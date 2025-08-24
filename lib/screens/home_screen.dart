import 'package:flutter/material.dart';
import 'barcode_scanner_screen.dart';
import 'ai_chat_screen.dart'; // AiChatScreen을 import 합니다.

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 로고
              Container(
                height: 120,
                child: Image.asset(
                  'assets/images/logo.png',
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.medical_services,
                        size: 60,
                        color: Colors.blue,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),

              // 제목
              const Text(
                '내가 꺼내는 약정보',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(height: 60),

              // 카메라로 검색 버튼
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BarcodeScannerScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.qr_code_scanner,
                    size: 28,
                  ),
                  label: const Text(
                    '카메라로 검색',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 생성형 AI에게 질문 버튼
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  // /// [수정] onPressed 로직을 AiChatScreen으로 이동하도록 변경
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // drugInfo 파라미터 없이 AiChatScreen을 호출합니다.
                        builder: (context) => const AiChatScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    size: 28,
                  ),
                  label: const Text(
                    '생성형 AI에게 질문',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 복약 기록 관리 버튼
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // 임시 메시지 표시
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('복약 기록 관리 기능은 준비 중입니다.'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.history,
                    size: 28,
                  ),
                  label: const Text(
                    '복약 기록 관리',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}