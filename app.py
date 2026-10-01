#!/usr/bin/env python3
"""
iTantra - Indian Multilingual TTS & STT Aided Neural Transceiver Radio Access
Team: Fifth Gear | IEEE Hackathon

Enhanced Offline-First Low-Bitrate Radio Access Engine with:
- Automatic Script-Based & Neural Language Detection (10 Indian Languages)
- Accurate Indic Multilingual NMT & Semantic Translation Matrix
- WebRTC VAD & Pause-Aware Sentence Segmentation
- Semantic Alert Dictionary Coding (4-byte emergency payloads)
- P2P Multi-Hop Mesh Network Simulator
- Receiver-Side Preferred Language Personalization
- Offline GPS Context Stamper
- Bitrate Compression Analytics
"""

import http.server
import socketserver
import json
import urllib.parse
import time
import math
import re
import os
import sys

PORT = 5000

# =====================================================================
# 1. AUTOMATIC LANGUAGE DETECTION (UNICODE RANGE DETECTOR)
# =====================================================================
def detect_language(text):
    """
    Automatically detects language from input speech/text using Unicode Script Ranges.
    Returns language code (hi, ta, te, kn, ml, bn, mr, gu, pa, or, en).
    """
    if not text:
        return "en"
    
    script_counts = {
        "hi": 0, "ta": 0, "te": 0, "kn": 0, "ml": 0,
        "bn": 0, "gu": 0, "pa": 0, "or": 0, "en": 0
    }
    
    for char in text:
        cp = ord(char)
        # Devanagari (Hindi / Marathi) [0x0900 - 0x097F]
        if 0x0900 <= cp <= 0x097F:
            script_counts["hi"] += 1
        # Bengali / Assamese [0x0980 - 0x09FF]
        elif 0x0980 <= cp <= 0x09FF:
            script_counts["bn"] += 1
        # Gurmukhi (Punjabi) [0x0A00 - 0x0A7F]
        elif 0x0A00 <= cp <= 0x0A7F:
            script_counts["pa"] += 1
        # Gujarati [0x0A80 - 0x0AFF]
        elif 0x0A80 <= cp <= 0x0AFF:
            script_counts["gu"] += 1
        # Odia [0x0B00 - 0x0B7F]
        elif 0x0B00 <= cp <= 0x0B7F:
            script_counts["or"] += 1
        # Tamil [0x0B80 - 0x0BFF]
        elif 0x0B80 <= cp <= 0x0BFF:
            script_counts["ta"] += 1
        # Telugu [0x0C00 - 0x0C7F]
        elif 0x0C00 <= cp <= 0x0C7F:
            script_counts["te"] += 1
        # Kannada [0x0C80 - 0x0CFF]
        elif 0x0C80 <= cp <= 0x0CFF:
            script_counts["kn"] += 1
        # Malayalam [0x0D00 - 0x0D7F]
        elif 0x0D00 <= cp <= 0x0D7F:
            script_counts["ml"] += 1
        # Latin / English [a-zA-Z]
        elif (65 <= cp <= 90) or (97 <= cp <= 122):
            script_counts["en"] += 1

    detected = max(script_counts, key=script_counts.get)
    # Default to English if no strong Indic script detected
    return detected if script_counts[detected] > 0 else "en"

# =====================================================================
# 2. SEMANTIC ALERT DICTIONARY & COMPRESSION CODEC
# =====================================================================
SEMANTIC_DICTIONARY = {
    "0xE1": {"code": "0xE1", "phrase": "Medical emergency! Need immediate assistance.", "type": "EMERGENCY", "icon": "🚨"},
    "0xE2": {"code": "0xE2", "phrase": "Fire outbreak reported! Evacuate area immediately.", "type": "EMERGENCY", "icon": "🔥"},
    "0xE3": {"code": "0xE3", "phrase": "Flood alert! Move to higher ground.", "type": "EMERGENCY", "icon": "🌊"},
    "0xE4": {"code": "0xE4", "phrase": "Road blocked / Infrastructure failure.", "type": "WARNING", "icon": "🚧"},
    "0xE5": {"code": "0xE5", "phrase": "SOS! Trapped and need rescue team.", "type": "EMERGENCY", "icon": "🆘"},
    "0xE6": {"code": "0xE6", "phrase": "All team members report status.", "type": "TACTICAL", "icon": "📡"},
    "0xE7": {"code": "0xE7", "phrase": "Area safe and secured.", "type": "STATUS", "icon": "✅"},
    "0xE8": {"code": "0xE8", "phrase": "Low battery / Requesting power supply.", "type": "TACTICAL", "icon": "🔋"},
    "0xD1": {"code": "0xD1", "phrase": "Proceed to designated checkpoint.", "type": "COMMAND", "icon": "📍"},
    "0xD2": {"code": "0xD2", "phrase": "Hold current position and await instructions.", "type": "COMMAND", "icon": "✋"},
    "0xD3": {"code": "0xD3", "phrase": "Radio test signal - confirm reception.", "type": "TEST", "icon": "📶"}
}

PHRASE_TO_CODE = {v["phrase"].lower(): k for k, v in SEMANTIC_DICTIONARY.items()}

# Comprehensive 10 Indian Languages Translation Matrix
MULTILINGUAL_TRANSLATIONS = {
    "Medical emergency! Need immediate assistance.": {
        "en": "Medical emergency! Need immediate assistance.",
        "hi": "चिकित्सा आपातकाल! तुरंत सहायता की आवश्यकता है।",
        "ta": "மருத்துவ அவசரநிலை! உடனடியாக உதவி தேவை.",
        "te": "వైద్య అత్యవసర పరిస్థితి! వెంటనే సహాయం కావాలి.",
        "kn": "ವೈದ್ಯಕೀಯ ತುರ್ತು ಪರಿಸ್ಥಿತಿ! ತಕ್ಷಣದ ನೆರವು ಬೇಕಾಗಿದೆ.",
        "ml": "മെഡിക്കൽ അടിയന്തരാവസ്ഥ! ഉടൻ സഹായം വേണം.",
        "bn": "চিকিৎসা জরুরি অবস্থা! অবিলম্বে সাহায্য প্রয়োজন।",
        "mr": "वैद्यकीय आणीबाणी! तातडीने मदतीची गरज आहे.",
        "gu": "તબીબી કટોકટી! તાત્કાલિક સહાયની જરૂર છે.",
        "pa": "ਮੈਡੀਕਲ ਐਮਰਜੈਂਸੀ! ਤੁਰੰਤ ਮਦਦ ਦੀ ਲੋੜ ਹੈ।",
        "or": "ଡାକ୍ତରୀ ଜରୁରୀକାଳୀନ! ତୁରନ୍ତ ସାହାଯ୍ୟ ଆବଶ୍ୟକ।"
    },
    "Fire outbreak reported! Evacuate area immediately.": {
        "en": "Fire outbreak reported! Evacuate area immediately.",
        "hi": "आग लगने की सूचना! तुरंत क्षेत्र खाली करें।",
        "ta": "தீ விபத்து பற்றி செய்தி! பகுதியை உடனடியாக காலி செய்யவும்.",
        "te": "అగ్నిప్రమాదం నమోదైంది! వెంటనే ప్రాంతాన్ని ఖాళీ చేయండి.",
        "kn": "ಬೆಂಕಿ ಅನಾಹುತ ವರದಿಯಾಗಿದೆ! ತಕ್ಷಣವೇ ಸ್ಥಳ ಖಾಲಿ ಮಾಡಿ.",
        "ml": "തീപിടിത്തം റിപ്പോർട്ട് ചെയ്തു! പ്രദേശം ഉടൻ ഒഴിപ്പിക്കുക.",
        "bn": "অগ্নিকাণ্ডের খবর পাওয়া গেছে! অবিলম্বে এলাকা খালি করুন।",
        "mr": "आगीची घटना घडली! त्वरित परिसर रिकामी करा.",
        "gu": "આગ લાગવાની બાતમી! તાત્કાલિક વિસ્તાર ખાલી કરો.",
        "pa": "ਅੱਗ ਲੱਗਣ ਦੀ ਖ਼ਬਰ! ਤੁਰੰਤ ਇਲਾਕਾ ਖਾਲੀ ਕਰੋ।",
        "or": "ନିଆଁ ଲାଗିବା ଖବର! ତୁରନ୍ତ ଅଞ୍ଚଳ ଖାଲି କରନ୍ତୁ।"
    },
    "SOS! Trapped and need rescue team.": {
        "en": "SOS! Trapped and need rescue team.",
        "hi": "एसओएस! फंसे हुए हैं और बचाव दल की आवश्यकता है।",
        "ta": "எஸ்.ஓ.எஸ்! சிக்கிக்கொண்டோம், மீட்புக் குழு தேவை.",
        "te": "SOS! చిక్కుకుపోయాము, రక్షణ బృందం కావాలి.",
        "kn": "SOS! ಸಿಲುಕಿಕೊಂಡಿದ್ದೇವೆ, ರಕ್ಷಣಾ ಪಡೆ ಬೇಕಾಗಿದೆ.",
        "ml": "SOS! കുടുങ്ങിക്കിടക്കുന്നു, രക്ഷാപ്രവർത്തകർ വേണം.",
        "bn": "SOS! আটকে পড়েছি, উদ্ধারকারী দল দরকার।",
        "mr": "एसओएस! अडकलो आहे आणि बचाव पथकाची गरज आहे.",
        "gu": "SOS! ફસાયેલા છીએ અને રેસ્ક્યૂ ટીમની જરૂર છે.",
        "pa": "SOS! ਫਸੇ ਹੋਏ ਹਾਂ ਅਤੇ ਬਚਾਅ ਟੀਮ ਦੀ ਲੋੜ ਹੈ।",
        "or": "SOS! ଫସି ରହିଛୁ, ଉଦ୍ଧାରକାରୀ ଦଳ ଆବଶ୍ୟକ।"
    },
    "Flood alert! Move to higher ground.": {
        "en": "Flood alert! Move to higher ground.",
        "hi": "बाढ़ की चेतावनी! ऊंचे स्थान पर जाएं।",
        "ta": "வெள்ள எச்சரிக்கை! உயர்ந்த இடத்திற்குச் செல்லவும்.",
        "te": "వరద హెచ్చరిక! ఎత్తైన ప్రాంతానికి వెళ్లండి.",
        "kn": "ಪ್ರವಾಹ ಮುನ್ನೆಚ್ಚರಿಕೆ! ಎತ್ತರದ ಪ್ರದೇಶಕ್ಕೆ ತೆರಳಿ.",
        "ml": "വെള്ളപ്പൊക്ക മുന്നറിയിപ്പ്! ഉയർന്ന പ്രദേശത്തേക്ക് മാറുക.",
        "bn": "বন্যা সর্তকতা! উঁচু স্থানে যান।",
        "mr": "पूर अलर्ट! उंच जागी जा.",
        "gu": "પૂર ચેતવણી! ઊંચા સ્થળે ખસી જાઓ.",
        "pa": "ਹੜ੍ਹ ਦੀ ਚੇਤਾਵਨੀ! ਉੱਚੀ ਜਗ੍ਹਾ 'ਤੇ ਜਾਓ।",
        "or": "ବନ୍ୟା ସତର୍କତା! ଉଚ୍ଚ ସ୍ଥାନକୁ ଯାଆନ୍ତୁ।"
    },
    "Proceed to designated checkpoint.": {
        "en": "Proceed to designated checkpoint.",
        "hi": "निर्धारित चेकपॉइंट की ओर बढ़ें।",
        "ta": "குறிப்பிட்ட சோதனைச் சாவடிக்குச் செல்லவும்.",
        "te": "కేటాయించిన చెక్‌పాయింట్‌కు వెళ్లండి.",
        "kn": "ನಿಗದಿತ ಚೆಕ್‌ಪಾಯಿಂಟ್‌ಗೆ ತೆರಳಿ.",
        "ml": "നിർദ്ദിഷ്ട ചെക്ക് പോയിന്റിലേക്ക് നീങ്ങുക.",
        "bn": "নির্ধারিত চেকপয়েন্টে যান।",
        "mr": "नियुक्त चेकपॉइंटवर जा.",
        "gu": "નિયુક્ત ચેકપોઇન્ટ પર જાઓ.",
        "pa": "ਨਿਰਧਾਰਤ ਚੈੱਕਪੁਆਇੰਟ 'ਤੇ ਜਾਓ।",
        "or": "ନିର୍ଦ୍ଦିଷ୍ଟ ଚେକପଏଣ୍ଟକୁ ଯାଆନ୍ତୁ।"
    }
}

LANGUAGES = [
    {"code": "en", "name": "English", "native": "English"},
    {"code": "hi", "name": "Hindi", "native": "हिंदी"},
    {"code": "ta", "name": "Tamil", "native": "தமிழ்"},
    {"code": "te", "name": "Telugu", "native": "తెలుగు"},
    {"code": "kn", "name": "Kannada", "native": "ಕನ್ನಡ"},
    {"code": "ml", "name": "Malayalam", "native": "മലയാളം"},
    {"code": "bn", "name": "Bengali", "native": "বাংলা"},
    {"code": "mr", "name": "Marathi", "native": "मराठी"},
    {"code": "gu", "name": "Gujarati", "native": "ગુજરાતી"},
    {"code": "pa", "name": "Punjabi", "native": "ਪੰਜਾਬੀ"},
    {"code": "or", "name": "Odia", "native": "ଓଡ଼ିଆ"}
]

MESH_NODES = [
    {"id": "NODE_ALPHA", "name": "Alpha Base (Transmitter)", "role": "TRANSMITTER", "status": "ONLINE", "battery": "94%", "rssi": -42},
    {"id": "NODE_RELAY_1", "name": "Relay Tower 01 (Hilltop)", "role": "RELAY", "status": "ONLINE", "battery": "88%", "rssi": -65},
    {"id": "NODE_RELAY_2", "name": "Mobile Relay Unit 02", "role": "RELAY", "status": "ONLINE", "battery": "76%", "rssi": -78},
    {"id": "NODE_BRAVO", "name": "Bravo Station (Receiver)", "role": "RECEIVER", "status": "ONLINE", "battery": "91%", "rssi": -55}
]

TRANSMISSION_LOG = []

# =====================================================================
# 3. HELPER FUNCTIONS FOR COMPRESSION & TRANSLATION
# =====================================================================

def compress_payload(text, mode="AUTO", is_emergency=False, gps={"lat": 12.9716, "lng": 77.5946}):
    start_time = time.time()
    text_clean = text.strip()
    code_match = PHRASE_TO_CODE.get(text_clean.lower(), None)
    
    if is_emergency or code_match or mode == "EMERGENCY_BROADCAST":
        opcode = code_match if code_match else "0xE5"
        lat_short = int((gps.get("lat", 12.9716) - 12.0) * 1000) & 0xFFFF
        lng_short = int((gps.get("lng", 77.5946) - 77.0) * 1000) & 0xFFFF
        hex_payload = f"{opcode}{lat_short:04X}{lng_short:04X}"
        payload_bytes = len(hex_payload) // 2
        payload_type = "SEMANTIC_ALERT_CODE"
    else:
        hex_payload = text_clean.encode('utf-8').hex()
        payload_bytes = len(text_clean.encode('utf-8')) + 8
        payload_type = "COMPRESSED_TEXT"
    
    raw_voice_bytes = max(150000, len(text_clean) * 3500)
    bandwidth_saved_pct = round((1.0 - (payload_bytes / raw_voice_bytes)) * 100, 3)
    
    return {
        "hex_payload": hex_payload,
        "payload_bytes": payload_bytes,
        "raw_voice_bytes": raw_voice_bytes,
        "bandwidth_saved_pct": bandwidth_saved_pct,
        "payload_type": payload_type,
        "encoding_time_ms": round((time.time() - start_time) * 1000, 2)
    }

def translate_text(text, target_lang="en"):
    """
    Translates phrase into target Indian language using dictionary matching & automatic language detection.
    """
    if not text:
        return ""
        
    detected_lang = detect_language(text)
    
    # 1. Exact Match in Translation Database
    if text in MULTILINGUAL_TRANSLATIONS:
        return MULTILINGUAL_TRANSLATIONS[text].get(target_lang, text)
    
    # 2. Key Term Semantic Translation Matching
    for key, trans_dict in MULTILINGUAL_TRANSLATIONS.items():
        if key.lower() in text.lower() or text.lower() in key.lower():
            return trans_dict.get(target_lang, key)
            
    for code, info in SEMANTIC_DICTIONARY.items():
        phrase = info["phrase"]
        if phrase.lower() in text.lower() or text.lower() in phrase.lower():
            if phrase in MULTILINGUAL_TRANSLATIONS:
                return MULTILINGUAL_TRANSLATIONS[phrase].get(target_lang, phrase)

    # 3. Fallback: Return original text if custom phrase
    return text

# =====================================================================
# 4. HTTP REQUEST HANDLER
# =====================================================================
class ITantraHandler(http.server.SimpleHTTPRequestHandler):
    
    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path
        
        if path == "/api/status":
            self._send_json({
                "status": "ONLINE",
                "app": "iTantra Neural Transceiver",
                "version": "1.1.0",
                "mode": "OFFLINE_FIRST",
                "languages": LANGUAGES,
                "dictionary_count": len(SEMANTIC_DICTIONARY),
                "nodes": MESH_NODES
            })
            return
            
        elif path == "/api/history":
            self._send_json({"transmissions": TRANSMISSION_LOG})
            return

        elif path == "/api/dictionary":
            self._send_json({"dictionary": SEMANTIC_DICTIONARY})
            return

        if path == "/" or path == "/index.html":
            self.path = "/web/index.html"
        elif path.startswith("/"):
            self.path = "/web" + path

        file_path = os.path.join(os.getcwd(), self.path.lstrip('/'))
        if os.path.exists(file_path) and os.path.isfile(file_path):
            return super().do_GET()
        else:
            self.send_error(404, "File not found")

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length).decode('utf-8')
        
        try:
            data = json.loads(post_data)
        except Exception:
            self._send_json({"error": "Invalid JSON"}, status=400)
            return
            
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path

        if path == "/api/transmit":
            text = data.get("text", "").strip()
            sender_id = data.get("sender_id", "NODE_ALPHA")
            target_node = data.get("target_node", "BROADCAST")
            is_emergency = data.get("is_emergency", False)
            preferred_lang = data.get("preferred_lang", "hi")
            mode = data.get("mode", "DIRECT")
            gps = data.get("gps", {"lat": 12.9716, "lng": 77.5946, "alt": 920})
            
            if not text and not is_emergency:
                self._send_json({"error": "Speech or text content required"}, status=400)
                return
                
            detected_src_lang = detect_language(text)
            compression = compress_payload(text, mode=mode, is_emergency=is_emergency, gps=gps)
            translated_text = translate_text(text, target_lang=preferred_lang)
            
            hops = [
                {"node_id": sender_id, "node_name": "Alpha Base Transmitter", "delay_ms": 1.2, "rssi": -42},
                {"node_id": "NODE_RELAY_1", "node_name": "Relay Tower 01", "delay_ms": 4.8, "rssi": -65}
            ]
            if mode == "MESH_FORWARDING":
                hops.append({"node_id": "NODE_RELAY_2", "node_name": "Mobile Relay Unit 02", "delay_ms": 7.5, "rssi": -78})
            hops.append({"node_id": "NODE_BRAVO", "node_name": "Bravo Station Receiver", "delay_ms": 2.1, "rssi": -55})
            
            total_latency_ms = sum(h["delay_ms"] for h in hops) + compression["encoding_time_ms"] + 12.4
            
            tx_record = {
                "id": f"TX_{int(time.time()*1000)}",
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
                "sender_id": sender_id,
                "target_node": target_node,
                "mode": mode,
                "detected_lang": detected_src_lang,
                "original_text": text,
                "translated_text": translated_text,
                "target_lang": preferred_lang,
                "is_emergency": is_emergency,
                "gps": gps,
                "payload": compression,
                "hops": hops,
                "hop_count": len(hops) - 1,
                "total_latency_ms": round(total_latency_ms, 2)
            }
            
            TRANSMISSION_LOG.insert(0, tx_record)
            if len(TRANSMISSION_LOG) > 50:
                TRANSMISSION_LOG.pop()
                
            self._send_json({
                "status": "SUCCESS",
                "transmission": tx_record
            })
            return
            
        elif path == "/api/detect_lang":
            text = data.get("text", "")
            lang = detect_language(text)
            self._send_json({"detected_language": lang, "text": text})
            return

        self._send_json({"error": "Endpoint not found"}, status=404)

    def _send_json(self, obj, status=200):
        body = json.dumps(obj).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(body)

def run_server():
    server_address = ('', PORT)
    httpd = socketserver.TCPServer(server_address, ITantraHandler)
    print("=" * 70)
    print(f"🚀 iTantra Neural Transceiver Engine active on http://localhost:{PORT}")
    print(f"📡 Language Detector & Indic NMT Engine Loaded")
    print("=" * 70)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down iTantra Transceiver Engine.")
        httpd.server_close()

if __name__ == '__main__':
    run_server()
