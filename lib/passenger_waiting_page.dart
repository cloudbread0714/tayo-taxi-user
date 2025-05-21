import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ride_in_progress_page.dart'; // ✅ 실제 전환할 페이지 import

class PassengerWaitingPage extends StatelessWidget {
  final String requestId;

  const PassengerWaitingPage({required this.requestId, super.key});

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
        final status = data['status'];
        final driverName = data['driverName'] ?? '미확인';
        final carNumber = data['carNumber'] ?? '미확인';
        final pickupArrived = data['pickupArrived'] == true;

        if (pickupArrived) {
          // ✅ 픽업 도착 시 새로운 페이지로 전환
          Future.microtask(() {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => RideInProgressPage(requestId: requestId),
              ),
            );
          });
          return const SizedBox(); // 임시 위젯 (Navigator.pushReplacement 대기용)
        }

        if (status == 'accepted') {
          return Scaffold(
            appBar: AppBar(title: const Text('🚕 택시 배정 완료')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 80),
                  const SizedBox(height: 20),
                  const Text(
                    '택시가 배정되었습니다! \n 픽업 위치에서 기사님을 기다려주세요!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text('기사 이름: $driverName', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 5),
                  Text('차량 번호: $carNumber', style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('🚖 기사 수락 대기 중')),
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  '택시 기사의 수락을 기다리고 있습니다...',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}