import 'package:latlong2/latlong.dart';

class RideRequest {
  final String passengerId;
  final String pickupPlaceName;
  final LatLng pickupLocation;
  final String destinationName;
  final LatLng destinationLocation;
  final String status;

  RideRequest({
    required this.passengerId,
    required this.pickupPlaceName,
    required this.pickupLocation,
    required this.destinationName,
    required this.destinationLocation,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'passengerId': passengerId,
      'pickupPlaceName': pickupPlaceName,
      'pickupLat': pickupLocation.latitude,
      'pickupLng': pickupLocation.longitude,
      'destinationName': destinationName,
      'destinationLat': destinationLocation.latitude,
      'destinationLng': destinationLocation.longitude,
      'status': status,
    };
  }

  factory RideRequest.fromMap(Map<String, dynamic> map) {
    return RideRequest(
      passengerId: map['passengerId'] ?? '',
      pickupPlaceName: map['pickupPlaceName'] ?? '',
      pickupLocation: LatLng(
        (map['pickupLat'] ?? 0).toDouble(),
        (map['pickupLng'] ?? 0).toDouble(),
      ),
      destinationName: map['destinationName'] ?? '',
      destinationLocation: LatLng(
        (map['destinationLat'] ?? 0).toDouble(),
        (map['destinationLng'] ?? 0).toDouble(),
      ),
      status: map['status'] ?? 'pending',
    );
  }
}