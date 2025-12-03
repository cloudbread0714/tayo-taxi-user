import 'dart:convert';
import 'dart:async';
import 'dart:async' show Timer;
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
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
bool waitingForConfirmation = false;
String? extractedPlaceForConfirmation;

class _DestinationInputPageState extends State<DestinationInputPage> {
  String currentAddress = '출발지를 불러오는 중...';
  latlng.LatLng? currentLatLng;
  latlng.LatLng? destinationLatLng;
  final TextEditingController destinationController = TextEditingController();
  List<Map<String, dynamic>> suggestions = <Map<String, dynamic>>[];
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  late TutorialCoachMark tutorialCoachMark;
  List<TargetFocus> targets = [];

  // GlobalKey들을 클래스 내부로 이동
  final GlobalKey destinationFieldKey = GlobalKey();
  final GlobalKey micButtonKey = GlobalKey();
  final GlobalKey nextButtonKey = GlobalKey();

    @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("ko-KR");
    
    // 위젯이 완전히 빌드된 후 첫 번째 튜토리얼 시작 (로그인 후 1회만)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowFirstTutorial(context);
    });
  }

  Future<void> _processVoiceWithAI() async {
    if (waitingForConfirmation && extractedPlaceForConfirmation != null) {
      // ✅ 네/아니요 응답 처리
      await _handleConfirmationInput();
    } else {
      // ✅ 목적지 인식 단계
      await _handleDestinationInput();
    }
  }

  Future<void> _handleDestinationInput() async {
    final available = await _speech.initialize();
    if (!available) {
      await _speakAndWait("음성 인식을 사용할 수 없습니다.");
      return;
    }
    await Future.delayed(Duration(milliseconds: 300));

    setState(() => isListening = true);
    final result = await _listenOnce();
    setState(() => isListening = false);

    print("인식된 음성: '$result' (길이: ${result.length})");
    
    if (result.isEmpty || result.length < 2) {
      _showBottomPopup("말씀을 인식하지 못했어요. 다시 눌러주세요.");
      await _speakAndWait("말씀을 인식하지 못했어요. 다시 눌러주세요.");
      return;
    }

    // 집 처리 생략 가능
    final isGoingHome = ["집", "우리 집", "집에"].any((p) => result.contains(p));
    if (isGoingHome) {
      final home = await _loadHomeBookmark();
      if (home != null) {
        destinationController.text = home['placeName'];
        destinationLatLng = latlng.LatLng(home['lat'], home['lng']);
        _showBottomPopup("집으로 설정했어요. 다음 버튼을 눌러주세요.");
        await _speakAndWait("집으로 설정했어요. 다음 버튼을 눌러주세요.");
      } else {
        _showBottomPopup("집 주소가 설정되어 있지 않아요.");
        await _speakAndWait("집 주소가 설정되어 있지 않아요.");
      }
      return;
    }

    final extracted = await _getPlaceFromGemini(result);
    if (extracted == null || extracted.length < 2) {
      _showBottomPopup("죄송합니다. 장소를 이해하지 못했어요.");
      await _speakAndWait("죄송합니다. 장소를 이해하지 못했어요.");
      return;
    }

    // 👉 다음 클릭 시 네/아니요로 넘어가게 준비
    extractedPlaceForConfirmation = extracted;
    waitingForConfirmation = true;
    _showBottomPopup("$extracted 이(가) 맞으신가요?"); 
    await _speakAndWait("$extracted 이(가) 맞으신가요?");
    
    // 팝업이 닫힌 후 자동으로 음성인식 시작 (초 후)
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && waitingForConfirmation) {
        _handleConfirmationInput();
      }
    });
  }

  Future<void> _handleConfirmationInput() async {
    final available = await _speech.initialize();
    if (!available) {
      await _speakAndWait("음성 인식을 사용할 수 없습니다.");
      return;
    }

    await Future.delayed(Duration(milliseconds: 300));

    // 바로 음성인식 시작 (추가 안내 없이)
    setState(() => isListening = true);
    final result = await _listenOnce();
    setState(() => isListening = false);

    final answer = result.toLowerCase().replaceAll(RegExp(r'[^\uAC00-\uD7A3a-z0-9]'), '');
    final yes = ["네", "예", "응", "그래", "좋아", "맞아", "맞습니다"].any((e) => answer.contains(e));
    final no = ["아니", "노", "싫"].any((e) => answer.contains(e));
    
    print("확인 응답: $result");

    if (yes) {
      destinationController.text = extractedPlaceForConfirmation!;
      // 자동완성 리스트는 표시하지 않고 바로 첫 번째 항목 선택
      await _convertAddressToLatLng(extractedPlaceForConfirmation!);
      _showBottomPopup("${extractedPlaceForConfirmation!}로 설정했어요.");
      await _speakAndWait("${extractedPlaceForConfirmation!}로 설정했어요.");
    } else if (no) {
      _showBottomPopup("알겠습니다. 다시 말씀해주세요.");
      await _speakAndWait("알겠습니다. 다시 말씀해주세요.");
      
      // 다시 음성인식 시작 (3초 후)
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && waitingForConfirmation) {
          _handleDestinationInput();
        }
      });
    } else {
      _showBottomPopup("죄송해요. 다시 말씀해주세요.");
      await _speakAndWait("죄송해요. 다시 말씀해주세요.");
      
      // 다시 음성인식 시작 (3초 후)
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && waitingForConfirmation) {
          _handleConfirmationInput();
        }
      });
      return;
    }

    // 초기화
    waitingForConfirmation = false;
    extractedPlaceForConfirmation = null;
  }


  Future<String?> _getPlaceFromGemini(String inputText) async {
    print("Gemini API 호출: '$inputText'");
    
    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$kGeminiApiKey'),
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
      print("Gemini API 응답: '$cleaned'");
      return cleaned.toLowerCase() == 'none' ? null : cleaned;
    } else {
      print("❌ Gemini 호출 실패: ${response.statusCode} - ${response.body}");
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
    if (input.isEmpty) {
      setState(() => suggestions = <Map<String, dynamic>>[]);
      return;
    }

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': input,
        'key': kGoogleApiKey,
        'language': 'ko',
        'components': 'country:kr',
      },
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final preds = data['predictions'] as List;

        setState(() {
          suggestions = preds.map((p) {
            final fmt = p['structured_formatting'];
            return {
              'placeId': p['place_id'],
              'placeName': fmt['main_text'],
              'address': fmt['secondary_text'],
            };
          }).toList();
        });
      } else {
        setState(() => suggestions = <Map<String, dynamic>>[]);
      }
    } catch (e) {
      setState(() => suggestions = <Map<String, dynamic>>[]);
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    destinationController.text = suggestion['placeName'];
    await _convertAddressToLatLng(
      "${suggestion['address']} ${suggestion['placeName']}",
    );
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

  Future<void> _speakAndWait(String message) async {
    await _flutterTts.speak(message);

    bool isSpeaking = true;
    _flutterTts.setCompletionHandler(() {
      isSpeaking = false;
    });

    for (int i = 0; i < 100; i++) {
      if (!isSpeaking) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _showBottomPopup(String message) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (BuildContext context) {
        return Container(
          margin: EdgeInsets.only(
            left: screenWidth * 0.05,
            right: screenWidth * 0.05,
            bottom: screenHeight * 0.15, // 하단 여백을 늘려서 더 위로 올림
          ),
          padding: EdgeInsets.all(screenWidth * 0.05),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        );
      },
    );
    
    // 3초 후 자동으로 닫기
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<String> _listenOnce() async {
    final completer = Completer<String>();
    bool gotResult = false;

    print("음성인식 시작...");
    
    await _speech.listen(
      localeId: "ko_KR",
      listenMode: stt.ListenMode.confirmation,
      onResult: (result) {
        print("음성인식 결과: '${result.recognizedWords}' (최종: ${result.finalResult})");
        if (!gotResult && result.finalResult && result.recognizedWords.isNotEmpty) {
          gotResult = true;
          print("음성인식 완료: '${result.recognizedWords.trim()}'");
          completer.complete(result.recognizedWords.trim());
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 10), // 타임아웃 시간 증가
      onTimeout: () {
        print("음성인식 타임아웃");
        return '';
      },
    );
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
                      Row(
                        key: destinationFieldKey, // Row에 GlobalKey 추가
                        children: [
                                                      Expanded(
                              child: TextField(
                                controller: destinationController,
                              onChanged: _fetchPlaceSuggestions,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.place),
                                labelText: '목적지 입력',
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.027,
                                  horizontal: screenWidth * 0.04,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: _processVoiceWithAI,
                            child: Container(
                              key: micButtonKey, // GlobalKey를 Container에 직접 부여
                              width: 50,
                              height: 20 + (screenHeight * 0.027 * 2), // TextField 높이와 맞춤
                              decoration: BoxDecoration(
                                color: isListening ? Colors.red.shade100 : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isListening ? Colors.red : Colors.grey,
                                  width: isListening ? 2 : 1,
                                ),
                                boxShadow: isListening ? [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ] : null,
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Icon(
                                      Icons.mic,
                                      size: screenWidth * 0.07,
                                      color: isListening
                                          ? Colors.red.shade700
                                          : Colors.green.shade900,
                                    ),
                                  ),
                                  if (isListening)
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.013),
                      ...suggestions.map((s) =>
                          ListTile(
                            title: Text(
                              s['placeName'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(s['address'] ?? ''),
                            onTap: () => _selectSuggestion(s),
                          ),
                      ),
                      SizedBox(height: screenHeight * 0.025),
                      ElevatedButton(
                        key: nextButtonKey,
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
          ],
        ),
      ),
    );
  }

  void _showFirstTutorial(BuildContext context) {
    final double screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final double screenHeight = MediaQuery
        .of(context)
        .size
        .height;

    targets.clear();
    targets.addAll([
      TargetFocus(
        identify: "input_area",
        keyTarget: destinationFieldKey, // 목적지 입력 칸을 기준으로 큰 영역 설정
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "이 곳에 가고 싶은 장소를 입력하세요",
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  "칸을 터치하세요",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: screenWidth * 0.035,
                  ),
                )
              ],
            ),
          ),
          TargetContent(
            align: ContentAlign.top, // 또는 topCenter
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end, // 오른쪽 정렬
              children: [
                Text(
                  "마이크 버튼을 눌러서\n직접 말할 수도 있어요",
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    ]);

    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black.withOpacity(0.8),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        // 첫 번째 튜토리얼 완료 후 두 번째 튜토리얼 시작
        _showSecondTutorial(context);
      },
      onClickTarget: (target) {
        print("첫 번째 튜토리얼 타겟 클릭: ${target.identify}");
        tutorialCoachMark.next();
        return true;
      },
      onClickOverlay: (target) {
        print("첫 번째 튜토리얼 오버레이 클릭: ${target.identify}");
        tutorialCoachMark.next();
        return true;
      },
      onSkip: () {
        _showSecondTutorial(context);
        return true;
      },
      hideSkip: true,
    );

    tutorialCoachMark.show(context: context);
  }

  void _showSecondTutorial(BuildContext context) {
    final double screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final double screenHeight = MediaQuery
        .of(context)
        .size
        .height;

    targets.clear();
    targets.addAll([
      TargetFocus(
        identify: "next",
        keyTarget: nextButtonKey,
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "목적지를 입력했다면 이 버튼을 눌러주세요",
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  "버튼을 터치하세요",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: screenWidth * 0.035,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    ]);

    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black.withOpacity(0.8),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        _flutterTts.speak("어디로 가고 싶으신가요?"); // 튜토리얼 완료 후 안내
      },
      onClickTarget: (target) {
        print("두 번째 튜토리얼 타겟 클릭: ${target.identify}");
        tutorialCoachMark.next();
        return true;
      },
      onClickOverlay: (target) {
        print("두 번째 튜토리얼 오버레이 클릭: ${target.identify}");
        tutorialCoachMark.next();
        return true;
      },

      hideSkip: true,
    );

    tutorialCoachMark.show(context: context);
  }

  @override
  void dispose() {
    destinationController.dispose();
    super.dispose();
  }

  Future<void> _checkAndShowFirstTutorial(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'unknown';
    final key = 'has_shown_destination_tutorial_$userId';
    final hasShownTutorial = prefs.getBool(key) ?? false;
    
    if (!hasShownTutorial) {
      await prefs.setBool(key, true);
      _showFirstTutorial(context);
    } else {
      // ride_arrival_page에서 넘어온 경우에도 TTS 재생 (메인화면 진입 후)
      // _flutterTts.speak("어디로 가고 싶으신가요?");
    }
  }
}