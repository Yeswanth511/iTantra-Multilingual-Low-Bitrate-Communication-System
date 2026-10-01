# iTantra - Required ML Models, Libraries & IDE Extensions Guide

This guide provides a comprehensive checklist and step-by-step instructions for downloading, installing, and configuring all open-source Speech-to-Text (STT), Text-to-Speech (TTS), WebRTC Voice Activity Detection (VAD), INT8 Quantization tools, and IDE extensions required to run the **iTantra** platform in an offline, production environment.

---

## 1. Speech-To-Text (STT) Models

For on-device, offline multilingual speech recognition across 10 Indian languages (Hindi, Tamil, Telugu, Kannada, Malayalam, Bengali, Marathi, Gujarati, Punjabi, English):

| Model Name | Developer / Org | Model Format | Size | Languages Supported | Download Source / HuggingFace Repo |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Whisper-Tiny (INT8 ONNX)** | OpenAI / ONNX Runtime | `.onnx` (Quantized) | ~39 MB | Multilingual (100+ including Indian langs) | [`onnx-community/whisper-tiny`](https://huggingface.co/onnx-community/whisper-tiny) |
| **Whisper-Base (INT8 ONNX)** | OpenAI / ONNX Runtime | `.onnx` (Quantized) | ~74 MB | High accuracy Indian multilingual | [`onnx-community/whisper-base`](https://huggingface.co/onnx-community/whisper-base) |
| **IndicWav2Vec** | AI4Bharat | PyTorch `.pt` / `.onnx` | ~120 MB | 40+ Indian Dialects & Languages | [`ai4bharat/indicwav2vec-v1`](https://huggingface.co/ai4bharat/indicwav2vec-v1) |
| **Vosk Indic Offline STT** | Alpha Cephei | TFLite / ONNX | ~45 MB | Hindi, Indian English, Bengali | [`alphacep/vosk-model-hi-0.22`](https://alphacephei.com/vosk/models) |

### How to Download & Quantize Whisper-Tiny to INT8 ONNX:
```bash
# Install Optimum & ONNXRuntime
pip install optimum[onnxruntime] transformers

# Export Whisper-tiny into INT8 Quantized ONNX format for Mobile/LiteRT
optimum-cli export onnx --model openai/whisper-tiny --task automatic-speech-recognition --optimize O2 whisper_tiny_onnx/
```

---

## 2. Text-To-Speech (TTS) Models

For on-device speech synthesis on the receiver side in the user's preferred language:

| Model Name | Engine | Model Format | Size | Languages Supported | Download Link |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Piper TTS (Indic Voices)** | Piper / RHVoice | ONNX (`.onnx`) | ~18 - 25 MB / voice | Hindi, Tamil, Telugu, Kannada, Malayalam, Bengali, Marathi, Gujarati, Punjabi, English | [`rhasspy/piper-voices`](https://github.com/rhasspy/piper/releases) |
| **eSpeak-NG Engine** | eSpeak | Native C binary / `.data` | ~3 MB | 100+ languages (Full Indic support) | [`espeak-ng/espeak-ng`](https://github.com/espeak-ng/espeak-ng) |
| **AI4Bharat Indic-TTS** | AI4Bharat | PyTorch / TFLite | ~85 MB | 13 Indian Languages | [`ai4bharat/indic-tts`](https://huggingface.co/ai4bharat) |

### Downloading Piper ONNX Voice Models:
```bash
# Example downloading Hindi & Tamil ONNX TTS voice models
wget https://github.com/rhasspy/piper/releases/download/v1.0.0/voice-hi_IN-medium.onnx
wget https://github.com/rhasspy/piper/releases/download/v1.0.0/voice-ta_IN-medium.onnx
```

---

## 3. WebRTC Voice Activity Detection (VAD)

WebRTC VAD detects continuous speech vs natural pauses (>600ms), automatically segmenting sentences and triggering low-bitrate transmission without waiting for manual push-to-talk release.

| Package / Library | Runtime Environment | Size | Purpose |
| :--- | :--- | :--- | :--- |
| **`webrtcvad`** | Python C-Extension | ~120 KB | High-speed zero-latency frame VAD |
| **`silero-vad` (ONNX)** | ONNX Runtime Mobile / Flutter | ~1.8 MB | Deep learning pause detector |

### Installation:
```bash
# Python WebRTC VAD package
pip install webrtcvad sounddevice numpy
```

---

## 4. Required IDE Extensions & Plugins

To develop, debug, and build iTantra efficiently, install the following extensions in your IDE (VS Code / Android Studio):

### VS Code Extensions:
1. **Flutter** (`Dart-Code.flutter`) - Mobile cross-platform support & live reload.
2. **Dart** (`Dart-Code.dart`) - Dart language support, linting, and formatting.
3. **Python** (`ms-python.python`) - Python intellisense, debugging, and linting.
4. **Pylance** (`ms-python.vscode-pylance`) - Fast type checking for Python runtime.
5. **Live Server** (`ritwickdey.liveserver`) - Instant preview for web transceiver UI.
6. **Prettier - Code formatter** (`esbenp.prettier-vscode`) - Web asset formatting.

### Android Studio / Gradle Plugins:
1. **Flutter Plugin** & **Dart Plugin**
2. **Android NDK (Native Development Kit)** - Required if compiling WebRTC C++ bindings or ONNX C++ runtimes for ARM64 Android devices.
3. **CMake (v3.22+)** - For native ONNX runtime mobile build integration.

---

## 5. Mobile Framework & Storage Dependencies

For building the Android mobile app (`flutter_app`):

| Dependency | Purpose | pubspec.yaml declaration |
| :--- | :--- | :--- |
| **`speech_to_text`** | On-device microphone speech capture & VAD interface | `speech_to_text: ^6.6.0` |
| **`flutter_tts`** | Offline local speech synthesis for receiver voice output | `flutter_tts: ^3.8.3` |
| **`hive` / `hive_flutter`** | Lightweight offline key-value & binary packet storage | `hive_flutter: ^1.1.0` |
| **`location`** | Onboard GPS sensor coordinates stamper (no internet map required) | `location: ^5.0.3` |
