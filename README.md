# Nottler — Flutter offline notification manager

Nottler is now a Flutter Android application. It captures notifications through
an Android `NotificationListenerService`, stores them locally in SQLite, and
processes them without cloud APIs or network calls.

## What changed

- Built the active Flutter UI under `lib/`.
- Kept the notification listener native in Kotlin so capture is independent of
  Flutter lifecycle state.
- Added a Flutter `MethodChannel`/`EventChannel` bridge for notification access,
  pending events, and processing acknowledgements.
- Added local SQLite tables for memory items and notification logs, including
  category, confidence, importance, embedding, model version, summary, and
  processing-error fields.
- Added local full-text-style search over stored fields plus cosine semantic
  search over stored embeddings.
- Added persistent duplicate protection, user-controlled app/category filters,
  snoozing, deadline alerts, local category corrections, and privacy controls.
- Added a deterministic numeric fallback internally for classifier/embedder
  compatibility, while the main app remains gated on the required local LM.

The project is driven by `pubspec.yaml`, `lib/main.dart`, and the Android
project under `android/`.

## Architecture

```text
Android NotificationListenerService
        │ queue + event channel
        ▼
Flutter AppController ── SQLite (memory_items, notification_logs)
        │
        ├─ native Kotlin LiteRT + LiteRT-LM engines (required local model)
        └─ Flutter UI and local SQLite storage
```

The native listener never logs notification text and does not make network
requests during processing. Processing is asynchronous: notification callbacks enqueue quickly,
while model execution and database writes happen away from the listener callback.

## Local AI and LiteRT

The Android layer uses the current LiteRT Android API through
`com.google.ai.edge.litert:litert:2.2.0`. LiteRT's `CompiledModel` runner tries
GPU first and falls back to CPU. The required language model is checked before
the main app shell is shown; the app does not run in a no-LM mode.

Optional model files can be placed in either location:

- `android/app/src/main/assets/models/notification_classifier.tflite`
- `android/app/src/main/assets/models/notification_embedder.tflite`
- or the app-private directory `files/models/` on a running device.

No opaque model weights are checked into this migration. The required language
model is downloaded only after the user taps the first-launch download button;
the app remains on the setup screen until it is present and initialized.

Model contracts:

- classifier input: one float tensor shaped `[1, 96]` containing the local
  feature vector; output: at least 12 scores in this order: OTP, Finance,
  Banking, Messaging, Social, Shopping, Delivery, Work, Travel, System,
  Promotion, Other;
- embedder input: the same `[1, 96]` local feature vector; output: one float
  vector, preferably 128 dimensions;
- the current native loader reuses input/output buffers and a single background
  executor. It reports the selected accelerator through the AI status screen.

The native implementation follows LiteRT's official Android `CompiledModel`
flow: create a model, allocate buffers, write input floats, run, read output
floats, and close the model. See the [LiteRT Android documentation](https://developers.google.com/edge/litert/android)
and [Kotlin API example](https://developers.google.com/edge/litert/next/android_kotlin)
for the upstream API.

### Generative local language model

The project includes the Android integration for LiteRT-LM 0.13.1. It can run
the Apache-2.0 `Qwen3 0.6B INT4 no-think` artifact locally for concise factual
notification summaries. The model is deliberately installed separately from
the APK because it is approximately 347 MB. LiteRT-LM initialization and
generation run on a dedicated background executor; GPU is attempted first and
CPU is used when GPU initialization fails.

The model is only invoked for banking, finance, delivery, and travel records.
It receives the notification title/body and a strict instruction to preserve
only stated facts. It does not browse, call tools, access other apps, or send
notification text over the network. It is a small summarizer, not a general
reasoning system; INT4 quantization can reduce answer quality, and the
 There is no language-model fallback mode when this required model is unavailable.

Model source and installation instructions:

- [Qwen3 0.6B INT4 LiteRT-LM model card](https://huggingface.co/litert-community/Qwen3-0.6B-int4)
- [LiteRT-LM Kotlin API](https://github.com/google-ai-edge/LiteRT-LM/blob/main/docs/api/kotlin/getting_started.md)

For a debug install, copy the downloaded file into the app-private directory:

```text
adb push qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm /data/local/tmp/qwen3.litertlm
adb shell run-as com.thingstoremember mkdir -p files/models
adb shell run-as com.thingstoremember cp /data/local/tmp/qwen3.litertlm files/models/qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm
```

Restart Nottler after copying. Nottler verifies the model before showing the
main app.

### Installing a model locally

For a debug device, copy a model into the app-private directory with Android
Studio's Device Explorer, or use `adb` and `run-as`:

```text
adb push notification_classifier.tflite /data/local/tmp/notification_classifier.tflite
adb shell run-as com.thingstoremember mkdir -p files/models
adb shell run-as com.thingstoremember cp /data/local/tmp/notification_classifier.tflite files/models/notification_classifier.tflite
```

Restart Nottler after copying. A normal first install uses the in-app model
download screen instead of these manual copy commands.

## Build and test

The project was verified with Flutter 3.47.2 / Dart 3.13.2.

```text
flutter pub get
dart analyze
flutter test
flutter build apk --debug
```

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.
Release builds currently use the debug signing configuration until a production
keystore is supplied.

The Android project uses Gradle 8.14.5, AGP 8.13.2, and Kotlin 2.4.0. AGP 8 is
intentional for the current LiteRT 2.2.0 artifact: AGP 9 detects duplicate
namespace metadata between LiteRT's paired artifacts. Excluding the API
artifact is not safe because it contains the `CompiledModel` classes. Flutter
may warn that these older build-tool versions will be dropped in a future
release; when LiteRT publishes an AGP 9-compatible artifact, the versions can
be moved forward together.

## Android permissions and behavior

The user must enable Nottler under Android Settings → Notification access.
Nottler requests internet access only to download the selected local model and
notification permission only when the user enables deadline alerts. It ignores
its own package, skips blank events, deduplicates notifications using a
normalized local fingerprint, and caps the native processed-id cache.

Users can filter apps, categories, and low-priority alerts before a reminder
is saved. Deadline alerts are off until the user enables them. Scheduling a reminder creates a local alert one hour before its due
time; snoozed reminders alert at the selected snooze time and are restored
after device restarts. Category corrections are retained locally for matching
future notifications. Privacy controls can delete all data or data from one
source app.

Classification categories are OTP, Finance, Banking, Messaging, Social,
Shopping, Delivery, Work, Travel, System, Promotion, and Other. OTP and
promotion alerts are intentionally not converted into memory items; actionable
delivery, finance, banking, work, and travel alerts can become local memory
items. Summaries for these records are generated locally by LiteRT-LM when the
required model is ready.

## Known limitations

- Production-quality classifier/embedder weights still need to be selected,
  validated, and packaged by the app owner; the checked-in fallback is a local
  deterministic feature implementation, not the required language model. The
  app does not enter the main workflow until the LiteRT-LM model is ready.
- The optional numeric LiteRT model contract requires models exported to the
  documented `[1, 96]` input shape and category order.
- Semantic search is local cosine similarity and only covers records with a
  stored embedding.
- The current Android release signing is debug-only.
- Android OEM battery policies can still stop notification listeners; the app
  cannot override those policies without user action.
