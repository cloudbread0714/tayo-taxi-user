import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:app_tayo_taxi/PickUpList_page.dart';
import 'mypage.dart';
import 'bookmarkPlaces.dart';

final String kGoogleApiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  String currentAddress = '출발지를 불러오는 중...';
  latlng.LatLng? currentLatLng;
  latlng.LatLng? destinationLatLng;
  final TextEditingController destinationController = TextEditingController();
  List<String> suggestions = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _goHomeAndNavigate() async {
    if (currentLatLng == null) return;  // 안전 검사

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

    final data = snap.docs.first.data() as Map<String, dynamic>;
    final homeLat = data['lat'] as double;
    final homeLng = data['lng'] as double;
    final homeName = data['placeName'] as String;

    // 바로 내비게이션 페이지로 이동
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
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.local_taxi, size: 100, color: Colors.green),
                      const SizedBox(height: 20),
                      const Text(
                        '출발/도착지 설정',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 40),
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
                      const SizedBox(height: 20),
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
                      const SizedBox(height: 10),
                      ...suggestions.map((s) => ListTile(
                        title: Text(s),
                        onTap: () => _selectSuggestion(s),
                      )),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          // '다음' 로직 (변경 없음)
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
                          textStyle: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        child:
                        const Text('다음', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(height: 30),
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
                              textStyle: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('즐겨찾기'),
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
                                textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12))),
                            child: const Text('집으로'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // 추가할 마이페이지 아이콘 버튼
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.person, size: 28, color: Colors.black),
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