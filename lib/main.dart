import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LocalFreeTalkApp());
}

class LocalFreeTalkApp extends StatelessWidget {
  const LocalFreeTalkApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LocalFreeTalk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        fontFamily: 'Roboto',
      ),
      home: const TranslationScreen(),
    );
  }
}

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({Key? key}) : super(key: key);

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isListening = false;
  bool _isTranslating = false;
  bool _isModelsReady = false;
  bool _hasError = false;

  String _recognizedText = '마이크 버튼을 누르고 말씀하세요.';
  String _translatedText = '번역 결과가 여기에 표시됩니다.';
  String _statusMessage = 'Checking AI Models...';

  final Map<String, Map<String, dynamic>> _languages = {
    'English': {
      'translate': TranslateLanguage.english,
      'stt': 'en_US',
      'tts': 'en-US',
    },
    'Korean (한국어)': {
      'translate': TranslateLanguage.korean,
      'stt': 'ko_KR',
      'tts': 'ko-KR',
    },
    'Vietnamese (Tiếng Việt)': {
      'translate': TranslateLanguage.vietnamese,
      'stt': 'vi_VN',
      'tts': 'vi-VN',
    },
  };

  String _sourceLangKey = 'English';
  String _targetLangKey = 'Korean (한국어)';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeModels();
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  // 현재 선택된 출발어/도착어 모델을 우선 다운로드한 뒤 나머지 언어 준비
  Future<void> _initializeModels() async {
    if (!mounted) return;
    setState(() {
      _hasError = false;
      _isModelsReady = false;
      _statusMessage = 'Checking AI Models...';
    });

    final modelManager = OnDeviceTranslatorModelManager();
    final orderedKeys = <String>{
      _sourceLangKey,
      _targetLangKey,
      ..._languages.keys,
    };

    try {
      for (final key in orderedKeys) {
        final TranslateLanguage lang =
            _languages[key]!['translate'] as TranslateLanguage;
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Downloading $key Model...';
        });

        final bool isDownloaded = await modelManager.isModelDownloaded(
          lang.bcpCode,
        );
        if (!isDownloaded) {
          await modelManager.downloadModel(lang.bcpCode);
        }
      }

      if (!mounted) return;
      setState(() {
        _isModelsReady = true;
        _hasError = false;
        _statusMessage = 'All Offline AI Models Ready';
      });
    } on MissingPluginException catch (e) {
      if (!mounted) return;
      setState(() {
        _isModelsReady = false;
        _hasError = true;
        _statusMessage =
            '플러그인 연결 오류(${e.message ?? 'MissingPluginException'}) - 재빌드 필요';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isModelsReady = false;
        _hasError = true;
        _statusMessage = '모델 다운로드 실패 (탭하여 재시도): $e';
      });
    }
  }

  // 번역 및 TTS 출력
  Future<void> _translateAndSpeak(String text) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty || _isTranslating) return;

    if (!_isModelsReady) {
      if (!mounted) return;
      setState(() {
        _translatedText = 'AI 모델이 아직 준비되지 않았습니다. 상단 상태 배지를 눌러 확인해 주세요.';
      });
      return;
    }

    _isTranslating = true;
    try {
      final TranslateLanguage srcLang =
          _languages[_sourceLangKey]!['translate'] as TranslateLanguage;
      final TranslateLanguage tgtLang =
          _languages[_targetLangKey]!['translate'] as TranslateLanguage;

      final translator = OnDeviceTranslator(
        sourceLanguage: srcLang,
        targetLanguage: tgtLang,
      );
      final String translation = await translator.translateText(trimmed);
      await translator.close();

      if (!mounted) return;
      setState(() {
        _translatedText = translation;
      });

      try {
        final String ttsCode = _languages[_targetLangKey]!['tts'] as String;
        await _flutterTts.stop();
        await _flutterTts.setLanguage(ttsCode);
        await _flutterTts.speak(translation);
      } on MissingPluginException {
        // TTS 플러그인 미연결 시에도 번역 텍스트는 정상 표시 유지
      } catch (_) {}
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _translatedText = '번역 플러그인 연결이 되지 않았습니다. 앱을 다시 빌드해 주세요.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _translatedText = '번역 오류: $e';
      });
    } finally {
      _isTranslating = false;
    }
  }

  // 마이크 버튼 토글 (누르면 듣기 시작, 다시 누르면 종료 및 번역)
  Future<void> _listen() async {
    if (!_isListening) {
      try {
        final bool available = await _speech.initialize(
          onStatus: (status) {
            if ((status == 'done' || status == 'notListening') && mounted) {
              setState(() => _isListening = false);
            }
          },
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _isListening = false;
              _recognizedText = '음성 인식 오류: ${error.errorMsg}';
            });
          },
        );

        if (!available) {
          if (!mounted) return;
          setState(() {
            _recognizedText = '마이크 권한이 없거나 기기에서 음성 인식을 지원하지 않습니다.';
          });
          return;
        }

        if (!mounted) return;
        setState(() {
          _isListening = true;
          _recognizedText = '듣는 중... 말씀해 주세요';
        });

        final String sttCode = _languages[_sourceLangKey]!['stt'] as String;
        await _speech.listen(
          localeId: sttCode,
          onResult: (val) {
            if (!mounted) return;
            setState(() {
              _recognizedText = val.recognizedWords;
            });
            if (val.finalResult && val.recognizedWords.isNotEmpty) {
              _translateAndSpeak(val.recognizedWords);
            }
          },
        );
      } on MissingPluginException {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _recognizedText = '음성 인식(STT) 플러그인이 연결되지 않았습니다.';
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _recognizedText = '음성 인식 시작 실패: $e';
        });
      }
    } else {
      setState(() => _isListening = false);
      try {
        await _speech.stop();
      } catch (_) {}

      if (_recognizedText.trim().isNotEmpty &&
          !_recognizedText.startsWith('듣는 중')) {
        await _translateAndSpeak(_recognizedText);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _hasError
        ? const Color(0xFFEF4444)
        : (_isModelsReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LocalFreeTalk',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 모델 준비 상태 배지 (에러 시 탭하면 재시도)
              Center(
                child: GestureDetector(
                  onTap: _initializeModels,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: statusColor.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. 언어 선택 바 (출발어 -> 도착어)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: _sourceLangKey,
                      dropdownColor: const Color(0xFF1E293B),
                      underline: const SizedBox(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      items: _languages.keys.map((String lang) {
                        return DropdownMenuItem<String>(
                          value: lang,
                          child: Text(lang),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null && newValue != _sourceLangKey) {
                          setState(() {
                            _sourceLangKey = newValue;
                          });
                          _initializeModels();
                        }
                      },
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF818CF8),
                      size: 20,
                    ),
                    DropdownButton<String>(
                      value: _targetLangKey,
                      dropdownColor: const Color(0xFF1E293B),
                      underline: const SizedBox(),
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                      ),
                      items: _languages.keys.map((String lang) {
                        return DropdownMenuItem<String>(
                          value: lang,
                          child: Text(lang),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null && newValue != _targetLangKey) {
                          setState(() {
                            _targetLangKey = newValue;
                          });
                          _initializeModels();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. 입력 텍스트 카드
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.language_rounded,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Input ($_sourceLangKey)',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Text(
                              _recognizedText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. 번역 결과 카드
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6366F1).withOpacity(0.15),
                        const Color(0xFF8B5CF6).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: Color(0xFF818CF8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Translation ($_targetLangKey)',
                            style: const TextStyle(
                              color: Color(0xFF818CF8),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Text(
                              _translatedText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 5. 하단 마이크 버튼
              SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _listen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor:
                        (_isListening
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF6366F1))
                            .withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    size: 24,
                  ),
                  label: Text(
                    _isListening ? 'Listening... Tap to Stop' : 'Tap & Speak',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
