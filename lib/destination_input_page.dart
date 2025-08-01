import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:avatar_glow/avatar_glow.dart'; // 추가된 패키지


import 'package:app_tayo_taxi/pickup_place_list_page.dart';
import 'user_profile_page.dart';
import 'bookmark_places_page.dart';

final String kGoogleApiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
final String kGeminiApiKey = dotenv.env['GOOGLE_GEMINI_API_KEY'] ?? '';

class DestinationInputPage extends StatefulWidget {
  const DestinationInputPage({super.key});

  @override
  State<DestinationInputPage> createState() => _DestinationInputPageState();
}

bool isListening = false;

class _DestinationInputPageState extends State<DestinationInputPage> {
  String currentAddress = '출발지를 불러오는 중...';
  latlng.LatLng? currentLatLng;
  latlng.LatLng? destinationLatLng;
  final TextEditingController destinationController = TextEditingController();
  List<String> suggestions = [];
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processVoiceWithAI());
  }

  Future<void> _processVoiceWithAI() async {
    await _flutterTts.setLanguage("ko-KR");

    for (int attempt = 0; attempt < 3; attempt++) {
      await _speakAndWait("어디로 가고 싶으신가요?");
      await Future.delayed(const Duration(milliseconds: 400));

      final available = await _speech.initialize();
      if (!available) {
        await _flutterTts.speak("음성 인식을 사용할 수 없습니다.");
        return;
      }

      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 300));

      final speechCompleter = Completer<String>();
      bool alreadyCompleted = false;

      // 🔵 음성 인식 시작 표시
      setState(() => isListening = true);

      await _speech.listen(
        localeId: "ko_KR",
        listenMode: stt.ListenMode.dictation,
        onResult: (result) {
          if (!alreadyCompleted && result.finalResult && result.recognizedWords
              .trim()
              .isNotEmpty) {
            alreadyCompleted = true;
            speechCompleter.complete(result.recognizedWords.trim());
          }
        },
      );

      final userSpeech = await speechCompleter.future.timeout(
        const Duration(seconds: 7),
        onTimeout: () => '',
      );

      // 🔴 음성 인식 종료 표시
      setState(() => isListening = false);

      print("🗣 목적지 음성 입력 결과: '$userSpeech'");

      if (userSpeech.length < 2) {
        await _speakAndWait("말씀을 인식하지 못했어요. 다시 말씀해주시겠어요?");
        continue;
      }

      final userSpeechLower = userSpeech.toLowerCase();
      final homePatterns = [
        "집", "집으로", "집에", "우리 집", "집 가고", "집에 가고", "집으로 가고 싶어"
      ];
      final isGoingHome = homePatterns.any((phrase) =>
          userSpeechLower.contains(phrase));

      if (isGoingHome) {
        final homeData = await _loadHomeBookmark();
        if (homeData != null) {
          setState(() {
            destinationController.text = homeData['placeName'];
            destinationLatLng = latlng.LatLng(homeData['lat'], homeData['lng']);
          });
          await _speakAndWait("집으로 설정했어요. 다음 버튼을 눌러주세요.");
          return;
        } else {
          await _speakAndWait("집 주소가 설정되어 있지 않아요. 즐겨찾기에서 집을 설정해주세요.");
          continue;
        }
      }

      final extractedPlace = await _getPlaceFromGemini(userSpeech);
      print("📍 추출된 장소: '$extractedPlace'");

      if (extractedPlace == null || extractedPlace
          .trim()
          .length < 2) {
        await _speakAndWait("죄송합니다. 장소를 이해하지 못했어요. 다시 말씀해주세요.");
        continue;
      }

      await _speakAndWait("$extractedPlace로 가고 싶으신가요? 네 또는 아니요로 대답해주세요.");
      await Future.delayed(const Duration(milliseconds: 500));
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 300));

      final confirmCompleter = Completer<String>();
      bool confirmCompleted = false;

      // 🔵 확인 음성 인식 시작
      setState(() => isListening = true);

      await _speech.listen(
        localeId: "ko_KR",
        listenMode: stt.ListenMode.confirmation,
        onResult: (result2) {
          if (!confirmCompleted && result2.finalResult &&
              result2.recognizedWords
                  .trim()
                  .isNotEmpty) {
            confirmCompleted = true;
            confirmCompleter.complete(result2.recognizedWords.trim());
          }
        },
      );

      final confirmation = await confirmCompleter.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () => '',
      );

      // 🔴 확인 음성 인식 종료
      setState(() => isListening = false);

      final lowerConfirm = confirmation.toLowerCase().replaceAll(
          RegExp(r'[^\uAC00-\uD7A3a-z0-9]'), '');
      print("✅ 사용자 확인 응답: '$lowerConfirm'");

      final yesPatterns = ["네", "예", "응", "넵", "그래", "좋아요", "네네", "네에요"];
      final noPatterns = ["아니요", "아니", "싫어요", "노", "아뇨"];

      final isYes = yesPatterns.any((p) => lowerConfirm.contains(p));
      final isNo = noPatterns.any((p) => lowerConfirm.contains(p));

      if (isYes) {
        setState(() {
          destinationController.text = extractedPlace;
        });
        await _fetchPlaceSuggestions(extractedPlace);
        await _speakAndWait(
            "$extractedPlace로 설정했어요. 정확한 위치를 선택해주고, 다음 버튼을 눌러주세요.");
        return;
      } else if (isNo) {
        await _speakAndWait("알겠습니다. 다시 여쭤볼게요.");
        continue;
      } else {
        await _speakAndWait("죄송해요, 네 또는 아니요로 말씀해주세요.");
        continue;
      }
    }

    await _speakAndWait("죄송합니다. 목적지를 직접 입력해주세요.");
  }

  Future<void> _speakAndWait(String message) async {
    await _flutterTts.speak(message);
    bool isSpeaking = true;
    _flutterTts.setCompletionHandler(() {
      isSpeaking = false;
    });

    // 최대 10초까지 대기
    for (int i = 0; i < 100; i++) {
      if (!isSpeaking) break;
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  Future<String?> _getPlaceFromGemini(String inputText) async {
    final response = await http.post(
      Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$kGeminiApiKey'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": "다음 문장에서 한국어 장소명만 추출해 주세요. 장소가 없으면 'NONE'이라고만 말해주세요: '$inputText'"
              }
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final text = json['candidates'][0]['content']['parts'][0]['text'] as String;
      final cleaned = text
          .replaceAll('\n', '')
          .trim();
      return cleaned.toLowerCase() == 'none' ? null : cleaned;
    } else {
      print("❌ Gemini 호출 실패: ${response.body}");
      return null;
    }
  }


  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => currentAddress = '위치 서비스 비활성화됨');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => currentAddress = '위치 권한이 거부되었습니다');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => currentAddress = '위치 권한이 영구적으로 거부되었습니다');
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = '${place.administrativeArea} ${place.locality} ${place
            .street}';
        setState(() {
          currentAddress = address;
          currentLatLng = latlng.LatLng(position.latitude, position.longitude);
        });
      } else {
        setState(() => currentAddress = '주소 정보를 찾을 수 없습니다');
      }
    } catch (e) {
      setState(() => currentAddress = '주소 변환 실패: $e');
    }
  }

  Future<void> _fetchPlaceSuggestions(String input) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$kGoogleApiKey&language=ko&components=country:kr';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final predictions = data['predictions'] as List;
        setState(() {
          suggestions =
              predictions.map((p) => p['description'] as String).toList();
        });
      } else {
        setState(() => suggestions = []);
      }
    } catch (e) {
      setState(() => suggestions = []);
    }
  }

  Future<void> _selectSuggestion(String suggestion) async {
    destinationController.text = suggestion;
    await _convertAddressToLatLng(suggestion);
    setState(() => suggestions.clear());
  }

  Future<Map<String, dynamic>?> _loadHomeBookmark() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .where('isHome', isEqualTo: true)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      return snap.docs.first.data();
    } else {
      return null;
    }
  }

  Future<void> _convertAddressToLatLng(String address) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri
        .encodeComponent(address)}&key=$kGoogleApiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final location = results.first['geometry']['location'];
          setState(() {
            destinationLatLng = latlng.LatLng(location['lat'], location['lng']);
          });
        } else {
          setState(() => destinationLatLng = null);
        }
      }
    } catch (e) {
      setState(() => destinationLatLng = null);
    }
  }

  Future<void> _goHomeAndNavigate() async {
    if (currentLatLng == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .where('isHome', isEqualTo: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('집 주소가 설정되지 않았습니다.')),
      );
      return;
    }

    final data = snap.docs.first.data();
    final homeLat = data['lat'] as double;
    final homeLng = data['lng'] as double;
    final homeName = data['placeName'] as String;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PickupListPage(
              currentLocation: currentLatLng!,
              destinationLocation: latlng.LatLng(homeLat, homeLng),
              suggestedPlaceName: homeName,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final double screenHeight = MediaQuery
        .of(context)
        .size
        .height;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.067),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.local_taxi, size: screenWidth * 0.278,
                          color: Colors.green),
                      SizedBox(height: screenHeight * 0.025),
                      AutoSizeText(
                        '출발/도착지 설정',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: screenWidth * 0.094,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        minFontSize: 16,
                      ),
                      SizedBox(height: screenHeight * 0.050),
                      TextField(
                        readOnly: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.my_location),
                          labelText: '출발지: $currentAddress',
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 22.0, horizontal: 16.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.025),
                      TextField(
                        controller: destinationController,
                        onChanged: _fetchPlaceSuggestions,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.place),
                          labelText: '목적지 입력',
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 22.0, horizontal: 16.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.013),
                      ...suggestions.map((s) =>
                          ListTile(
                            title: Text(s),
                            onTap: () => _selectSuggestion(s),
                          )),
                      SizedBox(height: screenHeight * 0.025),
                      ElevatedButton(
                        onPressed: () async {
                          if (currentLatLng == null) return;
                          if (destinationLatLng == null &&
                              destinationController.text.isNotEmpty) {
                            await _convertAddressToLatLng(
                                destinationController.text);
                          }
                          if (destinationLatLng == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('목적지를 선택하거나 입력해주세요.')),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PickupListPage(
                                    currentLocation: currentLatLng!,
                                    destinationLocation: destinationLatLng!,
                                    suggestedPlaceName: destinationController
                                        .text,
                                  ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade200,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: TextStyle(
                              fontSize: screenWidth * 0.050,
                              fontWeight: FontWeight.bold),
                        ),
                        child: Text('다음', style: TextStyle(
                            fontSize: screenWidth * 0.056)),
                      ),
                      SizedBox(height: screenHeight * 0.037),
                      Center(
                        child: ElevatedButton(
                          onPressed: () async {
                            final result = await Navigator.push<
                                Map<String, dynamic>>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const BookmarkPlacesPage()),
                            );
                            if (result != null) {
                              setState(() {
                                destinationController.text =
                                result['placeName'];
                                destinationLatLng = latlng.LatLng(
                                  result['lat'],
                                  result['lng'],
                                );
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.grey),
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 40),
                            minimumSize: const Size(180, 55),
                            textStyle: TextStyle(
                              fontSize: screenWidth * 0.050,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const AutoSizeText('즐겨찾기', maxLines: 1,
                              minFontSize: 14),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.025),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: Icon(Icons.person, size: screenWidth * 0.078,
                    color: Colors.black),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyPage()),
                  );
                },
              ),
            ),

            // 🔵 AvatarGlow 음성 인식 시각화 추가
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: AvatarGlow(
                  glowColor: Colors.green,
                  endRadius: 50.0,
                  animate: isListening,
                  duration: const Duration(milliseconds: 2000),
                  repeatPauseDuration: const Duration(milliseconds: 100),
                  repeat: true,
                  child: Material(
                    elevation: 4.0,
                    shape: const CircleBorder(),
                    child: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      radius: 28.0,
                      child: Icon(
                        Icons.mic,
                        size: 28.0,
                        color: isListening ? Colors.green.shade900 : Colors
                            .grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}