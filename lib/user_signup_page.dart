import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _guardianNameController = TextEditingController();    // 보호자 이름
  final _guardianPhoneController = TextEditingController();   // 보호자 전화번호

  void _signUp() async {
    final id            = _idController.text.trim();
    final pw            = _passwordController.text.trim();
    final name          = _nameController.text.trim();
    final phone         = _phoneController.text.trim();
    final guardianName  = _guardianNameController.text.trim();
    final guardianPhone = _guardianPhoneController.text.trim();

    if ([id, pw, name, phone, guardianName, guardianPhone].any((s) => s.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 필드를 입력해주세요.')),
      );
      return;
    }

    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: id, password: pw);
      final user = cred.user;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'email': id,
          'name': name,
          'phone': phone,
          'guardian': {
            'name': guardianName,
            'phone': guardianPhone,
          },
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('회원가입 성공'),
          content: Text(
              '아이디: $id\n'
                  '이름: $name\n'
                  '전화번호: $phone\n'
                  '보호자 이름: $guardianName\n'
                  '보호자 전화: $guardianPhone'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                );
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      final message = (e.code == 'email-already-in-use')
          ? '중복된 아이디입니다'
          : e.message ?? '알 수 없는 오류';
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('회원가입 실패'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text('회원가입', style: TextStyle(fontSize: screenWidth * 0.056)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('아이디'),
                      SizedBox(height: screenHeight * 0.010),
                      _buildInputField(controller: _idController),

                      SizedBox(height: screenHeight * 0.030),
                      _buildLabel('비밀번호'),
                      SizedBox(height: screenHeight * 0.010),
                      _buildInputField(controller: _passwordController, obscureText: true),

                      SizedBox(height: screenHeight * 0.030),
                      _buildLabel('이름'),
                      SizedBox(height: screenHeight * 0.010),
                      _buildInputField(controller: _nameController),

                      SizedBox(height: screenHeight * 0.030),
                      _buildLabel('전화번호'),
                      SizedBox(height: screenHeight * 0.010),
                      _buildInputField(controller: _phoneController, keyboardType: TextInputType.phone),

                      SizedBox(height: screenHeight * 0.030),
                      _buildLabel('보호자 이름'),
                      SizedBox(height: screenHeight * 0.010),
                      _buildInputField(controller: _guardianNameController),

                      SizedBox(height: screenHeight * 0.030),
                      _buildLabel('보호자 전화번호'),
                      SizedBox(height: screenHeight * 0.010),
                      _buildInputField(controller: _guardianPhoneController, keyboardType: TextInputType.phone),
                    ],
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.020),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('가입하기', style: TextStyle(fontSize: screenWidth * 0.050)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Text(text,
      style: TextStyle(fontSize: screenWidth * 0.050, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          isDense: true,
        ),
        style: TextStyle(fontSize: screenWidth * 0.050),
      ),
    );
  }
}
