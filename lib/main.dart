// Flutter 앱의 시작점이 되는 파일입니다
// 이 파일은 앱이 처음 실행될 때 가장 먼저 실행되는 코드를 담고 있어요
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/env_config.dart';
import 'screens/home_screen.dart';

// main 함수: 앱이 시작될 때 가장 먼저 실행되는 함수예요
// async는 이 함수가 비동기로 동작한다는 뜻이에요 (데이터를 기다리는 동안 다른 일을 할 수 있어요)
void main() async {
  // Flutter 앱이 제대로 작동하기 위해 필요한 초기 설정을 해주는 코드예요
  // 마치 집을 지을 때 기초공사를 하는 것과 같아요
  WidgetsFlutterBinding.ensureInitialized();
  
  // 환경 변수라는 설정 파일을 불러오는 코드예요
  // 환경 변수는 앱이 어떤 환경에서 실행되는지 알려주는 정보예요 (예: 개발용, 실제 서비스용)
  await EnvConfig.load();
  
  
  // 설정 유효성 검사
  if (!EnvConfig.isConfigValid) {
    print('⚠️ 환경 변수 설정이 올바르지 않습니다. .env 파일을 확인해주세요.');
  }
  
  // 실제 앱을 화면에 표시하는 코드예요
  // 마치 집을 다 지은 후에 사람들이 살 수 있게 하는 것과 같아요
  runApp(const MedicineBarcodeScannerApp());
}

// 약품 바코드 스캐너 앱의 메인 클래스예요
// StatelessWidget은 화면이 변하지 않는 정적인 위젯이라는 뜻이에요
class MedicineBarcodeScannerApp extends StatelessWidget {
  // 생성자: 이 클래스로 객체를 만들 때 사용되는 특별한 함수예요
  // super.key는 부모 클래스에게 필요한 정보를 전달하는 코드예요
  const MedicineBarcodeScannerApp({super.key});

  // build 함수: 화면에 무엇을 그릴지 결정하는 함수예요
  // context는 현재 앱의 상태 정보를 담고 있는 상자예요
  @override
  Widget build(BuildContext context) {
    // MaterialApp: 구글의 Material Design 스타일을 사용하는 앱을 만드는 위젯이에요
    return MaterialApp(
      title: '내가 꺼내는 약정보', // 앱의 제목이에요
      theme: ThemeData(
        primarySwatch: Colors.blue, // 앱의 주요 색상을 파란색으로 설정해요
        useMaterial3: true, // Material Design 3 버전을 사용한다는 뜻이에요
      ),
      // 한국어 지원 설정
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'), // 한국어
        Locale('en', 'US'), // 영어
      ],
      locale: const Locale('ko', 'KR'), // 기본 언어를 한국어로 설정
      home: const HomeScreen(), // 앱이 시작될 때 보여줄 첫 번째 화면이에요
      debugShowCheckedModeBanner: false, // 개발 모드일 때 오른쪽 위에 표시되는 배너를 숨겨요
    );
  }
}