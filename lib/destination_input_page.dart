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
import 'services/extract_place.dart';

final String kGoogleApiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';

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
  List<String> suggestions = [];
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("ko-KR");
    _flutterTts.speak("어디로 가고 싶으신가요?"); // 자동 안내
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

    if (result.length < 2) {
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
        await _speakAndWait("집으로 설정했어요. 다음 버튼을 눌러주세요.");
      } else {
        await _speakAndWait("집 주소가 설정되어 있지 않아요.");
      }
      return;
    }

    final extracted = await extractPlaceName(result);
    if (extracted == null || extracted.length < 2) {
      await _speakAndWait("죄송합니다. 장소를 이해하지 못했어요.");
      return;
    }

    // 👉 다음 클릭 시 네/아니요로 넘어가게 준비
    extractedPlaceForConfirmation = extracted;
    waitingForConfirmation = true;
    await _speakAndWait("$extracted 로 가고 싶으신가요? 네 또는 아니요로 대답해주세요.");
  }

  Future<void> _handleConfirmationInput() async {
    final available = await _speech.initialize();
    if (!available) {
      await _speakAndWait("음성 인식을 사용할 수 없습니다.");
      return;
    }

    await Future.delayed(Duration(milliseconds: 300));

    setState(() => isListening = true);
    final result = await _listenOnce();
    setState(() => isListening = false);

    final answer = result.toLowerCase().replaceAll(RegExp(r'[^\uAC00-\uD7A3a-z0-9]'), '');
    final yes = ["네", "예", "응", "그래", "좋아"].any((e) => answer.contains(e));
    final no = ["아니", "노", "싫"].any((e) => answer.contains(e));

    if (yes) {
      destinationController.text = extractedPlaceForConfirmation!;
      await _fetchPlaceSuggestions(extractedPlaceForConfirmation!);
      await _speakAndWait("${extractedPlaceForConfirmation!}로 설정했어요.");
    } else if (no) {
      await _speakAndWait("알겠습니다. 다시 말씀해주세요.");
    } else {
      await _speakAndWait("죄송해요. 네 또는 아니요로 말씀해주세요.");
      return;
    }

    // 초기화
    waitingForConfirmation = false;
    extractedPlaceForConfirmation = null;
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

  Future<String> _listenOnce() async {
    final completer = Completer<String>();
    bool gotResult = false;

    await _speech.listen(
      localeId: "ko_KR",
      listenMode: stt.ListenMode.dictation,
      onResult: (result) {
        if (!gotResult && result.finalResult && result.recognizedWords.isNotEmpty) {
          gotResult = true;
          completer.complete(result.recognizedWords.trim());
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () => '',
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
    child: InkWell(
    onTap: _processVoiceWithAI, // 버튼 클릭 시 음성 인식 시작
    customBorder: const CircleBorder(),
    child: CircleAvatar(
    backgroundColor: Colors.green.shade100,
    radius: 28.0,
    child: Icon(
    Icons.mic,
    size: 28.0,
    color: isListening ? Colors.green.shade900 : Colors.grey,
    ),
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