import 'package:cloud_firestore/cloud_firestore.dart';
import '../ride_request_model.dart';

Future<void> uploadRideRequest(RideRequest request) async {
  await FirebaseFirestore.instance
      .collection('ride_requests')
      .add(request.toMap());
}