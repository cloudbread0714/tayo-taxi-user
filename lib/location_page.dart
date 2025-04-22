import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pickup_location_page.dart'; // Make sure this file uses latlng.LatLng and flutter_map if you're replacing google_maps_flutter

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
      debugPrint('🔍 Geocoding address: $address');
      final response = await http.get(Uri.parse(url));
      debugPrint('📦 Geocoding 응답 본문: ${response.body}');
      debugPrint('Geocode status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final location = results.first['geometry']['location'];
          setState(() {
            destinationLatLng = latlng.LatLng(location['lat'], location['lng']);
          });
        } else {
          debugPrint('❌ Geocoding 결과 없음, destinationLatLng를 null로 초기화');
          setState(() {
            destinationLatLng = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Geocode error: $e');
      setState(() {
        destinationLatLng = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 30),
                  const Text(
                    '출발/도착지 설정',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Icon(Icons.local_taxi, size: 80, color: Colors.amber),
                  const SizedBox(height: 30),
                  TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.my_location),
                      labelText: '출발지: $currentAddress',
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
                      if (currentLatLng == null) return;

                      if (destinationLatLng == null &&
                          destinationController.text.isNotEmpty) {
                        await _convertAddressToLatLng(destinationController.text);
                      }

                      if (destinationLatLng == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('목적지를 선택하거나 입력해주세요.')),
                        );
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PickupLocationPage(
                            suggestedPlaceName: destinationController.text,
                            currentLocation: currentLatLng!,
                            pickupLocation: destinationLatLng!,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('다음', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.grey),
                        ),
                        child: const Text('즐겨찾기'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('마이페이지'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}