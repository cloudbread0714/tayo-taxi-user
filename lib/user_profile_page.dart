import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'destination_input_page.dart';
import 'user_login_page.dart';
import 'user_info_form.dart';
import 'family_info_form.dart';
import 'ride_history_page.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text('마이페이지', style: TextStyle(fontSize: screenWidth * 0.056, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DestinationInputPage()),
            );
          },
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            SizedBox(height: screenHeight * 0.025),
            _menuButton(context, Icons.person, '나의 정보', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyInfoPage()),
              );
            }),
            SizedBox(height: screenHeight * 0.025),
            _menuButton(context, Icons.family_restroom, '보호자 정보', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamilyInfoPage()),
              );
            }),
            SizedBox(height: screenHeight * 0.025),
            _menuButton(context, Icons.history, '최근 내역', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyOrderHistory()),
              );
            }),
            SizedBox(height: screenHeight * 0.43),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut(); // Firebase 로그아웃
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false, // 이전 화면 스택 모두 제거
                );
              },
              icon: const Icon(Icons.logout),
              label: Text('로그아웃', style: TextStyle(fontSize: screenWidth * 0.044)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.shade100,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuButton(
      BuildContext context,
      IconData icon,
      String label,
      VoidCallback onPressed,
      ) {
    final double screenWidth  = MediaQuery.of(context).size.width;
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: TextStyle(fontSize: screenWidth * 0.050)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade100,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
