// models/ride_request.dart
import 'package:latlong2/latlong.dart';

class RideRequest {
  final String passengerId;
  final String pickupPlaceName;
  final LatLng pickupLocation;
  final String destinationName;
  final LatLng destinationLocation;

  RideRequest({
    required this.passengerId,
    required this.pickupPlaceName,
    required this.pickupLocation,
    required this.destinationName,
    required this.destinationLocation,
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
    };
  }

  factory RideRequest.fromMap(Map<String, dynamic> map) {
    return RideRequest(
      passengerId: map['passengerId'],
      pickupPlaceName: map['pickupPlaceName'],
      pickupLocation: LatLng(map['pickupLat'], map['pickupLng']),
      destinationName: map['destinationName'],
      destinationLocation: LatLng(map['destinationLat'], map['destinationLng']),
    );
  }
}