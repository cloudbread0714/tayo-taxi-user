import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ride_tracking_page.dart'; // 실제 전환할 페이지 import
import 'destination_input_page.dart';       // 메인 LocationPage import

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
            body: Center(child: _LoadingIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final status = data['status'];
        final pickupArrived = data['pickupArrived'] == true;

        if (pickupArrived) {
          Future.microtask(() {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => RideInProgressPage(requestId: requestId),
              ),
            );
          });
          return const SizedBox();
        }

        // 호출 취소 함수
        Future<void> _cancelRequest() async {
          try {
            await docRef.delete();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('호출 취소에 실패했습니다.')),
            );
            return;
          }
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LocationPage()),
                (route) => false,
          );
        }

        if (status == 'accepted') {
          // Accepted 화면은 기존 그대로 유지
          final driverName = data['driverName'] ?? '미확인';
          final carNumber = data['carNumber'] ?? '미확인';
          return Scaffold(
            backgroundColor: Colors.green.shade50,
            body: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_taxi, color: Colors.green, size: 80),
                    const SizedBox(height: 16),
                    const Text(
                      '택시가 배정되었습니다!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text('기사님: $driverName', style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 8),
                    Text('차량 번호: $carNumber', style: const TextStyle(fontSize: 20)),
                  ],
                ),
              ),
            ),
          );
        }

        // 대기 화면
        final pickupPlace = data['pickupPlaceName'] ?? '정보 없음';
        final destPlace = data['destinationName'] ?? '정보 없음';
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 200),
                  Center(
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: CircularProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        strokeWidth: 5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  const Text(
                    '수락 대기 중...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30),
                  ),
                  //const Center(child: _LoadingIndicator()),
                  const SizedBox(height: 130),
                  // 통합 정보 박스
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '출발지: $pickupPlace\n도착지: $destPlace',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  //const Spacer(),
                  const SizedBox(height: 50),
                  Align(
                    alignment: Alignment.center,
                    child: ElevatedButton(
                      onPressed: _cancelRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(160, 48), // 버튼 가로 길이 조정
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('호출 취소'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
      strokeWidth: 6,
    ),
  );
}
