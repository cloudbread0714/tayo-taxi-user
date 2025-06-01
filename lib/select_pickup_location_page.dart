import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ride_request_model.dart';
import 'ride_waiting_page.dart';

class PickupLocationPage extends StatefulWidget {
  final String suggestedPlaceName;
  final LatLng currentLocation;
  final LatLng destinationLocation;
  final LatLng? pickupLatLng;
  final String? pickupName;

  const PickupLocationPage({
    super.key,
    required this.suggestedPlaceName,
    required this.currentLocation,
    required this.destinationLocation,
    this.pickupLatLng,
    this.pickupName,
  });

  @override
  State<PickupLocationPage> createState() => _PickupLocationPageState();
}

class _PickupLocationPageState extends State<PickupLocationPage> {
  NaverMapController? _controller;
  NLatLng? pickupNLatLng;
  String pickupPlaceName = '';
  String? rideRequestDocId;

  @override
  void initState() {
    super.initState();

    if (widget.pickupLatLng != null && widget.pickupName != null) {
      pickupNLatLng = NLatLng(
          widget.pickupLatLng!.latitude, widget.pickupLatLng!.longitude);
      pickupPlaceName = widget.pickupName!;
      _addMarkersAndAdjustCamera();
    } else {
      _findNearbyConvenienceStore();
    }
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

        _addMarkersAndAdjustCamera();
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

  Future<void> _addMarkersAndAdjustCamera() async {
    if (_controller == null || pickupNLatLng == null) return;

    await _controller!.clearOverlays();

    await _controller!.addOverlay(NMarker(
      id: 'pickup',
      position: pickupNLatLng!,
    ));

    await _controller!.updateCamera(
      NCameraUpdate.withParams(target: pickupNLatLng!, zoom: 18),
    );
  }

  Future<void> _submitRideRequest() async {
    if (pickupNLatLng == null) return;

    final user = FirebaseAuth.instance.currentUser;
    final passengerId = user?.email ?? 'unknown';

    final ride = RideRequest(
      passengerId: passengerId,
      pickupPlaceName: pickupPlaceName,
      pickupLat: pickupNLatLng!.latitude,
      pickupLng: pickupNLatLng!.longitude,
      destinationName: widget.suggestedPlaceName,
      destinationLat: widget.destinationLocation.latitude,
      destinationLng: widget.destinationLocation.longitude,
    );

    final docRef = await FirebaseFirestore.instance
        .collection('ride_requests')
        .add(ride.toMap());

    rideRequestDocId = docRef.id;

    // 수락을 기다리지 않고 바로 페이지 전환
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PassengerWaitingPage(requestId: rideRequestDocId!),
      ),
    );

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
      appBar: AppBar(
        title: const Text('픽업 위치', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            Text(
              '픽업 위치',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.normal,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              pickupPlaceName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            /*Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '픽업 위치: ',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  TextSpan(
                    text: pickupPlaceName,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),*/
            const SizedBox(height: 30),
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
                  await _addMarkersAndAdjustCamera();
                },
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 100),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _submitRideRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade200,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text("택시 호출하기",
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
