import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'login_page.dart';

Future<void> main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // .env 파일 로딩 (.env 파일이 루트에 있어야 함)
  await dotenv.load(fileName: ".env");

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 실제 API 키 불러오기 (확인용)
  final apiKey = dotenv.env['GOOGLE_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    debugPrint("❌ GOOGLE_API_KEY가 .env에 없거나 비어 있습니다.");
  } else {
    debugPrint("✅ GOOGLE_API_KEY가 성공적으로 로딩되었습니다.");
  }

  // ✅ Impeller 비활성화
  const isImpellerEnabled = false;
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
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Arial',
      ),
      home: const LoginPage(),
    );
  }
}