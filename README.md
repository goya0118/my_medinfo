# medinfo

A new Flutter project.

git clone https://github.com/goya0118/my_medinfo.git

## Requirement
Flutter SDK 설치
루트 경로에 .env 파일 생성 (config.py 역할)
Xcode 설치 (앱스토어에서)
flutter pub get -> requirement 설치!!

## 파일 설명

pubspec.yaml -> requirement 역할

lib -> 코드 파일들 

lib/config/env_config -> config 등 환경변수
lib/models/drug_info -> api 호출 후 형식 변환

lib/screens
- barcode_scanner_screen -> 카메라 기능 본체 
- drug_info_screen -> 인식 후 결과 화면
- home_screen -> 메인화면 스크린

lib/services
- barcode_processor -> 바코드 추출
- camera_manager -> 카메라 로드 / 권한
- drug_api_service -> api 호출

lib/widgets
- camera_view_widget -> 카메라 로딩 / 오류 등 위젯
- drug_info_widget -> 약품 검색 위젯

lib/main -> main 함수