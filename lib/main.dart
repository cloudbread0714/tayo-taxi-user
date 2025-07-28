import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'firebase_options.dart';
import 'user_login_page.dart';

Future<void> main() async {
  // Flutter 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  //  Naver Map SDK 초기화 (clientId는 .env 파일에서 로드)
  final naverClientId = dotenv.env['NAVER_CLIENT_ID'];
  if (naverClientId == null || naverClientId.isEmpty) {
    debugPrint('.env 파일에 NAVER_CLIENT_ID가 누락되어 있습니다.');
    return; // 앱 실행 중단
  }

  final naverMap = FlutterNaverMap();
  await naverMap.init(
    clientId: naverClientId,
    onAuthFailed: (e) => debugPrint(' NaverMap 인증 실패: $e'),
  );

  // 앱 실행
  runApp(const MyApp());
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
      home: const LoginPage(), // 시작 화면
    );
  }
}