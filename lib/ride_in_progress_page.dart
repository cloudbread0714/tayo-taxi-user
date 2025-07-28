import 'dart:convert';
import 'dart:math';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'destination_input_page.dart';
import 'ride_arrival_page.dart';

class RideInProgressPage extends StatefulWidget {
  final String requestId;
  const RideInProgressPage({super.key, required this.requestId});

  @override
  State<RideInProgressPage> createState() => _RideInProgressPageState();
}

class _RideInProgressPageState extends State<RideInProgressPage> {
  bool _hasMoved = false;

  @override
  Widget build(BuildContext context) {
    final double screenWidth  = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final docRef = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(widget.requestId);

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        // 1) 문서 로드 대기
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2) 문서가 존재하지 않는 경우
        final docSnap = snapshot.data!;
        if (!docSnap.exists) {
          Future.microtask(() {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DestinationInputPage()),
              );
            }
          });
          return const SizedBox.shrink();
        }

        final data = docSnap.data() as Map<String, dynamic>;

        // 3) status가 "end"로 변경된 순간 한 번만 복사/삭제
        if (data['status'] == 'end' && !_hasMoved) {
          _hasMoved = true;
          Future.microtask(() async {
            await _moveToHistoryAndDelete(data);
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ArrivedDestinationPage()),
              );
            }
          });
        }

        if (data['status'] != 'end') {
          final driverName = data['driverName'] ?? '미확인';
          final carNumber  = data['carNumber']  ?? '미확인';

          double pickupLat = (data['pickupLat'] as num).toDouble();
          double pickupLng = (data['pickupLng'] as num).toDouble();
          final double destLat   = (data['destinationLat'] as num).toDouble();
          final double destLng   = (data['destinationLng'] as num).toDouble();

          final String? googleApiKey = dotenv.env['GOOGLE_API_KEY'];
          if (googleApiKey == null || googleApiKey.isEmpty) {
            // API 키가 없으면 10분 뒤로
            final DateTime arrivalTime = DateTime.now().add(const Duration(minutes: 10));
            final String arrivalHour   = arrivalTime.hour.toString().padLeft(2, '0');
            final String arrivalMinute = arrivalTime.minute.toString().padLeft(2, '0');
            final String arrivalText   = '$arrivalHour시 $arrivalMinute분';

            return _buildSimpleUI(
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              driverName: driverName,
              carNumber: carNumber,
              arrivalText: arrivalText,
            );
          }

          // ① “Snapped to road” (가장 가까운 도로 좌표) 확보
          return FutureBuilder<LatLng>(
            future: _snapToNearestRoad(
              LatLng(pickupLat, pickupLng),
              googleApiKey,
              docRef,
            ),
            builder: (context, snapRoadSnapshot) {
              if (snapRoadSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final LatLng snappedPickup = snapRoadSnapshot.data ?? LatLng(pickupLat, pickupLng);

              // ② 이후 실제 Directions API 호출
              return FutureBuilder<int?>(
                future: fetchTravelDurationSeconds(
                  origin: snappedPickup,
                  destination: LatLng(destLat, destLng),
                  apiKey: googleApiKey,
                ),
                builder: (context, durationSnapshot) {
                  if (durationSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final int? durationSeconds = durationSnapshot.data;
                  final int estimatedMinutes = durationSeconds != null
                      ? (durationSeconds / 60).ceil()
                      : (data['estimatedArrivalMinutes'] as int? ?? 10);

                  final DateTime arrivalTime = DateTime.now().add(Duration(minutes: estimatedMinutes));
                  final String arrivalHour   = arrivalTime.hour.toString().padLeft(2, '0');
                  final String arrivalMinute = arrivalTime.minute.toString().padLeft(2, '0');
                  final String arrivalText   = '$arrivalHour시 $arrivalMinute분';

                  return _buildSimpleUI(
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                    driverName: driverName,
                    carNumber: carNumber,
                    arrivalText: arrivalText,
                  );
                },
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  // Firestore 문서의 pickupLat/pickupLng를 “가장 가까운 도로 위 좌표”로 보정
  // 보정된 좌표를 반환. 보정 발생 시 DB에 업데이트
  Future<LatLng> _snapToNearestRoad(
      LatLng original,
      String apiKey,
      DocumentReference<Map<String, dynamic>> docRef,
      ) async {
    try {
      final coordStr = '${original.latitude},${original.longitude}';
      final url = Uri.parse(
        'https://roads.googleapis.com/v1/nearestRoads'
            '?points=$coordStr'
            '&key=$apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) {
        print('Roads API 요청 실패: ${response.statusCode}');
        return original;
      }

      final Map<String, dynamic> jsonData = json.decode(response.body);
      final snappedPoints = jsonData['snappedPoints'] as List<dynamic>?;
      if (snappedPoints == null || snappedPoints.isEmpty) {
        print('도로 스냅 결과 없음, 원래 좌표 사용');
        return original;
      }

      final Map<String, dynamic> snappedLocation = snappedPoints[0]['location'];
      final double newLat = (snappedLocation['latitude'] as num).toDouble();
      final double newLng = (snappedLocation['longitude'] as num).toDouble();
      final LatLng snappedLatLng = LatLng(newLat, newLng);

      final double distanceMeters = _calculateDistanceInMeters(original, snappedLatLng);
      if (distanceMeters >= 10) {
        await docRef.update({
          'pickupLat': newLat,
          'pickupLng': newLng,
        });
        print('Firestore에 보정된 좌표 저장: ($newLat, $newLng)');
      } else {
        print('원본 좌표와 스냅 좌표 차이($distanceMeters m)가 작아, DB 업데이트 생략');
      }

      return snappedLatLng;
    } catch (e) {
      print('snapToNearestRoad 오류: $e');
      return original;
    }
  }

  // 두 LatLng 사이 “직선 거리(m)” 계산 (Haversine formula)
  double _calculateDistanceInMeters(LatLng a, LatLng b) {
    const double earthRadius = 6371000;
    final double lat1 = a.latitude * (pi / 180);
    final double lon1 = a.longitude * (pi / 180);
    final double lat2 = b.latitude * (pi / 180);
    final double lon2 = b.longitude * (pi / 180);

    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;

    final double havA =
        sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) *
                sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(havA), sqrt(1 - havA));
    return earthRadius * c;
  }

  // Google Directions API 호출하여 “운행 예상 소요 시간(초)” 리턴
  Future<int?> fetchTravelDurationSeconds({
    required LatLng origin,
    required LatLng destination,
    required String apiKey,
  }) async {
    try {
      final originStr = '${origin.latitude},${origin.longitude}';
      final destinationStr = '${destination.latitude},${destination.longitude}';

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
            '?origin=$originStr'
            '&destination=$destinationStr'
            '&mode=driving'
            '&key=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        print('Directions API 요청 실패: ${response.statusCode}');
        return null;
      }

      final Map<String, dynamic> jsonData = json.decode(response.body);

      if (jsonData['status'] == 'ZERO_RESULTS') {
        print('경로가 없습니다 (ZERO_RESULTS)');
        return null;
      }
      if (jsonData['status'] != 'OK') {
        print('Directions API 오류 상태: ${jsonData['status']}');
        return null;
      }

      final routes = jsonData['routes'] as List<dynamic>;
      if (routes.isEmpty) return null;

      final legs = (routes[0]['legs'] as List<dynamic>);
      if (legs.isEmpty) return null;

      final duration = legs[0]['duration'] as Map<String, dynamic>;
      return (duration['value'] as int);
    } catch (e) {
      print('fetchTravelDurationSeconds 오류: $e');
      return null;
    }
  }

  // 기사 이름, 차량 번호, 도착 예정 시간을 표시하는 공통 UI
  Widget _buildSimpleUI({
    required double screenWidth,
    required double screenHeight,
    required String driverName,
    required String carNumber,
    required String arrivalText,
  }) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.06,
            vertical: screenHeight * 0.05,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: screenHeight * 0.087),
              AutoSizeText(
                '목적지로 이동 중입니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.072,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
                maxLines: 1,
                minFontSize: 12,
              ),
              SizedBox(height: screenHeight * 0.04),

              Center(
                child: Icon(
                  Icons.directions_car,
                  size: screenWidth * 0.25,
                  color: Colors.green.shade400,
                ),
              ),
              SizedBox(height: screenHeight * 0.04),

              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: screenHeight * 0.04,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AutoSizeText(
                      '기사 이름',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.064,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      minFontSize: 14,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    AutoSizeText(
                      driverName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.064,
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      minFontSize: 14,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    AutoSizeText(
                      '차량 번호',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.064,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      minFontSize: 14,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    AutoSizeText(
                      carNumber,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.064,
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      minFontSize: 14,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    AutoSizeText(
                      '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.064,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      minFontSize: 14,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    AutoSizeText(
                      '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.064,
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      minFontSize: 14,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Firestore 문서 복사 → history로 이동 후 원본 삭제
  Future<void> _moveToHistoryAndDelete(Map<String, dynamic> rideData) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      final String uid = currentUser.uid;
      final String requestId = widget.requestId;
      final historyData = {
        ...rideData,
        'endedAt': FieldValue.serverTimestamp(),
      };
      final histRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('history')
          .doc(requestId);
      await histRef.set(historyData);
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(requestId)
          .delete();
    } catch (_) {}
  }
}
