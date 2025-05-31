import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'location_page.dart';
import 'ArrivedDestination.dart';

class RideInProgressPage extends StatefulWidget {
  final String requestId;

  const RideInProgressPage({super.key, required this.requestId});

  @override
  State<RideInProgressPage> createState() => _RideInProgressPageState();
}

class _RideInProgressPageState extends State<RideInProgressPage> {
  bool _hasMoved = false;
  Future<void> _moveToHistoryAndDelete(Map<String, dynamic> rideData) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('사용자 로그인 정보가 없습니다. 복사/삭제를 중단합니다.');
        return;
      }

      final String targetUid = currentUser.uid;
      final String requestId = widget.requestId;

      // 복사하려는 데이터에 endedAt 타임스탬프 필드 추가
      final Map<String, dynamic> historyData = {
        ...rideData,
        'endedAt': FieldValue.serverTimestamp(),
      };

      // users/{targetUid}/history/{requestId} 경로에 복사
      final historyRef = FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('history')
          .doc(requestId);

      await historyRef.set(historyData);

      // 복사 완료 후에 원본 ride_requests/{requestId} 문서 삭제
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(requestId)
          .delete();

      debugPrint('✔ ride_requests/$requestId → users/$targetUid/history 이동 및 삭제 완료');
    } catch (e, st) {
      debugPrint('✖ History 복사/삭제 중 오류 발생: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(widget.requestId);

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        // 1) 문서 로드 대기
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 2) 문서가 존재하지만 데이터가 null인 경우
        final docSnap = snapshot.data!;
        if (!docSnap.exists) {
          // ride_requests 문서가 이미 삭제되었을 수 있음 → 바로 LocationPage로 복귀
          Future.microtask(() {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LocationPage()),
              );
            }
          });
          return const SizedBox.shrink();
        }

        final data = docSnap.data() as Map<String, dynamic>;

        // 3) status가 "end"로 변경된 순간, 한 번만 복사/삭제 작업 수행
        if (data['status'] == 'end' && !_hasMoved) {
          _hasMoved = true;
          Future.microtask(() async {
            await _moveToHistoryAndDelete(data);

            // 복사/삭제가 완료되면 탑승자 화면을 LocationPage로 이동
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ArrivedDestinationPage()),
              );
            }
          });
        }

        if (data['status'] != 'end') {
          final driverName = data['driverName'] ?? '미확인';
          final carNumber = data['carNumber'] ?? '미확인';
          final estimatedArrival = data['estimatedArrivalMinutes'] ?? '알 수 없음';

          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 70),
                    Text(
                      '목적지로 이동 중입니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 50),

                    // 차량 아이콘
                    Center(
                      child: Icon(
                        Icons.directions_car,
                        size: 100,
                        color: Colors.green.shade400,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 정보 카드
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 기사 이름
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '기사 이름: ',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                driverName,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 차량 번호
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '차량 번호: ',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                carNumber,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 예상 도착 시간
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '예상 도착 시간: ',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '약 ${estimatedArrival}분',
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
