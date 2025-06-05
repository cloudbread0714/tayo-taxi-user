import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'ride_history_detail_page.dart';

class MyOrderHistory extends StatelessWidget {
  const MyOrderHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '최근 이용 내역',
          style: TextStyle(fontSize: screenWidth * 0.061, fontWeight: FontWeight.bold),
        ),
        leading: const BackButton(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('history')
            .orderBy('acceptedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                '에러 발생: ${snap.error}',
                style: TextStyle(fontSize: screenWidth * 0.050, color: Colors.red),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: AutoSizeText(
                '이용 내역이 없습니다',
                style: TextStyle(fontSize: screenWidth * 0.050),
                maxLines: 1,
                minFontSize: 14,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data()! as Map<String, dynamic>;
              final acceptedTimestamp = data['acceptedAt'] as Timestamp?;
              final accepted = acceptedTimestamp?.toDate() ?? DateTime.now();

              final dateStr = DateFormat('yy / MM / dd').format(accepted);
              final pickup = data['pickupPlaceName'] as String? ?? '정보 없음';
              final destination = data['destinationName'] as String? ?? '정보 없음';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.shade200,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyOrderHistoryDetails(data: data),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 20.0, horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 날짜
                        Text(
                          dateStr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: screenWidth * 0.056,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.015),

                        // 출발지
                        Row(
                          children: [
                            const Icon(Icons.my_location,
                                color: Colors.green, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              '출발지: ',
                              style: TextStyle(
                                  fontSize: screenWidth * 0.050, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AutoSizeText(
                                pickup,
                                style: TextStyle(fontSize: screenWidth * 0.050),
                                maxLines: 2,
                                minFontSize: 13,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.015),

                        // 도착지
                        Row(
                          children: [
                            const Icon(Icons.place,
                                color: Colors.green, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              '도착지: ',
                              style: TextStyle(
                                  fontSize: screenWidth * 0.050, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AutoSizeText(
                                destination,
                                style: TextStyle(fontSize: screenWidth * 0.050),
                                maxLines: 2,
                                minFontSize: 13,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
