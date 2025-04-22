import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'pickup_location_page.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  String currentAddress = '출발지를 불러오는 중...';
  LatLng? currentLatLng;
  final TextEditingController destinationController = TextEditingController();

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
          currentLatLng = LatLng(position.latitude, position.longitude);
        });
      } else {
        setState(() => currentAddress = '주소 정보를 찾을 수 없습니다');
      }
    } catch (e) {
      setState(() => currentAddress = '주소 변환 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      borderSide: const BorderSide(color: Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: destinationController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.place),
                    labelText: '목적지 입력 (예: 서울 강남역)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () async {
                    if (currentLatLng == null || destinationController.text.isEmpty) return;

                    try {
                      List<Location> locations = await locationFromAddress(destinationController.text);
                      if (locations.isNotEmpty) {
                        LatLng destinationLatLng = LatLng(locations.first.latitude, locations.first.longitude);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PickupLocationPage(
                              suggestedPlaceName: destinationController.text,
                              currentLocation: currentLatLng!,
                              pickupLocation: destinationLatLng,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('목적지 좌표를 찾을 수 없습니다: $e')),
                      );
                    }
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}