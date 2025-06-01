import 'package:cloud_firestore/cloud_firestore.dart';

class RideRequest {
  final String passengerId;
  final String pickupPlaceName;
  final double pickupLat;
  final double pickupLng;
  final String destinationName;
  final double destinationLat;
  final double destinationLng;
  final Timestamp? createdAt;
  final String status;

  RideRequest({
    required this.passengerId,
    required this.pickupPlaceName,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    this.createdAt,
    this.status = 'pending',
  });

  factory RideRequest.fromMap(Map<String, dynamic> map) {
    return RideRequest(
      passengerId: map['passengerId'] ?? '',
      pickupPlaceName: map['pickupPlaceName'] ?? '',
      pickupLat: map['pickupLat']?.toDouble() ?? 0.0,
      pickupLng: map['pickupLng']?.toDouble() ?? 0.0,
      destinationName: map['destinationName'] ?? '',
      destinationLat: map['destinationLat']?.toDouble() ?? 0.0,
      destinationLng: map['destinationLng']?.toDouble() ?? 0.0,
      createdAt: map['createdAt'],
      status: map['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'passengerId': passengerId,
      'pickupPlaceName': pickupPlaceName,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'destinationName': destinationName,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'status': status,
    };
  }
}

// 호출 업로드: status 기본값 포함
Future<void> uploadRideRequest(RideRequest request) async {
  await FirebaseFirestore.instance
      .collection('ride_requests')
      .add(request.toMap());
}

//  recent_ride_requests 제거, 대신 ride_requests에서 10분 이내 필터링만 활용
Future<List<RideRequest>> getRecentRideRequests() async {
  final tenMinutesAgo = Timestamp.fromDate(
    DateTime.now().subtract(const Duration(minutes: 10)),
  );

  final snapshot = await FirebaseFirestore.instance
      .collection('ride_requests')
      .where('createdAt', isGreaterThan: tenMinutesAgo)
      .where('status', isEqualTo: 'pending')
      .get();

  return snapshot.docs.map((doc) => RideRequest.fromMap(doc.data())).toList();
}
