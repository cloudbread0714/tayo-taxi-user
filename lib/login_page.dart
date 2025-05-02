import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_page.dart';
import 'location_page.dart'; // 로그인 성공 시 이동할 위치 추적 페이지

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();     // 이메일 입력 컨트롤러
  final passwordController = TextEditingController();  // 비밀번호 입력 컨트롤러

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();  // 앱 시작 시 자동 로그인 확인
  }

  // 현재 로그인된 사용자가 있으면 자동 로그인
  void _checkLoginStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LocationPage()),
        );
      });
    }
  }

  // 로그인 처리
  void _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 로그인 성공 → 위치 추적 페이지로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LocationPage()),
      );
    } on FirebaseAuthException catch (e) {
      // 로그인 실패 시 오류 메시지 출력
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('로그인 실패'),
          content: Text(e.message ?? '알 수 없는 오류'),
        ),
      );
    }
  }

  // 회원가입 페이지로 이동
  void _goToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignUpPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Text(
              '로그인',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.local_taxi, size: 80, color: Colors.amber),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    // 이메일 입력 필드
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: '아이디'),
                    ),
                    const SizedBox(height: 10),

                    // 비밀번호 입력 필드
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '비밀번호'),
                    ),
                    const SizedBox(height: 20),

                    // 로그인 버튼
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade100,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(40),
                      ),
                      onPressed: _login,
                      child: const Text('로그인'),
                    ),
                    const SizedBox(height: 10),

                    // 회원가입 버튼
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade100,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(40),
                      ),
                      onPressed: _goToSignUp,
                      child: const Text('회원가입'),
                    ),
                    const SizedBox(height: 10),

                    // 아이디/비밀번호 찾기
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        '아이디/비밀번호 찾기',
                        style: TextStyle(decoration: TextDecoration.underline),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}