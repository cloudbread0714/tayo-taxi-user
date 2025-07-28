import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_signup_page.dart';
import 'destination_input_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

//LoginPage 설정
class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // 앱 시작 시 자동 로그인 확인
  }

  void _checkLoginStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 이미 로그인 상태라면 바로 LocationPage로 이동
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DestinationInputPage()),
        );
      });
    }
  }

  void _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 로그인 성공 시 LocationPage로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DestinationInputPage()),
      );
    } on FirebaseAuthException catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('로그인 실패'),
          content: Text(e.message ?? '알 수 없는 오류'),
        ),
      );
    }
  }

  void _goToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignUpPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.067),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: screenHeight * 0.106),
              Center(
                child: Icon(
                  Icons.local_taxi,
                  size: 100,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: screenHeight * 0.020),
              Center(
                child: Text(
                  '로그인',
                  style: TextStyle(
                    fontSize: screenWidth * 0.100,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.050),
              TextField(
                controller: emailController,
                style: TextStyle(fontSize: screenWidth * 0.050),
                decoration: InputDecoration(
                  labelText: '아이디',
                  labelStyle: TextStyle(fontSize: screenWidth * 0.050),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 22.0, horizontal: 16.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.025),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: TextStyle(fontSize: screenWidth * 0.050),
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  labelStyle: TextStyle(fontSize: screenWidth * 0.050),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 22.0, horizontal: 16.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.037),
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                  backgroundColor: Colors.green.shade200,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '로그인',
                  style: TextStyle(fontSize: screenWidth * 0.056),
                ),
              ),
              SizedBox(height: screenHeight * 0.020),
              ElevatedButton(
                onPressed: _goToSignUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                  backgroundColor: Colors.green.shade200,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '회원가입',
                  style: TextStyle(fontSize: screenWidth * 0.056),
                ),
              ),
              SizedBox(height: screenHeight * 0.015),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    '아이디/비밀번호 찾기',
                    style: TextStyle(
                      fontSize: screenWidth * 0.044,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.050),
            ],
          ),
        ),
      ),
    );
  }
}
