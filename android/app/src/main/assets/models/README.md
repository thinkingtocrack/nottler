# Optional numeric models

The app requires the local Qwen3 language model before the main workflow is
available. No notification text is sent to a server. The numeric classifier and
embedding code remain local implementation details for categorization/search.

For LiteRT inference, install these files into the app-private directory:

```text
<app files directory>/models/notification_classifier.tflite
<app files directory>/models/notification_embedding.tflite
```

The files are intentionally not checked into this repository. Use a trusted,
offline installation channel such as a signed APK asset, Android App Bundle
asset pack, or `adb push` during development. Do not download them from inside
the notification listener.

## Model contract

Both models are single-signature float32 models with one input tensor shaped
`[1, 96]`. The input is a normalized, hashed bag-of-token features generated on
device from notification title/body/package metadata.

`notification_classifier.tflite` must expose one float output with at least 12
values in this fixed order:

```text
OTP, Finance, Banking, Messaging, Social, Shopping,
Delivery, Work, Travel, System, Promotion, Other
```

`notification_embedding.tflite` must expose one float output vector. A 128-value
output is recommended because it matches the local fallback dimensionality.

This custom numeric-input contract avoids shipping a tokenizer or a generative 
LLM for basic classification. If a future text embedder uses LiteRT Task 
Library metadata, adapt `NotificationAiEngine` to that model's documented 
input contract rather than silently guessing tensor shapes.

## Generative local language model

The app also supports the LiteRT-LM artifact
`qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm`. Keep this approximately 347 MB
file out of the APK and install it at:

```text
<app files directory>/models/qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm
```

The native loader tries the GPU backend first and falls back to CPU. It is used
for short factual summaries of banking, finance, delivery, and travel
notifications. If the file is missing or cannot load, the app stays on the
model setup screen and does not enter the main workflow.
