/**
 * iTantra - Client Application Script
 * Handles Speech Capture, WebRTC VAD Emulation, P2P Transmission, 
 * Multilingual Receiver Personalization, and Web Audio Siren/TTS.
 */

document.addEventListener('DOMContentLoaded', () => {
  // DOM Element References
  const recordBtn = document.getElementById('recordBtn');
  const recordBtnText = document.getElementById('recordBtnText');
  const clearBtn = document.getElementById('clearBtn');
  const transcriptText = document.getElementById('transcriptText');
  const transmitBtn = document.getElementById('transmitBtn');
  const vadStatus = document.getElementById('vadStatus');
  const vadPauseNotice = document.getElementById('vadPauseNotice');
  const preferredLangSelect = document.getElementById('preferredLangSelect');
  const transmissionMode = document.getElementById('transmissionMode');
  const targetNode = document.getElementById('targetNode');
  
  // Analytics & Hex View
  const rawAudioBytes = document.getElementById('rawAudioBytes');
  const iTantraPayloadBytes = document.getElementById('iTantraPayloadBytes');
  const bandwidthSavedPct = document.getElementById('bandwidthSavedPct');
  const savingsBar = document.getElementById('savingsBar');
  const hexPayloadView = document.getElementById('hexPayloadView');
  const hexBytesCount = document.getElementById('hexBytesCount');
  const payloadTypeLabel = document.getElementById('payloadTypeLabel');

  // Receiver DOM
  const rxMsgMeta = document.getElementById('rxMsgMeta');
  const rxMsgText = document.getElementById('rxMsgText');
  const rxMsgTranslation = document.getElementById('rxMsgTranslation');
  const rxLocationDetails = document.getElementById('rxLocationDetails');
  const playTtsBtn = document.getElementById('playTtsBtn');
  const emergencySirenBtn = document.getElementById('emergencySirenBtn');
  const logTableBody = document.getElementById('logTableBody');
  const logCountLabel = document.getElementById('logCountLabel');

  // State Variables
  let isRecording = false;
  let recognition = null;
  let vadTimer = null;
  let currentTxData = null;
  let audioCtx = null;

  // Initialize Canvas Visualizer
  const canvas = document.getElementById('waveformCanvas');
  const canvasCtx = canvas.getContext('2d');
  let animationId = null;

  function drawEmptyWaveform() {
    canvasCtx.fillStyle = '#06090e';
    canvasCtx.fillRect(0, 0, canvas.width, canvas.height);
    canvasCtx.beginPath();
    canvasCtx.moveTo(0, canvas.height / 2);
    canvasCtx.lineTo(canvas.width, canvas.height / 2);
    canvasCtx.strokeStyle = 'rgba(0, 210, 255, 0.3)';
    canvasCtx.lineWidth = 2;
    canvasCtx.stroke();
  }
  drawEmptyWaveform();

  function animateActiveWaveform() {
    canvasCtx.fillStyle = '#06090e';
    canvasCtx.fillRect(0, 0, canvas.width, canvas.height);
    canvasCtx.beginPath();
    canvasCtx.strokeStyle = '#00f2fe';
    canvasCtx.lineWidth = 2;
    
    const sliceWidth = canvas.width / 50;
    let x = 0;
    for (let i = 0; i < 50; i++) {
      const v = Math.random() * 0.8 + 0.1;
      const y = (v * canvas.height) / 2 + (canvas.height / 4);
      if (i === 0) canvasCtx.moveTo(x, y);
      else canvasCtx.lineTo(x, y);
      x += sliceWidth;
    }
    canvasCtx.stroke();
    if (isRecording) {
      animationId = requestAnimationFrame(animateActiveWaveform);
    }
  }

  // WebSpeech Speech-To-Text Recognition
  if ('SpeechRecognition' in window || 'webkitSpeechRecognition' in window) {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    recognition = new SpeechRecognition();
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.lang = 'en-US';

    recognition.onresult = (event) => {
      let finalTranscript = '';
      for (let i = event.resultIndex; i < event.results.length; ++i) {
        if (event.results[i].isFinal) {
          finalTranscript += event.results[i][0].transcript;
        }
      }
      if (finalTranscript) {
        transcriptText.value = finalTranscript;
        triggerVadPauseDetection();
      }
    };

    recognition.onerror = (e) => {
      console.warn('Speech recognition fallback:', e.error);
    };

    recognition.onend = () => {
      if (isRecording) {
        recognition.start();
      }
    };
  }

  // Record Button Toggle
  recordBtn.addEventListener('click', () => {
    if (!isRecording) {
      isRecording = true;
      recordBtn.classList.add('btn-danger');
      recordBtnText.textContent = 'Stop Recording (VAD Active)';
      vadStatus.classList.add('active');
      vadStatus.innerHTML = '<span class="vad-dot"></span> VAD Listening';
      
      if (recognition) {
        try { recognition.start(); } catch(e) {}
      }
      animateActiveWaveform();
    } else {
      stopRecording();
    }
  });

  function stopRecording() {
    isRecording = false;
    recordBtn.classList.remove('btn-danger');
    recordBtnText.textContent = 'Speak (WebRTC VAD)';
    vadStatus.classList.remove('active');
    vadStatus.innerHTML = '<span class="vad-dot"></span> VAD Idle';
    if (recognition) {
      try { recognition.stop(); } catch(e) {}
    }
    cancelAnimationFrame(animationId);
    drawEmptyWaveform();
  }

  clearBtn.addEventListener('click', () => {
    transcriptText.value = '';
    vadPauseNotice.classList.remove('show');
  });

  // WebRTC VAD Pause Detection Emulation (>600ms silence auto-transmits)
  function triggerVadPauseDetection() {
    clearTimeout(vadTimer);
    vadPauseNotice.classList.remove('show');
    vadTimer = setTimeout(() => {
      vadPauseNotice.classList.add('show');
      vadStatus.innerHTML = '<span class="vad-dot"></span> Pause Detected!';
      console.log("WebRTC VAD detected natural speech pause. Triggering low-bitrate relay...");
      // Auto-transmit on natural pause
      setTimeout(() => {
        executeTransmission();
      }, 400);
    }, 800);
  }

  // Quick Semantic Alert Chips
  document.querySelectorAll('.alert-chip').forEach(btn => {
    btn.addEventListener('click', () => {
      const phrase = btn.getAttribute('data-phrase');
      transcriptText.value = phrase;
      transmissionMode.value = 'EMERGENCY_BROADCAST';
      targetNode.value = 'BROADCAST';
      document.getElementById('currentModeBadge').textContent = 'Emergency Broadcast Flooding';
      document.getElementById('currentModeBadge').style.borderColor = 'var(--accent-red)';
      executeTransmission(true);
    });
  });

  // Transmission Handler
  transmitBtn.addEventListener('click', () => {
    executeTransmission(false);
  });

  async function executeTransmission(isEmergencyAlert = false) {
    const text = transcriptText.value.trim();
    if (!text && !isEmergencyAlert) {
      alert("Please speak or type a message/alert to transmit.");
      return;
    }

    const payload = {
      text: text || "Emergency SOS Alert Broadcast",
      sender_id: "NODE_ALPHA",
      target_node: targetNode.value,
      is_emergency: isEmergencyAlert || transmissionMode.value === 'EMERGENCY_BROADCAST',
      preferred_lang: preferredLangSelect.value,
      mode: transmissionMode.value,
      gps: { lat: 12.9716, lng: 77.5946, alt: 920 }
    };

    try {
      const response = await fetch('/api/transmit', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      const data = await response.json();

      if (data.status === 'SUCCESS') {
        currentTxData = data.transmission;
        updateUIWithTransmission(currentTxData);
        if (isRecording) stopRecording();
      }
    } catch (err) {
      console.error("Transmission error:", err);
      // Client-side fallback computation if offline
      const fallbackTx = createLocalFallbackTx(payload);
      currentTxData = fallbackTx;
      updateUIWithTransmission(fallbackTx);
    }
  }

  function createLocalFallbackTx(payload) {
    const rawBytes = Math.max(150000, payload.text.length * 3500);
    const payloadBytes = payload.is_emergency ? 4 : payload.text.length + 8;
    const savedPct = ((1.0 - (payloadBytes / rawBytes)) * 100).toFixed(2);
    
    return {
      id: `TX_${Date.now()}`,
      timestamp: new Date().toLocaleTimeString(),
      original_text: payload.text,
      translated_text: payload.text,
      target_lang: payload.preferred_lang,
      is_emergency: payload.is_emergency,
      mode: payload.mode,
      gps: payload.gps,
      payload: {
        hex_payload: payload.is_emergency ? "0xE103E51E" : "534f53204d65646963616c",
        payload_bytes: payloadBytes,
        raw_voice_bytes: rawBytes,
        bandwidth_saved_pct: savedPct,
        payload_type: payload.is_emergency ? "SEMANTIC_ALERT_CODE" : "COMPRESSED_TEXT"
      },
      total_latency_ms: 18.5
    };
  }

  // Update UI Panels on Packet Transmission
  function updateUIWithTransmission(tx) {
    // Analytics
    rawAudioBytes.textContent = (tx.payload.raw_voice_bytes / 1024).toFixed(1) + " KB";
    iTantraPayloadBytes.textContent = tx.payload.payload_bytes + " Bytes";
    bandwidthSavedPct.textContent = tx.payload.bandwidth_saved_pct + "% Saved";
    savingsBar.style.width = tx.payload.bandwidth_saved_pct + "%";
    payloadTypeLabel.textContent = tx.payload.payload_type;

    // Hex Display
    const hexFormatted = (tx.payload.hex_payload.match(/.{1,2}/g) || []).map(b => "0x" + b.toUpperCase()).join(" ");
    hexPayloadView.textContent = hexFormatted;
    hexBytesCount.textContent = tx.payload.payload_bytes + " Bytes";

    // Receiver Box
    rxMsgMeta.textContent = `[ID: ${tx.id}] • Latency: ${tx.total_latency_ms}ms • Lang: ${tx.target_lang.toUpperCase()}`;
    rxMsgText.textContent = `Original (Sender): "${tx.original_text}"`;
    rxMsgTranslation.textContent = `Decoded (${getLangName(tx.target_lang)}): "${tx.translated_text}"`;
    rxLocationDetails.textContent = `Lat: ${tx.gps.lat}° N | Lng: ${tx.gps.lng}° E (Altitude: ${tx.gps.alt}m)`;

    // Auto trigger siren if emergency
    if (tx.is_emergency) {
      playEmergencySiren();
    }

    // Auto Play Receiver TTS Speech
    speakText(tx.translated_text, tx.target_lang);

    // Append to Table Log
    appendLogEntry(tx);
  }

  // Language Code Helper
  function getLangName(code) {
    const map = {
      hi: "Hindi", ta: "Tamil", te: "Telugu", kn: "Kannada", ml: "Malayalam",
      bn: "Bengali", mr: "Marathi", gu: "Gujarati", pa: "Punjabi", en: "English"
    };
    return map[code] || code;
  }

  // Web SpeechSynthesis TTS Output
  function speakText(text, langCode) {
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = langCode === 'hi' ? 'hi-IN' : (langCode === 'ta' ? 'ta-IN' : 'en-IN');
      utterance.rate = 0.95;
      window.speechSynthesis.speak(utterance);
    }
  }

  playTtsBtn.addEventListener('click', () => {
    if (currentTxData) {
      speakText(currentTxData.translated_text, preferredLangSelect.value);
    } else {
      speakText(transcriptText.value || "iTantra Neural Transceiver ready.", preferredLangSelect.value);
    }
  });

  // Web Audio API Siren Generator (Offline Emergency Alarm sound)
  emergencySirenBtn.addEventListener('click', () => {
    playEmergencySiren();
  });

  function playEmergencySiren() {
    try {
      if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(600, audioCtx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(1200, audioCtx.currentTime + 0.4);
      osc.frequency.exponentialRampToValueAtTime(600, audioCtx.currentTime + 0.8);

      gain.gain.setValueAtTime(0.3, audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 1.2);

      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start();
      osc.stop(audioCtx.currentTime + 1.2);
    } catch(e) {
      console.warn("Audio siren error:", e);
    }
  }

  // Table Log Helper
  let txCount = 0;
  function appendLogEntry(tx) {
    txCount++;
    if (txCount === 1) {
      logTableBody.innerHTML = '';
    }
    logCountLabel.textContent = `${txCount} Transmissions`;

    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${tx.timestamp}</td>
      <td><span class="badge-tag">${tx.mode}</span></td>
      <td>${tx.payload.payload_type}</td>
      <td class="font-mono">${(tx.payload.raw_voice_bytes/1024).toFixed(1)} KB → ${tx.payload.payload_bytes} B</td>
      <td class="text-success font-mono"><strong>${tx.payload.bandwidth_saved_pct}%</strong></td>
      <td>${tx.target_lang.toUpperCase()}</td>
      <td class="font-mono">${tx.total_latency_ms} ms</td>
      <td>${tx.original_text}</td>
      <td class="text-glow">${tx.translated_text}</td>
    `;
    logTableBody.insertBefore(tr, logTableBody.firstChild);
  }
});
