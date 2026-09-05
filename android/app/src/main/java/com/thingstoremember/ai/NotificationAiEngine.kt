package com.thingstoremember.ai

import android.content.Context
import com.google.ai.edge.litert.Accelerator
import com.google.ai.edge.litert.CompiledModel
import com.thingstoremember.notification.NotificationPayload
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.exp
import kotlin.math.sqrt

private const val FEATURE_COUNT = 96
private const val EMBEDDING_DIMENSIONS = 128

private val CATEGORIES = listOf(
    "otp", "finance", "banking", "messaging", "social", "shopping",
    "delivery", "work", "travel", "system", "promotion", "other",
)

data class LiteRtAnalysis(
    val category: String,
    val confidence: Double,
    val importance: Int,
    val embedding: List<Float>,
    val aiProcessed: Boolean,
    val aiModelVersion: String,
    val summary: String? = null,
    val aiProcessingError: String? = null,
    val accelerator: String = "CPU",
) {
    fun toMap(): HashMap<String, Any?> = hashMapOf(
        "category" to category,
        "confidence" to confidence,
        "importance" to importance,
        "embedding" to embedding,
        "aiProcessed" to aiProcessed,
        "aiModelVersion" to aiModelVersion,
        "summary" to summary,
        "aiProcessingError" to aiProcessingError,
        "accelerator" to accelerator,
    )
}

object NotificationAiEngine {
    private var service: LiteRtService? = null

    @Synchronized
    fun start(context: Context) {
        if (service == null) service = LiteRtService(context.applicationContext)
        service?.initializeAsync()
    }

    fun analyze(context: Context, payload: NotificationPayload, callback: (Map<String, Any?>) -> Unit) {
        start(context)
        service?.analyzeAsync(payload) { callback(it.toMap()) }
    }

    fun embed(context: Context, text: String, callback: (List<Float>) -> Unit) {
        start(context)
        service?.embedAsync(text, callback)
    }

    fun status(context: Context): Map<String, Any?> {
        start(context)
        return service?.status() ?: mapOf(
            "initialized" to false,
            "classifier" to false,
            "embedding" to false,
            "message" to "Preparing offline AI",
        )
    }
}

private class LiteRtService(private val context: Context) {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "nottler-ai").apply { isDaemon = true }
    }
    @Volatile private var initialized = false
    @Volatile private var classifierRunner: Runner? = null
    @Volatile private var embeddingRunner: Runner? = null
    @Volatile private var classifierError: String? = null
    @Volatile private var embeddingError: String? = null

    fun initializeAsync() {
        if (initialized) return
        executor.execute {
            if (initialized) return@execute
            classifierRunner = loadRunner("notification_classifier.tflite")
            embeddingRunner = loadRunner("notification_embedding.tflite")
            initialized = true
        }
    }

    fun analyzeAsync(payload: NotificationPayload, callback: (LiteRtAnalysis) -> Unit) {
        initializeAsync()
        executor.execute {
            try {
                callback(analyzeNow(payload))
            } catch (error: Exception) {
                callback(heuristic(payload, error.javaClass.simpleName))
            }
        }
    }

    fun embedAsync(text: String, callback: (List<Float>) -> Unit) {
        initializeAsync()
        executor.execute {
            val result = embeddingRunner?.run(features(text)) ?: hashEmbedding(text)
            callback(result)
        }
    }

    fun status(): Map<String, Any?> = mapOf(
        "initialized" to initialized,
        "classifier" to (classifierRunner != null),
        "embedding" to (embeddingRunner != null),
        "message" to when {
            !initialized -> "Loading local models"
            classifierRunner != null && embeddingRunner != null -> "LiteRT models ready"
            else -> "Offline heuristic fallback ready; optional LiteRT models are not installed"
        },
        "classifierError" to classifierError,
        "embeddingError" to embeddingError,
    )

    private fun analyzeNow(payload: NotificationPayload): LiteRtAnalysis {
        val input = features("${payload.title} ${payload.text} ${payload.subText.orEmpty()}")
        val classifierOutput = classifierRunner?.run(input)
        val embeddingOutput = embeddingRunner?.run(input) ?: hashEmbedding(input.concatToString())
        if (classifierOutput != null && classifierOutput.size >= CATEGORIES.size) {
            val scores = softmax(classifierOutput.take(CATEGORIES.size))
            val best = scores.indices.maxByOrNull { scores[it] } ?: CATEGORIES.lastIndex
            val category = CATEGORIES[best]
            return LiteRtAnalysis(
                category = category,
                confidence = scores[best].toDouble(),
                importance = importance(category, "${payload.title} ${payload.text}".lowercase()),
                embedding = normalize(embeddingOutput),
                aiProcessed = true,
                aiModelVersion = "litert-2.2.0-custom-v1",
                accelerator = "LiteRT",
            )
        }
        return heuristic(payload, null, embeddingOutput)
    }

    private fun loadRunner(fileName: String): Runner? {
        val installed = File(File(context.filesDir, "models"), fileName)
        val assetName = "models/$fileName"
        val hasAsset = context.assets.list("models")?.contains(fileName) == true
        return try {
            if (installed.exists()) {
                createRunner(installed.absolutePath, fileName)
            } else if (hasAsset) {
                createAssetRunner(assetName, fileName)
            } else {
                null
            }
        } catch (firstError: Exception) {
            // GPU is useful when available, but model setup or device support
            // must never disable notification capture. Retry explicitly on CPU.
            try {
                if (installed.exists()) createRunner(installed.absolutePath, fileName, Accelerator.CPU)
                else if (hasAsset) createAssetRunner(assetName, fileName, Accelerator.CPU)
                else null
            } catch (secondError: Exception) {
                if (fileName.contains("classifier")) classifierError = secondError.javaClass.simpleName
                else embeddingError = secondError.javaClass.simpleName
                null
            }
        }
    }

    private fun createRunner(path: String, fileName: String, accelerator: Accelerator = Accelerator.GPU): Runner {
        val model = CompiledModel.create(path, CompiledModel.Options(accelerator), null)
        return try { Runner(model) } catch (error: Exception) { model.close(); throw error }
    }

    private fun createAssetRunner(assetName: String, fileName: String, accelerator: Accelerator = Accelerator.GPU): Runner {
        val model = CompiledModel.create(context.assets, assetName, CompiledModel.Options(accelerator), null)
        return try { Runner(model) } catch (error: Exception) { model.close(); throw error }
    }

    private fun heuristic(payload: NotificationPayload, error: String?, modelEmbedding: List<Float>? = null): LiteRtAnalysis {
        val text = "${payload.title} ${payload.text} ${payload.subText.orEmpty()}".lowercase()
        val category = classify(text, payload.packageName)
        return LiteRtAnalysis(
            category = category,
            confidence = confidence(category, text),
            importance = importance(category, text),
            embedding = normalize(modelEmbedding ?: hashEmbedding(text)),
            aiProcessed = true,
            aiModelVersion = "offline-feature-v1",
            summary = summary(category),
            aiProcessingError = error,
            accelerator = "CPU fallback",
        )
    }

    private fun loadFeatures(text: String): FloatArray = features(text)
}

private class Runner(private val model: CompiledModel) : AutoCloseable {
    private val inputs = model.createInputBuffers()
    private val outputs = model.createOutputBuffers()

    @Synchronized
    fun run(input: FloatArray): List<Float> {
        if (inputs.isEmpty() || outputs.isEmpty()) throw IllegalStateException("LiteRT model has no IO buffers")
        inputs[0].writeFloat(input)
        model.run(inputs, outputs)
        return outputs[0].readFloat().toList()
    }

    override fun close() {
        outputs.forEach { it.close() }
        inputs.forEach { it.close() }
        model.close()
    }
}

private fun features(text: String): FloatArray {
    val vector = FloatArray(FEATURE_COUNT)
    val normalized = text.lowercase().take(512)
    normalized.split(Regex("\\s+")).filter { it.isNotBlank() }.forEach { token ->
        vector[kotlin.math.abs(token.hashCode()) % FEATURE_COUNT] += 1f
        if (token.length > 2) vector[kotlin.math.abs((token.first().code * 31) + token.last().code) % FEATURE_COUNT] += 0.25f
    }
    val norm = sqrt(vector.fold(0f) { sum, value -> sum + (value * value) })
    if (norm > 0) for (index in vector.indices) vector[index] /= norm
    return vector
}

private fun hashEmbedding(text: String): List<Float> {
    val vector = FloatArray(EMBEDDING_DIMENSIONS)
    text.lowercase().take(512).split(Regex("\\s+")).filter { it.isNotBlank() }.forEach { token ->
        vector[kotlin.math.abs(token.hashCode()) % EMBEDDING_DIMENSIONS] += 1f
    }
    return normalize(vector.toList())
}

private fun normalize(values: List<Float>): List<Float> {
    if (values.isEmpty()) return List(EMBEDDING_DIMENSIONS) { 0f }
    val norm = sqrt(values.fold(0f) { sum, value -> sum + (value * value) })
    return if (norm == 0f) values else values.map { it / norm }
}

private fun softmax(values: List<Float>): List<Float> {
    val max = values.maxOrNull() ?: 0f
    val exponents = values.map { exp((it - max).toDouble()) }
    val total = exponents.sum()
    return exponents.map { (it / total).toFloat() }
}

private fun classify(text: String, packageName: String): String = when {
    Regex("\\botp\\b|verification code|one time password|security code|do not share").containsMatchIn(text) -> "otp"
    Regex("bank|upi|sbi|hdfc|icici|axis|debit|credit card|account").containsMatchIn(text) -> "banking"
    Regex("payment|paid|invoice|bill|salary|refund|transaction|wallet").containsMatchIn(text) -> "finance"
    Regex("deliver|shipment|parcel|tracking|courier|out for delivery").containsMatchIn(text) -> "delivery"
    Regex("flight|train|boarding|hotel|booking|reservation|uber|ola").containsMatchIn(text) -> "travel"
    Regex("meeting|calendar|deadline|work|slack|teams|interview|task").containsMatchIn(text) -> "work"
    Regex("sale|coupon|discount|offer|promo").containsMatchIn(text) -> "promotion"
    Regex("order|cart|shop|amazon|flipkart").containsMatchIn(text) -> "shopping"
    Regex("whatsapp|telegram|message|chat|sms|signal").containsMatchIn("$text $packageName") -> "messaging"
    Regex("instagram|facebook|like|comment|follow|social").containsMatchIn(text) -> "social"
    Regex("update available|battery|system|connected|storage|android").containsMatchIn(text) -> "system"
    else -> "other"
}

private fun confidence(category: String, text: String): Double = when {
    category == "other" -> 0.45
    category == "otp" || category == "promotion" -> 0.97
    text.length > 18 -> 0.86
    else -> 0.72
}

private fun importance(category: String, text: String): Int = when {
    category == "otp" || category == "promotion" -> 15
    Regex("urgent|asap|immediately|overdue|failed|blocked|cancelled").containsMatchIn(text) -> 95
    category == "banking" || category == "finance" -> 82
    category == "work" || category == "travel" -> 74
    else -> 52
}

private fun summary(category: String): String? = when (category) {
    "delivery" -> "Delivery update"
    "banking" -> "Banking notification"
    "finance" -> "Finance update"
    "travel" -> "Travel update"
    else -> null
}

private fun FloatArray.concatToString(): String = joinToString(",")
