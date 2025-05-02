// lib/services/upload_ride_request.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ride_request.dart';

class RideRequestService {
  static Future<void> upload(RideRequest request) async {
    await FirebaseFirestore.instance.collection('ride_requests').add(request.toMap());
  }
}