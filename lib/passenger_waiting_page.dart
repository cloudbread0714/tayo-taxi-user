import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        final driverId = data['driverId'];

        if (status == 'accepted') {
          // 기사 수락 완료 → 다음 단계 페이지로 이동
          return Scaffold(
            appBar: AppBar(title: const Text('택시 배정 완료')),
            body: Center(
              child: Text('택시가 배정되었습니다!\n기사 ID: $driverId'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('기사 대기 중')),
          body: const Center(
            child: Text('택시기사의 수락을 기다리는 중입니다...'),
          ),
        );
      },
    );
  }
}