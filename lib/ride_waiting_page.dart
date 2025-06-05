import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ride_in_progress_page.dart';
import 'destination_input_page.dart';

class PassengerWaitingPage extends StatelessWidget {
  final String requestId;

  const PassengerWaitingPage({required this.requestId, super.key});

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(requestId);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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
                margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.089),
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
                    SizedBox(height: screenHeight * 0.020),
                    AutoSizeText(
                      '택시가 배정되었습니다!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: screenWidth * 0.067, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      minFontSize: 12,
                    ),

                    SizedBox(height: screenHeight * 0.015),

                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '기사님: ',
                            style: TextStyle(
                              fontSize: screenWidth * 0.056,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: driverName,
                            style: TextStyle(
                              fontSize: screenWidth * 0.056,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.010),

                    AutoSizeText.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '차량 번호: ',
                            style: TextStyle(
                              fontSize: screenWidth * 0.056,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: carNumber,
                            style: TextStyle(
                              fontSize: screenWidth * 0.056,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      minFontSize: 12,
                    ),
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
                  SizedBox(height: screenHeight * 0.250),
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
                  SizedBox(height: screenHeight * 0.05),
                  AutoSizeText(
                    '수락 대기 중...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: screenWidth * 0.083),
                    maxLines: 1,
                    minFontSize: 14,
                  ),
                  SizedBox(height: screenHeight * 0.1),
                  // 통합 정보 박스
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '출발지: ',
                            style: TextStyle(
                              fontSize: screenWidth * 0.050,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: '$pickupPlace\n',
                            style: TextStyle(
                              fontSize: screenWidth * 0.050,
                              fontWeight: FontWeight.normal,
                            ),
                          ),

                          TextSpan(
                            text: '도착지: ',
                            style: TextStyle(
                              fontSize: screenWidth * 0.050,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: destPlace,
                            style: TextStyle(
                              fontSize: screenWidth * 0.050,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.05),
                  Align(
                    alignment: Alignment.center,
                    child: ElevatedButton(
                      onPressed: _cancelRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(160, 48),
                        textStyle: TextStyle(fontSize: screenWidth * 0.050, fontWeight: FontWeight.bold),
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
