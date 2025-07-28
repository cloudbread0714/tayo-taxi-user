import 'dart:convert';
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

import 'package:app_tayo_taxi/pickup_place_list_page.dart';
import 'user_profile_page.dart';
import 'bookmark_places_page.dart';

final String kGoogleApiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';

class DestinationInputPage extends StatefulWidget {
  const DestinationInputPage({super.key});

  @override
  State<DestinationInputPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<DestinationInputPage> {
  String currentAddress = '출발지를 불러오는 중...';
  latlng.LatLng? currentLatLng;
  latlng.LatLng? destinationLatLng;
  final TextEditingController destinationController = TextEditingController();
  List<String> suggestions = [];

  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;

  @override
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startVoiceInteraction());
  }

  Future<void> _startVoiceInteraction() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.speak("어딜 가실 건가요?");
    await Future.delayed(const Duration(seconds: 2));

    bool available = await _speech.initialize(
      onStatus: (status) => print("음성 상태: $status"),
      onError: (error) => print("음성 오류: $error"),
    );

    if (available) {
      await _speech.listen(
        localeId: "ko_KR",
        listenMode: stt.ListenMode.dictation,
        onResult: (result) async {
          if (result.recognizedWords.isNotEmpty) {
            final spokenText = result.recognizedWords;
            print("인식된 텍스트: $spokenText");

            setState(() {
              destinationController.text = spokenText;
            });

            await _fetchPlaceSuggestions(spokenText);

            await _flutterTts.speak(
                "$spokenText 가 입력되었어요. 정확한 위치를 리스트에서 선택해주세요.");

            await _speech.stop();
          }
        },
      );
    } else {
      await _flutterTts.speak("음성 인식을 사용할 수 없습니다.");
    }
  }

  Future<void> _goHomeAndNavigate() async {
    if (currentLatLng == null) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
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
        builder: (_) => PickupListPage(
          currentLocation: currentLatLng!,
          destinationLocation: latlng.LatLng(homeLat, homeLng),
          suggestedPlaceName: homeName,
        ),
      ),
    );
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
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = '${place.administrativeArea} ${place.locality} ${place.street}';
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
          suggestions = predictions.map((p) => p['description'] as String).toList();
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

  Future<void> _convertAddressToLatLng(String address) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$kGoogleApiKey';
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


  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

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
                      Icon(Icons.local_taxi, size: screenWidth * 0.278, color: Colors.green),
                      SizedBox(height: screenHeight * 0.025),
                      AutoSizeText(
                        '출발/도착지 설정',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: screenWidth * 0.094,
                            fontWeight: FontWeight.bold
                        ),
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
                      ...suggestions.map((s) => ListTile(
                        title: Text(s),
                        onTap: () => _selectSuggestion(s),
                      )),
                      SizedBox(height: screenHeight * 0.025),
                      ElevatedButton(
                        onPressed: () async {
                          // '다음' 로직
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
                              builder: (_) => PickupListPage(
                                currentLocation: currentLatLng!,
                                destinationLocation: destinationLatLng!,
                                suggestedPlaceName:
                                destinationController.text,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade200,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: TextStyle(
                              fontSize: screenWidth * 0.050, fontWeight: FontWeight.bold),
                        ),
                        child:
                        Text('다음', style: TextStyle(fontSize: screenWidth * 0.056)),
                      ),
                      SizedBox(height: screenHeight * 0.037),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final result =
                              await Navigator.push<Map<String, dynamic>>(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                    const BookmarkPlacesPage()),
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
                                  vertical: 15, horizontal: 30),
                              minimumSize: const Size(150, 50),
                              textStyle: TextStyle(
                                  fontSize: screenWidth * 0.050, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const AutoSizeText(
                              '즐겨찾기', maxLines: 1, minFontSize: 14,),
                          ),
                          ElevatedButton(
                            onPressed: _goHomeAndNavigate,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                side:
                                const BorderSide(color: Colors.grey),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15, horizontal: 30),
                                minimumSize: const Size(150, 50),
                                textStyle: TextStyle(
                                    fontSize: screenWidth * 0.050,
                                    fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12))),
                            child: const AutoSizeText(
                              '집으로', maxLines: 1, minFontSize: 14,),
                          ),
                        ],
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
                icon: Icon(Icons.person, size: screenWidth * 0.078, color: Colors.black),
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
}