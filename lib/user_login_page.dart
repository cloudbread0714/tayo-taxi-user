import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  
  // 튜토리얼 관련 변수들
  final GlobalKey signupButtonKey = GlobalKey();
  late TutorialCoachMark tutorialCoachMark;
  List<TargetFocus> targets = [];

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // 앱 시작 시 자동 로그인 확인
    
    // 위젯이 완전히 빌드된 후 튜토리얼 시작 (최초 1회만)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowSignupTutorial(context);
    });
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

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

  void _goToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignUpPage()),
    );
  }

  Future<void> _checkAndShowSignupTutorial(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 로그아웃 후 로그인 페이지에 도달했을 때는 currentUser가 null이므로
    // 로그아웃 상태에서의 튜토리얼을 체크
    final key = 'has_shown_login_tutorial_logout';
    final hasShownTutorial = prefs.getBool(key) ?? false;
    
    if (!hasShownTutorial) {
      await prefs.setBool(key, true);
      _showSignupTutorial(context);
    }
  }

  void _showSignupTutorial(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    targets.clear();
    targets.addAll([
      TargetFocus(
        identify: "signup",
        keyTarget: signupButtonKey,
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "버튼을 눌러 회원가입을 해주세요",
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  "버튼을 터치하세요",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: screenWidth * 0.035,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    ]);

    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black.withOpacity(0.8),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {},
      onClickTarget: (target) {
        // 회원가입 버튼을 클릭하면 튜토리얼을 종료하고 회원가입 화면으로 이동
        tutorialCoachMark.finish();
        _goToSignUp();
        return true;
      },
      onClickOverlay: (target) {
        tutorialCoachMark.next();
        return true;
      },
      onSkip: () {
        return true;
      },
      hideSkip: true,
    );

    tutorialCoachMark.show(context: context);
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
                key: signupButtonKey,
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
