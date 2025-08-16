import 'package:flutter/material.dart';
import 'config/env_config.dart';
import 'screens/home_screen.dart';

void main() async {
  // Flutter 초기화
  WidgetsFlutterBinding.ensureInitialized();
  
  // 환경 변수 로드
  await EnvConfig.load();
  
  // 설정 유효성 검사
  if (!EnvConfig.isConfigValid) {
    print('⚠️ 환경 변수 설정이 올바르지 않습니다. .env 파일을 확인해주세요.');
  }
  
  runApp(const MedicineBarcodeScannerApp());
}

class MedicineBarcodeScannerApp extends StatelessWidget {
  const MedicineBarcodeScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '내가 꺼내는 약정보',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}