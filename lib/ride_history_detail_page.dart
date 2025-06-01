import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MyOrderHistoryDetails extends StatelessWidget {
  final Map<String, dynamic> data;

  const MyOrderHistoryDetails({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Firestore Timestamp → DateTime
    final acceptedTimestamp = data['acceptedAt'] as Timestamp?;
    final endedTimestamp = data['endedAt'] as Timestamp?;
    final accepted = acceptedTimestamp?.toDate() ?? DateTime.now();
    final ended = endedTimestamp?.toDate() ?? DateTime.now();

    // Format strings
    final dateStr = DateFormat('yyyy년 MM월 dd일').format(accepted);
    final startTimeStr = DateFormat('HH:mm').format(accepted);
    final endTimeStr = DateFormat('HH:mm').format(ended);

    // Other fields
    final pickupPlace = data['pickupPlaceName'] as String? ?? '정보 없음';
    final destinationPlace = data['destinationName'] as String? ?? '정보 없음';
    final driverName = data['driverName'] as String? ?? '미확인';
    final carNumber = data['carNumber'] as String? ?? '미확인';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '상세 내역',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        leading: const BackButton(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 25),
              Text(
                dateStr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 40),

              // 출발 시간 / 도착 시간 영역
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.green, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          '출발 시간:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          startTimeStr,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.green, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          '도착 시간:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          endTimeStr,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 출발지 / 도착지 영역
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.my_location, color: Colors.green, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          '출발지:',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          pickupPlace,
                          style: const TextStyle(fontSize: 20),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.place, color: Colors.green, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          '도착지:',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          destinationPlace,
                          style: const TextStyle(fontSize: 20),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 기사님 / 차량 번호 영역
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.green, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          '기사님:',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          driverName,
                          style: const TextStyle(fontSize: 20),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.local_taxi, color: Colors.green, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          '차량 번호:',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          carNumber,
                          style: const TextStyle(fontSize: 20),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
