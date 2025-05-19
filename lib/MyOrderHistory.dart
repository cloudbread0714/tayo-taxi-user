import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MyOrderHistory extends StatelessWidget {
  const MyOrderHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('최근 내역'),
        leading: BackButton(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('recent_ride_requests')
            .where('passengerId', isEqualTo: userId)
            .orderBy('acceptedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('에러: ${snap.error}'));
          if (!snap.hasData)  return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('이용 내역이 없습니다'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data()! as Map<String, dynamic>;
              final accepted = (data['acceptedAt'] as Timestamp).toDate();
              final ended    = (data['expiresAt'] as Timestamp).toDate();
              final dateStr  = DateFormat('yy.MM.dd').format(accepted);
              final timeStr  = '${DateFormat('HH:mm').format(accepted)} - '
                  '${DateFormat('HH:mm').format(ended)}';

              return Card(
                color: Colors.green.shade50,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateStr,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(timeStr, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('출발지: ${data['pickupPlaceName']}', style: const TextStyle(fontSize: 16)),
                      Text('도착지: ${data['distinationName']}', style: const TextStyle(fontSize: 16)),
                      Text('기사님: ${data['driverId']}', style: const TextStyle(fontSize: 16)),
                    ],
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
