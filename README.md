# iTantra 📡
> **Indian Multilingual TTS & STT Aided Neural Transceiver Radio Access for Low Bitrate Links**  
> **Team:** Fifth Gear | **Event:** IEEE Hackathon

---

## 🌟 Executive Summary

In emergency situations, natural disasters, or remote tactical zones, cellular internet and high-bandwidth infrastructure are frequently degraded or unavailable. Transmitting raw voice audio (~64 kbps – 128 kbps) over low-bitrate links (such as LoRa, Bluetooth LE, or tactical VHF radio) causes heavy packet drop, high latency, and severe data congestion. Furthermore, language barriers in multilingual regions like India delay critical response efforts.

**iTantra** solves these challenges by combining **Offline-First Neural Speech Processing (STT/TTS)** with **Semantic Dictionary Coding** and **P2P Multi-Hop Mesh Radio Access**:
1. **On-Device STT & WebRTC VAD**: Speech is captured locally and automatically segmented upon natural speech pauses (>600ms).
2. **Ultra-Low-Bitrate & Semantic Coding**: Converts spoken sentences into text or compact **2-to-4-byte numerical codes** (e.g. `0xE1` for "Medical Emergency"), achieving **>99.9% bandwidth reduction** (250 KB audio compressed to 16 bytes!).
3. **Multilingual Receiver Personalization**: Telemetry text payloads are transmitted over peer-to-peer radio links; the receiver phone automatically decodes and synthesizes the speech in the receiver's **preferred language** out of 10 supported Indian languages (Hindi, Tamil, Telugu, Kannada, Malayalam, Bengali, Marathi, Gujarati, Punjabi, English).
4. **Offline GPS Context Stamper**: Automatically appends latitude/longitude sensor metadata to emergency alerts without requiring internet maps.

---

## 📁 Repository Structure

```
itantra/
├── app.py                      # Python Neural Transceiver Engine, VAD simulator & P2P Mesh Server
├── web/                        # Web Transceiver Dashboard UI
│   ├── index.html              # Dual-device (Transmitter & Receiver) interface & Mesh canvas
│   ├── styles.css              # Cyber-telecom dark glassmorphism design system
│   └── app.js                  # Audio visualizer, WebRTC VAD, Speech STT/TTS & Web Audio siren
├── flutter_app/                # Mobile Flutter Android Application Code
│   ├── lib/main.dart           # Production-ready Flutter UI & Neural Transceiver logic
│   └── pubspec.yaml            # Minimal dependencies (speech_to_text, flutter_tts, hive, location)
├── MODELS_AND_EXTENSIONS.md    # Complete catalog of Indic STT/TTS models, INT8 quantization & IDE extensions
└── README.md                   # Complete setup guide & documentation
```

---

## 🚀 Quick Start Guide

### Option 1: Run Python Neural Transceiver Server & Web Dashboard (Recommended)

1. **Start the Transceiver Server**:
   ```bash
   python3 app.py
   ```
2. **Access the Dashboard**:
   Open your browser and navigate to:
   ```
   http://localhost:5000
   ```
3. **Try out the Features**:
   - **Mic Capture & WebRTC VAD**: Click **"Speak (WebRTC VAD)"** and speak into your microphone. Pause for 0.8s to witness auto-transmission.
   - **Semantic Emergency Chips**: Click **"🚨 Medical SOS (0xE1)"** to send a 4-byte priority emergency broadcast.
   - **Receiver Language Personalization**: Change the receiver language dropdown to **Hindi**, **Tamil**, **Telugu**, or **Kannada** and click **"🔊 Reconstruct & Play TTS Speech"**!
   - **Bandwidth Analytics**: Inspect the real-time savings card showing >99.9% data reduction!

---

### Option 2: Mobile Android Build with Flutter

1. Navigate to the Flutter directory:
   ```bash
   cd flutter_app
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Build & run on connected Android phone or emulator:
   ```bash
   flutter run
   ```

---

## 📡 API Reference

The Python backend (`app.py`) provides lightweight REST endpoints:

- **`GET /api/status`**: Returns transceiver status, active nodes, and supported languages.
- **`POST /api/transmit`**: Encodes text or emergency codes into low-bitrate payloads, simulates mesh routing, and translates for receiver personalization.
  - **Payload Body**:
    ```json
    {
      "text": "Medical emergency! Need immediate assistance.",
      "sender_id": "NODE_ALPHA",
      "target_node": "BROADCAST",
      "is_emergency": true,
      "preferred_lang": "hi",
      "mode": "EMERGENCY_BROADCAST"
    }
    ```
- **`GET /api/history`**: Returns recent transmission audit log.
- **`GET /api/dictionary`**: Returns current semantic alert codepoint table.

---

## 💡 Key Innovations & Feature Summary

| Feature | Description | Advantage |
| :--- | :--- | :--- |
| **Offline-First AI** | On-device STT and TTS engines | Zero dependence on internet or cloud APIs |
| **Semantic Alert Coding** | Converts emergency phrases to 4-byte codes | Transmits emergency alerts in <5 ms even over 1 kbps links |
| **WebRTC VAD Pause Detection** | Detects natural pauses (>600ms) in voice | Triggers sentence transmission automatically without holding down buttons |
| **Receiver Personalization** | Receiver selects preferred language independently | Resolves language barriers across 10 Indian languages |
| **Multi-Hop Relay Mesh** | Peer-to-peer forwarding across nearby nodes | Extends range beyond direct line of sight |
| **GPS Sensor Context** | Attaches Lat/Lng coordinates directly from onboard sensors | Emergency responders know exact position offline |

---

## 🛠️ Required Models & IDE Extensions
Refer to [`MODELS_AND_EXTENSIONS.md`](MODELS_AND_EXTENSIONS.md) for full download URLs for Whisper-Tiny ONNX models, Piper Indic TTS voice models, INT8 quantization commands, and VS Code extensions.
