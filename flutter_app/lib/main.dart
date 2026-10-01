import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:nearby_connections/nearby_connections.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ITantraApp());
}

class ITantraApp extends StatelessWidget {
  const ITantraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iTantra Mesh Transceiver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        cardColor: const Color(0xFF111827),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D2FF),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF111827),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF111827),
          selectedItemColor: Color(0xFF00D2FF),
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const AppShell(),
    );
  }
}

// =====================================================================
// GEODESIC DISTANCE & COMPASS BEARING MATH UTILITY
// =====================================================================
class GeoMath {
  static const double earthRadiusM = 6371000.0;

  /// Haversine geodesic distance in meters
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    if (lat1 == 0.0 || lon1 == 0.0 || lat2 == 0.0 || lon2 == 0.0) return 0.0;
    final phi1 = lat1 * math.pi / 180.0;
    final phi2 = lat2 * math.pi / 180.0;
    final deltaPhi = (lat2 - lat1) * math.pi / 180.0;
    final deltaLambda = (lon2 - lon1) * math.pi / 180.0;

    final a = math.sin(deltaPhi / 2.0) * math.sin(deltaPhi / 2.0) +
        math.cos(phi1) * math.cos(phi2) *
        math.sin(deltaLambda / 2.0) * math.sin(deltaLambda / 2.0);
    final c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a));
    return earthRadiusM * c;
  }

  /// Formatted distance string (e.g., "145 m" or "2.35 km")
  static String formatDistance(double meters) {
    if (meters <= 0.0) return "Locating...";
    if (meters < 1000.0) return "${meters.toStringAsFixed(0)} m";
    return "${(meters / 1000.0).toStringAsFixed(2)} km";
  }

  /// Initial compass bearing in degrees [0, 360) from (lat1, lon1) to (lat2, lon2)
  static double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    if (lat1 == 0.0 || lon1 == 0.0 || lat2 == 0.0 || lon2 == 0.0) return 0.0;
    final phi1 = lat1 * math.pi / 180.0;
    final phi2 = lat2 * math.pi / 180.0;
    final deltaLambda = (lon2 - lon1) * math.pi / 180.0;

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final theta = math.atan2(y, x);
    return (theta * 180.0 / math.pi + 360.0) % 360.0;
  }

  /// Reverse bearing (from point 2 back to point 1)
  static double calculateReverseBearing(double bearingDegrees) {
    return (bearingDegrees + 180.0) % 360.0;
  }

  /// 8-point cardinal direction info
  static Map<String, String> formatDirection(double bearingDegrees) {
    const directions = [
      {"code": "N", "name": "North", "arrow": "⬆️"},
      {"code": "NE", "name": "North-East", "arrow": "↗️"},
      {"code": "E", "name": "East", "arrow": "➡️"},
      {"code": "SE", "name": "South-East", "arrow": "↘️"},
      {"code": "S", "name": "South", "arrow": "⬇️"},
      {"code": "SW", "name": "South-West", "arrow": "↙️"},
      {"code": "W", "name": "West", "arrow": "⬅️"},
      {"code": "NW", "name": "North-West", "arrow": "↖️"},
    ];
    int index = ((bearingDegrees + 22.5) % 360.0 ~/ 45.0);
    final d = directions[index];
    return {
      "name": "${d['name']!} ${d['arrow']!} (${bearingDegrees.toStringAsFixed(0)}°)",
      "cardinal": d['code']!,
      "arrow": d['arrow']!,
      "degrees": "${bearingDegrees.toStringAsFixed(0)}°",
    };
  }
}

// =====================================================================
// APP SHELL WITH BOTTOM NAVIGATION
// =====================================================================
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentTab = 0;
  final MeshEngine _mesh = MeshEngine();

  @override
  void initState() {
    super.initState();
    _mesh.init(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _mesh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardPage(mesh: _mesh),
      TransmitPage(mesh: _mesh),
      ReceivePage(mesh: _mesh),
      PeersPage(mesh: _mesh),
    ];

    return Scaffold(
      body: pages[_currentTab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          const BottomNavigationBarItem(icon: Icon(Icons.cell_tower), label: 'Transmit'),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _mesh.totalRx > 0,
              label: Text('${_mesh.totalRx}'),
              child: const Icon(Icons.call_received_rounded),
            ),
            label: 'Receive',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _mesh.peers.isNotEmpty,
              label: Text('${_mesh.peers.length}'),
              child: const Icon(Icons.device_hub_rounded),
            ),
            label: 'Peers',
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// MESH ENGINE — Dual Transport (Wi-Fi Direct + Offline Wi-Fi UDP + GPS)
// =====================================================================
class MeshEngine {
  final String deviceId = "iTantra_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
  
  // Strategy.P2P_STAR forces high-bandwidth Wi-Fi Direct / Hotspot transport over Bluetooth
  final Strategy strategy = Strategy.P2P_STAR;

  // Radio State
  bool isAdvertising = false;
  bool isDiscovering = false;
  bool isUdpActive = false;

  // GPS State
  double lat = 0.0;
  double lng = 0.0;

  // Counters & Message State
  int totalRx = 0;
  int totalTx = 0;
  String lastRxText = "";
  String lastRxTranslated = "";
  String lastRxSender = "";
  String lastRxSrcLang = "en";
  String lastRxSrcLangName = "English";
  String lastRxTransport = "Nearby Wi-Fi";
  double lastRxLat = 0.0;
  double lastRxLng = 0.0;
  double lastRxDistance = 0.0;
  String lastRxDirection = "";
  String lastRxReverseDirection = "";

  String preferredLang = "hi"; // Default receiver language

  final Map<String, String> peers = {}; // endpointId -> name
  final Set<String> seenPacketIds = {};
  final List<String> logs = [];
  final List<Map<String, dynamic>> rxHistory = [];

  // Offline UDP Socket for Pure Local Wi-Fi (No Hotspot/Internet/BT required)
  RawDatagramSocket? _udpSocket;
  static const int udpPort = 45454;

  // TTS & STT
  late FlutterTts tts;
  late stt.SpeechToText speech;
  bool isListening = false;
  String sttText = "";
  String sttLocale = "auto"; // Selected input speech locale
  String detectedLang = "en";
  String detectedLangName = "English";

  VoidCallback? _onUpdate;
  Timer? _retryTimer;

  final Map<String, String> langNames = {
    'hi': 'Hindi (हिंदी)',
    'ta': 'Tamil (தமிழ்)',
    'te': 'Telugu (తెలుగు)',
    'kn': 'Kannada (ಕನ್ನಡ)',
    'ml': 'Malayalam (മലയാളം)',
    'bn': 'Bengali (বাংলা)',
    'mr': 'Marathi (मराठी)',
    'gu': 'Gujarati (ગુજરાતી)',
    'pa': 'Punjabi (ਪੰਜਾਬੀ)',
    'en': 'English',
  };

  final Map<String, String> sttLocales = {
    'auto': 'Auto-Detect Script',
    'hi_IN': 'Hindi (hi-IN)',
    'ta_IN': 'Tamil (ta-IN)',
    'te_IN': 'Telugu (te-IN)',
    'kn_IN': 'Kannada (kn-IN)',
    'ml_IN': 'Malayalam (ml-IN)',
    'bn_IN': 'Bengali (bn-IN)',
    'mr_IN': 'Marathi (mr-IN)',
    'gu_IN': 'Gujarati (gu-IN)',
    'pa_IN': 'Punjabi (pa-IN)',
    'en_IN': 'English (en-IN)',
  };

  // Comprehensive Multilingual Emergency & Disaster Dictionary (10 Indian Languages)
  final Map<String, Map<String, String>> translations = {
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
    },
    "Need clean drinking water and food supplies.": {
      "en": "Need clean drinking water and food supplies.",
      "hi": "पीने के स्वच्छ पानी और भोजन की आवश्यकता है।",
      "ta": "சுத்தமான குடிநீரும் உணவுப் பொருட்களும் தேவை.",
      "te": "తాగునీరు మరియు ఆహార సామాగ్రి అవసరం.",
      "kn": "ಕುಡಿಯುವ ನೀರು ಮತ್ತು ಆಹಾರ ಸರಬರಾಜು ಅಗತ್ಯವಿದೆ.",
      "ml": "ശുദ്ധജലവും ഭക്ഷണവും ആവശ്യമുണ്ട്.",
      "bn": "বিশুদ্ধ পানীয় জল ও খাবারের প্রয়োজন।",
      "mr": "पिण्याचे पाणी आणि अन्नाची गरज आहे.",
      "gu": "પીવાના શુદ્ધ પાણી અને ભોજનની જરૂર છે.",
      "pa": "ਪੀਣ ਵਾਲੇ ਪਾਣੀ ਅਤੇ ਭੋਜਨ ਦੀ ਲੋੜ ਹੈ।",
    },
    "Road is blocked! Seek alternate route.": {
      "en": "Road is blocked! Seek alternate route.",
      "hi": "सड़क बंद है! वैकल्पिक मार्ग का उपयोग करें।",
      "ta": "சாலை அடைக்கப்பட்டுள்ளது! மாற்று வழியைப் பயன்படுத்தவும்.",
      "te": "రహదారి మూసివేయబడింది! ప్రత్యామ్నాయ మార్గాన్ని ఉపయోగించండి.",
      "kn": "ರಸ್ತೆ ಬ್ಲಾಕ್ ಆಗಿದೆ! ಪರ್ಯಾಯ ಮಾರ್ಗ ಬಳಸಿ.",
      "ml": "റോഡ് തടസ്സപ്പെട്ടു! മറ്റ് വഴി ഉപയോഗിക്കുക.",
      "bn": "রাস্তা বন্ধ! বিকল্প পথ ব্যবহার করুন।",
      "mr": "रस्ता बंद आहे! पर्यायी मार्ग वापरा.",
      "gu": "રસ્તો બંધ છે! વૈકલ્પિક માર્ગ શોધો.",
      "pa": "ਸੜਕ ਬੰਦ ਹੈ! ਬਦਲਵਾਂ ਰਸਤਾ ਵਰਤੋ।",
    },
    "Safe at secure shelter, awaiting transport.": {
      "en": "Safe at secure shelter, awaiting transport.",
      "hi": "सुरक्षित आश्रय स्थल पर हैं, वाहन की प्रतीक्षा है।",
      "ta": "பாதுகாப்பான இடத்தில் உள்ளோம், வாகனத்திற்காக காத்திருக்கிறோம்.",
      "te": "సురక్షిత ఆశ్రయంలో ఉన్నాము, రవాణా కోసం వేచి చూస్తున్నాము.",
      "kn": "ಸುರಕ್ಷಿತ ಸ್ಥಳದಲ್ಲಿದ್ದೇವೆ, ವಾಹನಕ್ಕಾಗಿ ಕಾಯುತ್ತಿದ್ದೇವೆ.",
      "ml": "സുരക്ഷിത സ്ഥാനത്താണ്, വാഹനത്തിനായി കാത്തിരിക്കുന്നു.",
      "bn": "নিরাপদ আশ্রয়ে আছি, পরিবহনের অপেক্ষায়।",
      "mr": "सुरक्षित निवाऱ्यात आहोत, वाहतुकीची वाट पाहत आहोत.",
      "gu": "સુરક્ષિત આશ્રયસ્થાને છીએ, વાહનની રાહ જોઈ રહ્યા છીએ.",
      "pa": "ਸੁਰੱਖਿਅਤ ਥਾਂ 'ਤੇ ਹਾਂ, ਗੱਡੀ ਦੀ ਉਡੀਕ ਕਰ ਰਹੇ ਹਾਂ।",
    },
  };

  void init(VoidCallback onUpdate) {
    _onUpdate = onUpdate;
    tts = FlutterTts();
    speech = stt.SpeechToText();
    _boot();
  }

  Future<void> _boot() async {
    await _requestPermissions();
    await _fetchGps();
    await _startNearbyMesh();
    await _startUdpWifiBroadcast();

    // 8-second periodic watchdog to ensure mesh and UDP socket stay active
    _retryTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!isAdvertising || !isDiscovering) {
        addLog("🔄 Auto-refreshing Wi-Fi Direct Mesh...");
        _startNearbyMesh();
      }
      if (!isUdpActive) {
        _startUdpWifiBroadcast();
      }
    });
  }

  void dispose() {
    _retryTimer?.cancel();
    try { _udpSocket?.close(); } catch (_) {}
    try { Nearby().stopAdvertising(); } catch (_) {}
    try { Nearby().stopDiscovery(); } catch (_) {}
    try { Nearby().stopAllEndpoints(); } catch (_) {}
  }

  Future<void> restartMesh() async {
    try { Nearby().stopAdvertising(); } catch (_) {}
    try { Nearby().stopDiscovery(); } catch (_) {}
    try { _udpSocket?.close(); } catch (_) {}
    isAdvertising = false;
    isDiscovering = false;
    isUdpActive = false;
    _notify();
    await Future.delayed(const Duration(milliseconds: 500));
    await _startNearbyMesh();
    await _startUdpWifiBroadcast();
  }

  void _notify() { _onUpdate?.call(); }

  // Permissions Request
  Future<void> _requestPermissions() async {
    await [
      ph.Permission.location,
      ph.Permission.bluetooth,
      ph.Permission.bluetoothAdvertise,
      ph.Permission.bluetoothConnect,
      ph.Permission.bluetoothScan,
      ph.Permission.nearbyWifiDevices,
      ph.Permission.microphone,
    ].request();
  }

  // Fetch Current GPS Coordinates
  Future<void> _fetchGps() async {
    try {
      final loc = Location();
      bool serviceEnabled = await loc.serviceEnabled();
      if (!serviceEnabled) serviceEnabled = await loc.requestService();
      var perm = await loc.hasPermission();
      if (perm == PermissionStatus.denied) perm = await loc.requestPermission();
      final data = await loc.getLocation();
      lat = data.latitude ?? 0.0;
      lng = data.longitude ?? 0.0;
      addLog("📍 GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}");
      _notify();
    } catch (e) {
      addLog("GPS unavailable, coordinates at default");
    }
  }

  // TRANSPORT 1: Google Nearby Connections (P2P_STAR: Wi-Fi Direct / Local Hotspot Priority)
  Future<void> _startNearbyMesh() async {
    if (!isAdvertising) {
      try {
        isAdvertising = await Nearby().startAdvertising(
          deviceId,
          strategy,
          onConnectionInitiated: _onConnectionInit,
          onConnectionResult: (id, status) {
            if (status == Status.CONNECTED) {
              addLog("🔗 Connected peer: ${peers[id] ?? id}");
            } else {
              addLog("⚠️ Connection status: $status for ${peers[id] ?? id}");
            }
            _notify();
          },
          onDisconnected: (id) {
            addLog("🔌 Disconnected peer: ${peers[id] ?? id}");
            peers.remove(id);
            _notify();
          },
          serviceId: "com.fifthgear.itantra",
        );
        addLog("📡 Advertising as $deviceId (Wi-Fi Direct P2P_STAR)");
        _notify();
      } catch (e) {
        addLog("Advertising: $e");
      }
    }

    if (!isDiscovering) {
      try {
        isDiscovering = await Nearby().startDiscovery(
          deviceId,
          strategy,
          onEndpointFound: (id, name, serviceId) {
            addLog("🟢 Found peer: $name");
            peers[id] = name;
            _notify();
            // Automatically establish high-bandwidth Wi-Fi link
            Nearby().requestConnection(
              deviceId,
              id,
              onConnectionInitiated: _onConnectionInit,
              onConnectionResult: (id, status) {
                if (status == Status.CONNECTED) {
                  addLog("🔗 Wi-Fi Direct Linked: ${peers[id] ?? id}");
                }
                _notify();
              },
              onDisconnected: (id) {
                peers.remove(id);
                _notify();
              },
            );
          },
          onEndpointLost: (id) {
            addLog("📴 Lost peer: ${peers[id] ?? id}");
            peers.remove(id);
            _notify();
          },
          serviceId: "com.fifthgear.itantra",
        );
        addLog("🔍 Scanning for Wi-Fi Direct peers...");
        _notify();
      } catch (e) {
        addLog("Discovery: $e");
      }
    }
    _notify();
  }

  void _onConnectionInit(String id, ConnectionInfo info) {
    peers[id] = info.endpointName;
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES && payload.bytes != null) {
          _handleIncomingPayload(payload.bytes!, "Nearby Wi-Fi Direct", endpointId);
        }
      },
    );
    addLog("🤝 Accepted Wi-Fi peer: ${info.endpointName}");
    _notify();
  }

  // TRANSPORT 2: Concurrent Offline Local Wi-Fi UDP Broadcast (No Hotspot/Internet/BT Required)
  Future<void> _startUdpWifiBroadcast() async {
    try {
      _udpSocket?.close();
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort);
      _udpSocket!.broadcastEnabled = true;
      isUdpActive = true;
      addLog("📶 Offline Wi-Fi UDP Socket Active on :$udpPort");

      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket!.receive();
          if (dg != null) {
            _handleIncomingPayload(dg.data, "Offline Wi-Fi (UDP)", "UDP");
          }
        }
      });
      _notify();
    } catch (e) {
      isUdpActive = false;
      addLog("Wi-Fi UDP: $e");
    }
  }

  // Incoming Payload Processor with Distance, Compass Bearing, and Auto-Translation
  void _handleIncomingPayload(Uint8List bytes, String transportName, [String? endpointId]) {
    try {
      final jsonStr = utf8.decode(bytes);
      final packet = jsonDecode(jsonStr) as Map<String, dynamic>;
      final packetId = packet['pid'] ?? "";

      // Deduplicate packet
      if (seenPacketIds.contains(packetId)) return;
      seenPacketIds.add(packetId);

      final text = packet['text'] ?? "";
      final srcLang = packet['lang'] ?? "en";
      final srcLangName = packet['lang_name'] ?? (langNames[srcLang] ?? "English");
      final senderLat = (packet['lat'] ?? 0.0).toDouble();
      final senderLng = (packet['lng'] ?? 0.0).toDouble();
      final senderName = packet['sender'] ?? "Unknown";
      final int ttl = packet['ttl'] ?? 0;
      final int payloadBytes = packet['bytes'] ?? text.length;

      // Calculate Haversine Distance (in meters)
      final distanceM = GeoMath.calculateDistance(lat, lng, senderLat, senderLng);
      final distanceStr = GeoMath.formatDistance(distanceM);

      // Calculate Compass Direction: Receiver -> Sender
      final bearingToSender = GeoMath.calculateBearing(lat, lng, senderLat, senderLng);
      final dirToSenderInfo = GeoMath.formatDirection(bearingToSender);

      // Calculate Relative Direction: Sender -> Receiver
      final bearingToReceiver = GeoMath.calculateReverseBearing(bearingToSender);
      final dirToReceiverInfo = GeoMath.formatDirection(bearingToReceiver);

      // Translate text to receiver's preferred language
      final translated = translate(text, preferredLang);

      lastRxText = text;
      lastRxTranslated = translated;
      lastRxSender = senderName;
      lastRxSrcLang = srcLang;
      lastRxSrcLangName = srcLangName;
      lastRxTransport = transportName;
      lastRxLat = senderLat;
      lastRxLng = senderLng;
      lastRxDistance = distanceM;
      lastRxDirection = dirToSenderInfo['name']!;
      lastRxReverseDirection = dirToReceiverInfo['name']!;
      totalRx++;

      rxHistory.insert(0, {
        'text': text,
        'translated': translated,
        'sender': senderName,
        'src_lang': srcLang,
        'src_lang_name': srcLangName,
        'target_lang': preferredLang,
        'lat': senderLat,
        'lng': senderLng,
        'my_lat': lat,
        'my_lng': lng,
        'distance_m': distanceM,
        'distance_str': distanceStr,
        'bearing_deg': bearingToSender,
        'direction_to_sender': dirToSenderInfo['name'],
        'direction_arrow': dirToSenderInfo['arrow'],
        'direction_to_receiver': dirToReceiverInfo['name'],
        'transport': transportName,
        'bytes': payloadBytes,
        'time': DateTime.now().toString().substring(11, 19),
      });
      if (rxHistory.length > 35) rxHistory.removeLast();

      addLog("📥 Rx from $senderName [$srcLangName] via $transportName | $distanceStr");
      speakText(translated);

      // Multi-hop Mesh Relay
      if (ttl > 1) {
        packet['ttl'] = ttl - 1;
        _relayToAllPeers(jsonEncode(packet), excludeId: endpointId);
        addLog("🔄 Mesh Relayed to ${peers.length - 1} peers (TTL ${ttl - 1})");
      }
      _notify();
    } catch (e) {
      addLog("Decode error: $e");
    }
  }

  // Dual Broadcast Outgoing Payload: Nearby Connections + Offline Wi-Fi UDP Socket
  void broadcastPayload(String text, bool isEmergency) {
    _fetchGps(); // Auto-refresh GPS coordinates

    final packetId = "P${DateTime.now().millisecondsSinceEpoch}";
    seenPacketIds.add(packetId);
    final int bytes = isEmergency ? 4 : utf8.encode(text).length + 8;

    final packetMap = {
      'pid': packetId,
      'sender': deviceId,
      'text': text,
      'lang': detectedLang,
      'lang_name': detectedLangName,
      'lat': lat,
      'lng': lng,
      'is_emergency': isEmergency,
      'bytes': bytes,
      'ttl': 3,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    final jsonStr = jsonEncode(packetMap);

    // 1. Send via Google Nearby Connections (Wi-Fi Direct / BLE)
    _relayToAllPeers(jsonStr);

    // 2. Send via Offline Local Wi-Fi UDP Broadcast
    try {
      final udpBytes = utf8.encode(jsonStr);
      _udpSocket?.send(udpBytes, InternetAddress("255.255.255.255"), udpPort);
    } catch (_) {}

    totalTx++;
    addLog("📡 Broadcasted $bytes B via Wi-Fi [$detectedLangName] (GPS: ${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})");
    _notify();
  }

  void _relayToAllPeers(String jsonPayload, {String? excludeId}) {
    final data = Uint8List.fromList(utf8.encode(jsonPayload));
    for (var peerId in peers.keys) {
      if (peerId == excludeId) continue;
      try {
        Nearby().sendBytesPayload(peerId, data);
      } catch (_) {}
    }
  }

  // Voice Input (STT) + Language Recognition
  void startListening(VoidCallback onDone) async {
    if (isListening) return;
    bool available = await speech.initialize(
      onStatus: (s) {
        if (s == 'done') {
          isListening = false;
          _notify();
          onDone();
        }
      },
    );
    if (available) {
      isListening = true;
      speech.listen(
        localeId: sttLocale == 'auto' ? null : sttLocale,
        onResult: (r) {
          sttText = r.recognizedWords;
          if (sttLocale == 'auto') {
            detectedLang = _detectLang(sttText);
          } else {
            detectedLang = sttLocale.split('_').first;
          }
          detectedLangName = langNames[detectedLang] ?? "English";
          _notify();
        },
      );
      _notify();
    }
  }

  void stopListening() {
    speech.stop();
    isListening = false;
    _notify();
  }

  void setManualText(String text) {
    sttText = text;
    if (sttLocale == 'auto') {
      detectedLang = _detectLang(text);
    } else {
      detectedLang = sttLocale.split('_').first;
    }
    detectedLangName = langNames[detectedLang] ?? "English";
    _notify();
  }

  // Multilingual Translation Engine
  String translate(String text, String targetLang) {
    if (translations.containsKey(text)) {
      return translations[text]![targetLang] ?? text;
    }
    for (var key in translations.keys) {
      if (text.toLowerCase().contains(key.toLowerCase())) {
        return translations[key]![targetLang] ?? key;
      }
    }
    return text;
  }

  // Speech TTS Output
  void speakText(String text) async {
    final ttsLocales = {
      'hi': 'hi-IN', 'ta': 'ta-IN', 'te': 'te-IN', 'kn': 'kn-IN',
      'ml': 'ml-IN', 'bn': 'bn-IN', 'mr': 'mr-IN', 'gu': 'gu-IN',
      'pa': 'pa-IN', 'en': 'en-US'
    };
    await tts.setLanguage(ttsLocales[preferredLang] ?? 'en-US');
    await tts.speak(text);
  }

  // Auto-Detect Language via Unicode Script Analysis
  String _detectLang(String text) {
    for (int i = 0; i < text.length; i++) {
      int c = text.codeUnitAt(i);
      if (c >= 0x0900 && c <= 0x097F) return "hi"; // Devanagari (Hindi / Marathi)
      if (c >= 0x0B80 && c <= 0x0BFF) return "ta"; // Tamil
      if (c >= 0x0C00 && c <= 0x0C7F) return "te"; // Telugu
      if (c >= 0x0C80 && c <= 0x0CFF) return "kn"; // Kannada
      if (c >= 0x0D00 && c <= 0x0D7F) return "ml"; // Malayalam
      if (c >= 0x0980 && c <= 0x09FF) return "bn"; // Bengali
      if (c >= 0x0A80 && c <= 0x0AFF) return "gu"; // Gujarati
      if (c >= 0x0A00 && c <= 0x0A7F) return "pa"; // Punjabi
    }
    return "en"; // English / Latin default
  }

  void addLog(String msg) {
    logs.insert(0, "[${DateTime.now().toString().substring(11, 19)}] $msg");
    if (logs.length > 50) logs.removeLast();
  }
}

// =====================================================================
// TAB 1: DASHBOARD PAGE
// =====================================================================
class DashboardPage extends StatelessWidget {
  final MeshEngine mesh;
  const DashboardPage({super.key, required this.mesh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('iTantra Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Metric Cards
            Row(
              children: [
                _statCard('Peers', '${mesh.peers.length}', Icons.device_hub, Colors.cyan),
                const SizedBox(width: 8),
                _statCard('Tx Sent', '${mesh.totalTx}', Icons.upload_rounded, Colors.green),
                const SizedBox(width: 8),
                _statCard('Rx Got', '${mesh.totalRx}', Icons.download_rounded, Colors.amber),
                const SizedBox(width: 8),
                _statCard('Range', mesh.lastRxDistance > 0 ? GeoMath.formatDistance(mesh.lastRxDistance) : 'Direct', Icons.radar, Colors.purpleAccent),
              ],
            ),
            const SizedBox(height: 14),

            // Dual Radio Mediums Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📻 Active Radio Transports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(mesh.isAdvertising ? Icons.wifi_tethering : Icons.wifi_off, color: mesh.isAdvertising ? Colors.green : Colors.grey, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('High-Range Wi-Fi Direct (P2P_STAR)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(mesh.isAdvertising ? 'Active (Replaces BT for up to 100m range)' : 'Starting...', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Chip(label: Text(mesh.isAdvertising ? 'ONLINE' : 'WAIT'), backgroundColor: mesh.isAdvertising ? Colors.green.withAlpha(50) : Colors.grey.withAlpha(50)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Icon(mesh.isUdpActive ? Icons.wifi : Icons.wifi_off, color: mesh.isUdpActive ? Colors.cyan : Colors.grey, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Offline Local Wi-Fi (UDP :45454)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(mesh.isUdpActive ? 'Zero-config broadcast (No Hotspot/BT required)' : 'Offline', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Chip(label: Text(mesh.isUdpActive ? 'ACTIVE' : 'IDLE'), backgroundColor: mesh.isUdpActive ? Colors.cyan.withAlpha(50) : Colors.grey.withAlpha(50)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Device GPS Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.my_location, color: Colors.green, size: 28),
                title: const Text('My GPS Position'),
                subtitle: Text('Lat: ${mesh.lat.toStringAsFixed(5)}  |  Lng: ${mesh.lng.toStringAsFixed(5)}', style: const TextStyle(fontFamily: 'monospace', color: Colors.cyan, fontSize: 12)),
                trailing: Text('ID: ${mesh.deviceId.substring(8)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 14),

            // Latest Received Message with Distance & Compass Direction
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('📩 Latest Transceiver Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (mesh.lastRxTransport.isNotEmpty)
                          Chip(label: Text(mesh.lastRxTransport, style: const TextStyle(fontSize: 10)), backgroundColor: Colors.cyan.withAlpha(40)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(mesh.lastRxText.isEmpty ? "No incoming transmissions yet." : '"${mesh.lastRxText}"', style: const TextStyle(fontSize: 15)),
                    if (mesh.lastRxSender.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      // Direction & Distance Radar Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.cyan.withAlpha(80))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.explore, color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                Text('Distance: ${GeoMath.formatDistance(mesh.lastRxDistance)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('🧭 Heading to Sender: ${mesh.lastRxDirection}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            Text('🔄 Heading from Sender to You: ${mesh.lastRxReverseDirection}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.cyan.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                        child: Text('🔊 "${mesh.lastRxTranslated}"', style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Activity Log
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📋 Radio Event Log', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      height: 130,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                      child: mesh.logs.isEmpty
                          ? const Center(child: Text('Scanning radio frequencies...', style: TextStyle(color: Colors.grey, fontSize: 12)))
                          : ListView.builder(
                              itemCount: mesh.logs.length,
                              itemBuilder: (c, i) => Text(mesh.logs[i], style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.cyan)),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// TAB 2: TRANSMIT PAGE (Speech Recognition + Language Tag + Emergency)
// =====================================================================
class TransmitPage extends StatefulWidget {
  final MeshEngine mesh;
  const TransmitPage({super.key, required this.mesh});

  @override
  State<TransmitPage> createState() => _TransmitPageState();
}

class _TransmitPageState extends State<TransmitPage> {
  MeshEngine get m => widget.mesh;
  final TextEditingController _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _send([String? phrase]) {
    final text = phrase ?? (_textCtrl.text.isNotEmpty ? _textCtrl.text : m.sttText);
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please speak, type, or choose an emergency alert')));
      return;
    }
    m.broadcastPayload(text, phrase != null);
    _textCtrl.clear();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Broadcasted to ${m.peers.length} peers via Wi-Fi!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📡 Transmit Radio'),
        actions: [
          Chip(label: Text('Peers: ${m.peers.length}', style: const TextStyle(fontSize: 12)), backgroundColor: Colors.green.withAlpha(50)),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Voice Speech Input Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🎙️ Voice Input (STT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Chip(label: Text('Tag: [${m.detectedLang.toUpperCase()}] ${m.detectedLangName}'), backgroundColor: Colors.cyan.withAlpha(50)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Speech Input Locale Dropdown
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: m.sttLocale,
                      decoration: const InputDecoration(
                        labelText: '🗣️ Spoken Language Mode',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: m.sttLocales.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            m.sttLocale = v;
                            if (v != 'auto') {
                              m.detectedLang = v.split('_').first;
                              m.detectedLangName = m.langNames[m.detectedLang] ?? "English";
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Speech Preview Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                      child: Text(m.sttText.isEmpty ? 'Tap Speak to record in your native language...' : m.sttText, style: const TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(height: 12),

                    // Manual Text Input
                    TextField(
                      controller: _textCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Or type custom message...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) => m.setManualText(v),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            if (m.isListening) {
                              m.stopListening();
                            } else {
                              m.startListening(() => setState(() {}));
                            }
                            setState(() {});
                          },
                          icon: Icon(m.isListening ? Icons.mic_off : Icons.mic),
                          label: Text(m.isListening ? 'Stop' : 'Speak'),
                          style: ElevatedButton.styleFrom(backgroundColor: m.isListening ? Colors.red : Colors.cyan),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _send(),
                            icon: const Icon(Icons.cell_tower),
                            label: const Text('Broadcast Wi-Fi'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // GPS Stamp
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on, color: Colors.green),
                title: const Text('GPS Auto-Tagged'),
                subtitle: Text('${m.lat.toStringAsFixed(5)}, ${m.lng.toStringAsFixed(5)}', style: const TextStyle(fontFamily: 'monospace', color: Colors.cyan)),
              ),
            ),
            const SizedBox(height: 14),

            // Emergency Alerts (Instant 4-Byte Semantic Codec)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🚨 Instant Emergency Semantic Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    _alertButton('🚨 Medical SOS (0xE1)', Colors.red, "Medical emergency! Need immediate assistance."),
                    const SizedBox(height: 8),
                    _alertButton('🔥 Fire Outbreak (0xE2)', Colors.orange, "Fire outbreak reported! Evacuate area immediately."),
                    const SizedBox(height: 8),
                    _alertButton('🆘 Trapped SOS (0xE5)', Colors.red, "SOS! Trapped and need rescue team."),
                    const SizedBox(height: 8),
                    _alertButton('🌊 Flood Alert (0xE3)', Colors.blue, "Flood alert! Move to higher ground."),
                    const SizedBox(height: 8),
                    _alertButton('💧 Water & Food Supplies (0xE6)', Colors.teal, "Need clean drinking water and food supplies."),
                    const SizedBox(height: 8),
                    _alertButton('🚧 Road Blocked (0xE7)', Colors.amber, "Road is blocked! Seek alternate route."),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertButton(String label, Color color, String phrase) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _send(phrase),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withAlpha(35),
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }
}

// =====================================================================
// TAB 3: RECEIVE PAGE (Radar Proximity + Bearing + Multi-Language Translation)
// =====================================================================
class ReceivePage extends StatefulWidget {
  final MeshEngine mesh;
  const ReceivePage({super.key, required this.mesh});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  MeshEngine get m => widget.mesh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📲 Receive & Compass')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preferred Target Language Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: m.preferredLang,
                  decoration: const InputDecoration(
                    labelText: '🌐 My Preferred Language (Auto-Translate To)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: m.langNames.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        m.preferredLang = v;
                        m.lastRxTranslated = m.translate(m.lastRxText, v);
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Received Messages List
            if (m.rxHistory.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text('No messages received yet.\nNearby devices will auto-connect via Wi-Fi Direct or local Wi-Fi.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ),
                ),
              )
            else
              ...m.rxHistory.map((rx) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Sender, Time, Transport Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('From: ${rx['sender']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Row(
                            children: [
                              Chip(label: Text('${rx['transport']}', style: const TextStyle(fontSize: 10)), backgroundColor: Colors.cyan.withAlpha(40)),
                              const SizedBox(width: 4),
                              Text('${rx['time']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // PROXIMITY & COMPASS BEARING RADAR CARD
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withAlpha(100)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.explore, color: Colors.amber, size: 20),
                                const SizedBox(width: 6),
                                Text('Distance: ${rx['distance_str']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13)),
                                const Spacer(),
                                Text('📍 ${rx['lat'].toStringAsFixed(4)}, ${rx['lng'].toStringAsFixed(4)}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.cyan)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('🧭 Heading to Sender: ${rx['direction_to_sender']}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                            Text('🔄 Heading from Sender to You: ${rx['direction_to_receiver']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Language Tag Pill
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.blue.withAlpha(40), borderRadius: BorderRadius.circular(4)),
                            child: Text('Spoken: [${(rx['src_lang'] as String).toUpperCase()}] ${rx['src_lang_name']}', style: const TextStyle(fontSize: 11, color: Colors.blueAccent)),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.green.withAlpha(40), borderRadius: BorderRadius.circular(4)),
                            child: Text('Translated: [${(rx['target_lang'] as String).toUpperCase()}]', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Original Text
                      Text('Original: "${rx['text']}"', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.white70)),
                      const SizedBox(height: 6),

                      // Translated Text with Voice Button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.cyan.withAlpha(25), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.cyan.withAlpha(60))),
                        child: Row(
                          children: [
                            Expanded(child: Text('🔊 "${rx['translated']}"', style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 13))),
                            IconButton(
                              icon: const Icon(Icons.volume_up, color: Colors.cyan, size: 22),
                              onPressed: () => m.speakText(rx['translated']),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Payload: ${rx['bytes']} Bytes • Wi-Fi Mesh Relay (TTL: 3)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// TAB 4: PEERS PAGE (Wi-Fi Mesh Health + Peer List + Logs)
// =====================================================================
class PeersPage extends StatefulWidget {
  final MeshEngine mesh;
  const PeersPage({super.key, required this.mesh});

  @override
  State<PeersPage> createState() => _PeersPageState();
}

class _PeersPageState extends State<PeersPage> {
  MeshEngine get m => widget.mesh;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔗 Wi-Fi Mesh Peers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyan),
            tooltip: 'Restart Mesh',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restarting Wi-Fi Transceiver...')));
              await m.restartMesh();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Card(
              color: const Color(0xFF1E293B),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(m.isAdvertising ? Icons.radar : Icons.wifi_off, color: m.isAdvertising ? Colors.green : Colors.red, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.isAdvertising ? 'Wi-Fi Direct P2P_STAR Active' : 'Wi-Fi Transceiver Initializing...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('Direct Wi-Fi range up to 100m. No internet or hotspot needed.', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                          const SizedBox(height: 4),
                          Text('Direct: ${m.isAdvertising ? "✅" : "❌"} | UDP Wi-Fi: ${m.isUdpActive ? "✅ (:45454)" : "❌"}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.cyan)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text('Connected Wi-Fi Peers (${m.peers.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),

            if (m.peers.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.wifi_find, size: 44, color: Colors.cyan),
                        const SizedBox(height: 12),
                        const Text('Scanning for nearby iTantra devices...', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Make sure both devices have Wi-Fi turned ON.\nNo router or hotspot connection is needed.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await m.restartMesh();
                            if (mounted) setState(() {});
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Restart Transceiver'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...m.peers.entries.map((e) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.phone_android, color: Colors.cyan),
                  title: Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('ID: ${e.key.length > 8 ? e.key.substring(0, 8) : e.key}... • High-Range Wi-Fi Link', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.wifi_tethering, color: Colors.green),
                ),
              )),

            const SizedBox(height: 16),

            // Mesh Activity Log
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📋 Mesh Event Log', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      height: 180,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                      child: m.logs.isEmpty
                          ? const Center(child: Text('Awaiting activity...', style: TextStyle(color: Colors.grey, fontSize: 12)))
                          : ListView.builder(
                              itemCount: m.logs.length,
                              itemBuilder: (c, i) => Text(m.logs[i], style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.cyan)),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
