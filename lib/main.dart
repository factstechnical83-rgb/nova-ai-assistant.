import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const NovaApp());
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030712),
      ),
      home: const NovaVoiceScreen(),
    );
  }
}

class NovaVoiceScreen extends StatefulWidget {
  const NovaVoiceScreen({super.key});

  @override
  State<NovaVoiceScreen> createState() => _NovaVoiceScreenState();
}

class _NovaVoiceScreenState extends State<NovaVoiceScreen>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  late AnimationController _animController;

  bool _isListening = false;
  bool _isThinking = false;
  String _userText = "Listening for your voice...";
  String _aiResponse = "Ready";

  // Build time par GitHub Secrets se pass kiya gaya key
  static const String apiKey = String.fromEnvironment('GEMINI_API_KEY');

  GenerativeModel? _model;
  ChatSession? _chat;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initAi();
    _initTts();
  }

  void _initAi() {
    if (apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(
          "Aapka naam NOVA hai. Aap ek advanced, empathetic aur caring sci-fi AI companion hain. "
          "Hamesha natural Hindi/Hinglish mein dosti bhare lehze me jawab dein. "
          "Voice conversation hai isliye answers short, interactive aur clear rakhein.",
        ),
      );
      _chat = _model!.startChat();
    }
  }

  void _initTts() async {
    await _tts.setLanguage("hi-IN");
    await _tts.setPitch(1.1);
    await _tts.setSpeechRate(0.9);
  }

  Future<void> _listen() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;

    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
            if (_userText.isNotEmpty && _userText != "Listening...") {
              _sendToGemini(_userText);
            }
          }
        },
        onError: (val) => setState(() => _isListening = false),
      );

      if (available) {
        setState(() {
          _isListening = true;
          _userText = "Listening...";
        });
        _speech.listen(
          localeId: "hi_IN",
          onResult: (val) {
            setState(() {
              _userText = val.recognizedWords;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _sendToGemini(String message) async {
    if (_chat == null) {
      setState(() => _aiResponse = "API Key not configured properly.");
      return;
    }

    setState(() => _isThinking = true);
    try {
      final response = await _chat!.sendMessage(Content.text(message));
      final reply = response.text ?? "Main samajh nahi paayi, dubara boliye?";
      setState(() {
        _aiResponse = reply;
        _isThinking = false;
      });
      await _tts.speak(reply);
    } catch (e) {
      setState(() {
        _aiResponse = "Error connecting to AI service.";
        _isThinking = false;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Icon(Icons.menu, color: Colors.white70),
        title: const Text("NOVA AI", style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: const [
          Icon(Icons.memory, color: Colors.cyanAccent),
          SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              _isThinking ? "Thinking..." : _aiResponse,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          // Glowing Sci-Fi Visualizer Orb
          Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                double scale = _isListening
                    ? 1.0 + (_animController.value * 0.25)
                    : (_isThinking ? 0.95 + (_animController.value * 0.1) : 1.0);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: _isListening
                            ? [Colors.cyanAccent, Colors.purpleAccent, Colors.transparent]
                            : [Colors.blueAccent.shade400, Colors.deepPurple, Colors.transparent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isListening
                              ? Colors.cyanAccent.withOpacity(0.6)
                              : Colors.blueAccent.withOpacity(0.4),
                          blurRadius: 40,
                          spreadRadius: 15,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.waves, size: 70, color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          const Spacer(),
          Text(
            _isListening ? "Listening..." : "Tap mic to talk",
            style: const TextStyle(color: Colors.white38, letterSpacing: 1.5),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _listen,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening ? Colors.redAccent : Colors.cyanAccent.shade700,
                boxShadow: [
                  BoxShadow(
                    color: _isListening
                        ? Colors.redAccent.withOpacity(0.5)
                        : Colors.cyanAccent.withOpacity(0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop : Icons.mic,
                size: 34,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
