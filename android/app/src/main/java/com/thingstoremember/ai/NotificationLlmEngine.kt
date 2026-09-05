package com.thingstoremember.ai

import android.content.Context
import android.util.Log
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.thingstoremember.notification.NotificationPayload
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

private const val MODEL_FILE = "qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm"
private const val MODEL_LABEL = "Qwen3 0.6B INT4 no-think"
private const val MODEL_URL = "https://huggingface.co/litert-community/Qwen3-0.6B-int4/resolve/main/qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm?download=true"
private const val MODEL_SHA256 = "2df6821ec12702dafd33915e7a1a1adc7c4b053f3672fd9555dfaf3a114c4139"
private const val MODEL_BYTES = 347251840L
private const val REQUIRED_FREE_BYTES = 64L * 1024L * 1024L
private const val LOG_TAG = "NotificationLlmEngine"

object NotificationLlmEngine {
    private var service: LocalLlmService? = null

    @Synchronized
    fun start(context: Context) {
        if (service == null) service = LocalLlmService(context.applicationContext)
        service?.initializeAsync()
    }

    fun summarize(
        context: Context,
        payload: NotificationPayload,
        callback: (String?) -> Unit,
    ) {
        start(context)
        service?.summarizeAsync(payload, callback)
    }

    fun download(context: Context, callback: (Boolean, String?) -> Unit) {
        start(context)
        service?.downloadAsync(callback)
    }

    fun status(context: Context): Map<String, Any?> {
        start(context)
        return service?.status() ?: mapOf(
            "languageModel" to false,
            "languageModelName" to MODEL_LABEL,
            "languageModelMessage" to "Preparing local language model",
        )
    }
}

private class LocalLlmService(private val context: Context) {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "nottler-llm").apply { isDaemon = true }
    }
    private val modelFile = File(File(context.filesDir, "models"), MODEL_FILE)
    private val partialModelFile = File(modelFile.parentFile, "$MODEL_FILE.download")

    @Volatile private var initializationAttempted = false
    @Volatile private var engine: Engine? = null
    @Volatile private var backendName = "Unavailable"
    @Volatile private var initializationError: String? = null
    @Volatile private var downloading = false
    @Volatile private var downloadProgress = 0
    @Volatile private var downloadBytes = 0L
    @Volatile private var downloadTotalBytes = MODEL_BYTES

    fun initializeAsync() {
        if (initializationAttempted) return
        executor.execute { ensureEngine() }
    }

    fun summarizeAsync(payload: NotificationPayload, callback: (String?) -> Unit) {
        executor.execute {
            val summary = try {
                summarizeNow(payload)
            } catch (error: Throwable) {
                if (switchToCpu()) {
                    try {
                        summarizeNow(payload)
                    } catch (retryError: Throwable) {
                        initializationError = retryError.javaClass.simpleName
                        null
                    }
                } else {
                    initializationError = error.javaClass.simpleName
                    null
                }
            }
            callback(summary)
        }
    }

    fun downloadAsync(callback: (Boolean, String?) -> Unit) {
        executor.execute {
            if (downloading) {
                callback(false, "A model download is already in progress.")
                return@execute
            }
            downloading = true
            try {
                if (modelFile.exists() && isValidModelFile()) {
                    downloadProgress = 100
                    downloadBytes = modelFile.length()
                    resetInitialization()
                    if (ensureEngine() == null) {
                        throw IOException("The existing model is present but the LiteRT-LM engine could not initialize")
                    }
                    callback(true, null)
                    return@execute
                }
                if (context.filesDir.usableSpace < MODEL_BYTES + REQUIRED_FREE_BYTES) {
                    throw IOException("Not enough free storage for the 347 MB local model")
                }
                if (modelFile.exists() && !modelFile.delete()) {
                    throw IOException("Could not replace the invalid local model file")
                }
                partialModelFile.delete()
                downloadProgress = 0
                downloadBytes = 0L
                modelFile.parentFile?.mkdirs()
                val connection = (URL(MODEL_URL).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 30_000
                    readTimeout = 120_000
                    instanceFollowRedirects = true
                    requestMethod = "GET"
                }
                try {
                    if (connection.responseCode !in 200..299) {
                        throw IOException("Model server returned HTTP ${connection.responseCode}")
                    }
                    downloadTotalBytes = connection.contentLengthLong.takeIf { it > 0 } ?: MODEL_BYTES
                    connection.inputStream.use { input ->
                        partialModelFile.outputStream().use { output ->
                            val buffer = ByteArray(64 * 1024)
                            while (true) {
                                val count = input.read(buffer)
                                if (count < 0) break
                                output.write(buffer, 0, count)
                                downloadBytes += count
                                downloadProgress = ((downloadBytes * 100L) / downloadTotalBytes)
                                    .coerceIn(0L, 100L).toInt()
                            }
                        }
                    }
                } finally {
                    connection.disconnect()
                }

                val actualSha256 = sha256(partialModelFile)
                if (!actualSha256.equals(MODEL_SHA256, ignoreCase = true)) {
                    throw IOException("Downloaded model checksum did not match")
                }
                if (modelFile.exists() && !modelFile.delete()) {
                    throw IOException("Could not replace the existing model file")
                }
                if (!partialModelFile.renameTo(modelFile)) {
                    throw IOException("Could not finalize the model file")
                }

                downloadProgress = 100
                resetInitialization()
                if (ensureEngine() == null) {
                    throw IOException("The model downloaded but LiteRT-LM could not initialize it")
                }
                callback(true, null)
            } catch (error: Exception) {
                partialModelFile.delete()
                initializationError = error.message ?: error.javaClass.simpleName
                callback(false, initializationError)
            } finally {
                downloading = false
            }
        }
    }

    fun status(): Map<String, Any?> = mapOf(
        "languageModel" to (engine != null),
        "languageModelName" to MODEL_LABEL,
        "languageModelBackend" to backendName,
        "languageModelDownloading" to downloading,
        "languageModelDownloadProgress" to downloadProgress,
        "languageModelDownloadBytes" to downloadBytes,
        "languageModelDownloadTotalBytes" to downloadTotalBytes,
        "languageModelStorageBytes" to (if (modelFile.exists()) modelFile.length() else 0L),
        "languageModelStorageAvailableBytes" to context.filesDir.usableSpace,
        "languageModelMessage" to when {
            engine != null -> "$MODEL_LABEL ready ($backendName)"
            downloading -> "Downloading $MODEL_LABEL"
            !modelFile.exists() -> "Download $MODEL_LABEL to continue"
            !initializationAttempted -> "Loading $MODEL_LABEL"
            else -> "Model present, but the LiteRT-LM engine is not initialized"
        },
        "languageModelError" to initializationError,
    )

    private fun summarizeNow(payload: NotificationPayload): String? {
        val activeEngine = ensureEngine() ?: return null
        val prompt = buildString {
            append("Summarize this phone notification in one short sentence. ")
            append("Keep only the sender, action, amount, or deadline stated. ")
            append("Do not invent facts. Return plain text with no label.\n\n")
            append("Title: ")
            append(payload.title.take(240))
            append("\nBody: ")
            append(payload.text.take(1200))
            if (!payload.subText.isNullOrBlank()) {
                append("\nExtra: ")
                append(payload.subText!!.take(240))
            }
        }
        val config = ConversationConfig(
            systemInstruction = Contents.of(
                "You are Nottler's private notification summarizer. Be concise and factual.",
            ),
        )
        return activeEngine.createConversation(config).use { conversation ->
            val response = conversation.sendMessage(prompt)
            val text = response.contents.contents
                .filterIsInstance<Content.Text>()
                .joinToString("") { it.text }
            cleanSummary(text)
        }
    }

    @Synchronized
    private fun ensureEngine(): Engine? {
        if (initializationAttempted) return engine
        initializationAttempted = true
        if (!modelFile.exists()) return null

        // The bundled Qwen3 artifact is not fully compatible with the Android
        // OpenCL delegate: EMBEDDING_LOOKUP remains on CPU, while LiteRT-LM
        // requests full delegation during GPU engine initialization. Use CPU
        // until a fully GPU-compatible artifact is supplied.
        val backends = listOf(Backend.CPU())
        for ((index, backend) in backends.withIndex()) {
            val attempt = tryCreate(backend)
            if (attempt != null) {
                engine = attempt
                backendName = "CPU"
                return attempt
            }
        }
        return null
    }

    private fun resetInitialization() {
        engine?.close()
        engine = null
        initializationAttempted = false
        initializationError = null
    }

    @Synchronized
    private fun switchToCpu(): Boolean {
        if (!backendName.startsWith("GPU")) return false
        try {
            engine?.close()
        } catch (_: Throwable) {
            // Continue with a fresh CPU engine even if GPU cleanup is incomplete.
        }
        engine = null
        val cpuAttempt = tryCreate(Backend.CPU()) ?: return false
        engine = cpuAttempt
        backendName = "CPU"
        initializationAttempted = true
        return true
    }

    private fun tryCreate(backend: Backend): Engine? {
        var candidate: Engine? = null
        return try {
            candidate = Engine(
                EngineConfig(
                    modelPath = modelFile.absolutePath,
                    backend = backend,
                    cacheDir = context.cacheDir.absolutePath,
                ),
            )
            candidate.initialize()
            candidate
        } catch (error: Throwable) {
            try {
                candidate?.close()
            } catch (closeError: Throwable) {
                Log.w(LOG_TAG, "Failed to close LiteRT-LM ${backend.javaClass.simpleName} candidate", closeError)
            }
            initializationError = "${error.javaClass.simpleName}: ${error.message ?: "no message"}"
            Log.e(LOG_TAG, "LiteRT-LM ${backend.javaClass.simpleName} initialization failed", error)
            null
        }
    }

    private fun isValidModelFile(): Boolean {
        return modelFile.length() == MODEL_BYTES &&
            sha256(modelFile).equals(MODEL_SHA256, ignoreCase = true)
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { byte -> "%02x".format(byte) }
    }
}

private fun cleanSummary(raw: String?): String? {
    val value = raw
        ?.replace(Regex("<think>[\\s\\S]*?</think>"), "")
        ?.replace("```", "")
        ?.trim()
        ?.lineSequence()
        ?.firstOrNull { it.isNotBlank() }
        ?.replace(Regex("^(summary|answer):\\s*", RegexOption.IGNORE_CASE), "")
        ?.trim(' ', '\"', '\'', '`', '*')
        ?.trim()
        ?: return null
    return value.takeIf { it.isNotEmpty() }?.take(280)
}
