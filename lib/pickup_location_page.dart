import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ride_request.dart';

class PickupLocationPage extends StatefulWidget {
  final String suggestedPlaceName;
  final LatLng currentLocation;
  final LatLng destinationLocation;

  const PickupLocationPage({
    super.key,
    required this.suggestedPlaceName,
    required this.currentLocation,
    required this.destinationLocation,
  });

  @override
  State<PickupLocationPage> createState() => _PickupLocationPageState();
}

class _PickupLocationPageState extends State<PickupLocationPage> {
  NaverMapController? _controller;
  NLatLng? pickupNLatLng;
  String pickupPlaceName = '';

  @override
  void initState() {
    super.initState();
    _findNearbyConvenienceStore();
  }

  Future<void> _findNearbyConvenienceStore() async {
    final googleApiKey = dotenv.env['GOOGLE_API_KEY']!;
    final lat = widget.currentLocation.latitude;
    final lng = widget.currentLocation.longitude;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=$lat,$lng&radius=500&type=convenience_store&language=ko&key=$googleApiKey',
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      final results = data['results'] as List;

      if (results.isNotEmpty) {
        final store = results[0];
        final name = store['name'];
        final location = store['geometry']['location'];
        final storeLat = location['lat'];
        final storeLng = location['lng'];

        setState(() {
          pickupPlaceName = name;
          pickupNLatLng = NLatLng(storeLat, storeLng);
        });

        _addPickupMarkerIfAvailable();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("근처 편의점을 찾을 수 없습니다.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("오류 발생: $e")),
      );
    }
  }

  void _addPickupMarkerIfAvailable() {
    if (_controller != null && pickupNLatLng != null) {
      _controller!.addOverlay(NMarker(id: 'pickup', position: pickupNLatLng!));
      _controller!.updateCamera(
        NCameraUpdate.withParams(target: pickupNLatLng!, zoom: 18),
      );
    }
  }

  Future<void> _submitRideRequest() async {
    if (pickupNLatLng == null) return;

    final ride = RideRequest(
      passengerId: 'user_123',
      pickupPlaceName: pickupPlaceName,
      pickupLocation: LatLng(pickupNLatLng!.latitude, pickupNLatLng!.longitude),
      destinationName: widget.suggestedPlaceName,
      destinationLocation: widget.destinationLocation,
    );

    await FirebaseFirestore.instance.collection('ride_requests').add(ride.toMap());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('택시 호출이 완료되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentNLatLng = NLatLng(
      widget.currentLocation.latitude,
      widget.currentLocation.longitude,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('픽업 위치')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              pickupPlaceName.isNotEmpty
                  ? '픽업 위치: $pickupPlaceName'
                  : '편의점 정보를 불러오는 중...',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: currentNLatLng,
                    zoom: 15,
                  ),
                ),
                onMapReady: (controller) async {
                  _controller = controller;
                  await controller.addOverlay(NMarker(id: 'current', position: currentNLatLng));
                  _addPickupMarkerIfAvailable();
                },
              ),
            ),
            ElevatedButton(
              onPressed: _submitRideRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text("택시 호출하기"),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
