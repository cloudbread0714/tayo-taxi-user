import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RideInProgressPage extends StatelessWidget {
  final String requestId;

  const RideInProgressPage({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(requestId);

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final driverName = data['driverName'] ?? '미확인';
        final carNumber = data['carNumber'] ?? '미확인';
        final estimatedArrival = data['estimatedArrivalMinutes'] ?? '알 수 없음';

        return Scaffold(
          appBar: AppBar(title: const Text('🚗 탑승 중')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_car, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  '목적지로 이동 중입니다',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text('기사 이름: $driverName', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 5),
                Text('차량 번호: $carNumber', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 5),
                Text('예상 도착 시간: 약 $estimatedArrival분', style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),
        );
      },
    );
  }
}