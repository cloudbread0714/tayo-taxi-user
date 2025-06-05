import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'firebase_options.dart';
import 'user_login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 엔진 바인딩

  await dotenv.load(fileName: ".env"); // .env 파일 로딩

  await Firebase.initializeApp( // Firebase 초기화
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Naver 지도 초기화
  final naverMap = FlutterNaverMap(); // 인스턴스 생성
  await naverMap.init(
    clientId: dotenv.env['NAVER_CLIENT_ID']!,
    onAuthFailed: (e) => debugPrint("❌ 네이버 지도 인증 실패: $e"),
  );

  // GOOGLE API 키 확인 (옵션)
  final apiKey = dotenv.env['GOOGLE_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    debugPrint("❌ GOOGLE_API_KEY가 .env에 없거나 비어 있습니다.");
  } else {
    debugPrint("✅ GOOGLE_API_KEY가 성공적으로 로딩되었습니다.");
  }

  runApp(const MyApp()); // 앱 실행
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TayoTaxi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Arial',
      ),
      home: const LoginPage(), // 시작 페이지 설정
    );
  }
}