import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'barcode_scanner_screen.dart';
import 'ai_chat_screen.dart';

/// 상단 타이틀 바 (AppBar 대체용)
class TitleHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? leadingSvg;
  final Widget? leading;
  final double height;

  const TitleHeader({
    super.key,
    this.title = '내꺼약',
    this.leadingSvg,              // 예: 'assets/images/bi.svg'
    this.leading,
    this.height = 100,               // AppBar 높이
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          height: height,
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE8E8E8), width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1) leading 위젯이 있으면 그걸 사용 (예: 뒤로가기 버튼)
              if (leading != null) ...[
                SizedBox(width: 37, height: 37, child: Center(child: leading)),
                const SizedBox(width: 8),
              ]
              // 2) 없으면 SVG 사용
              else if (leadingSvg != null) ...[
                SizedBox(
                  width: 37, height: 37,
                  child: SvgPicture.asset(leadingSvg!),
                ),
                const SizedBox(width: 8),
              ],
              
              // 타이틀
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5B32F4),
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: 0.4,
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

/// 홈 화면 (스크롤 금지)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,        // 배경 흰색 고정
      resizeToAvoidBottomInset: false,      // 키보드로 인한 위아래 이동 방지
      appBar: const TitleHeader(
        title: '내꺼약',
        leadingSvg: 'assets/images/bi.svg',
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(                     // ← 스크롤 없음
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '안녕하세요 김조흔님',
              style: TextStyle(
                fontSize: 32,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(height: 20),

            _buildButton(
              context,
              label: '카메라로 검색',
              icon: SvgPicture.asset('assets/images/icon-scan.svg', width: 28, height: 28),
              backgroundColor: const Color(0xFF5B32F4),
              textColor: Colors.white,
              strokeColor: const Color(0xFF5B32F4),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                );
              },
            ),
            const SizedBox(height: 20),

            _buildButton(
              context,
              label: '음성으로 질문',
              icon: SvgPicture.asset('assets/images/icon-audio.svg', width: 28, height: 28),
              backgroundColor: const Color(0xFF5B32F4),
              textColor: Colors.white,
              strokeColor: const Color(0xFF5B32F4),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // drugInfo 파라미터 없이 AiChatScreen을 호출합니다.
                    builder: (context) => const AiChatScreen(),
                  ),
                );
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(builder: (_) => const AiChatScreen()),
                // );
                // ScaffoldMessenger.of(context).showSnackBar(
                //   const SnackBar(content: Text('AI 질문 기능 준비 중입니다')),
                // );
              },
            ),
            const SizedBox(height: 20),

            _buildButton(
              context,
              label: '복약 기록 관리',
              icon: SvgPicture.asset('assets/images/icon-view-event.svg', width: 28, height: 28),
              backgroundColor: Colors.white,
              textColor: const Color(0xFF5B32F4),
              strokeColor: const Color(0xFF5B32F4),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('복약 기록 관리 기능은 준비 중입니다.')),
                );
              },
            ),

            const Spacer(),                 // 남는 공간은 하단으로 밀어 고정감 유지
          ],
        ),
      ),
    );
  }

  /// 버튼 위젯 빌더 (공통 스타일)
  static Widget _buildButton(
    BuildContext context, {
    required String label,
    required Widget icon,             // SVG/아이콘 위젯 그대로 전달
    required Color backgroundColor,   // 버튼 배경색
    required Color textColor,         // 텍스트 색
    required Color strokeColor,       // 외곽선(스트로크) 색
    VoidCallback? onPressed,
  }) {
    final button = Container(
      width: 358,
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 16),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 2, color: strokeColor),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 아이콘 영역 50x50
          SizedBox(
            width: 50,
            height: 50,
            child: FittedBox(
              fit: BoxFit.contain,
              child: icon,
            ),
          ),
          const SizedBox(width: 8),
          // 라벨
          Text(
            label,
            // ↓ Figma 추출값에 맞춘 스타일 (원하시면 'Standard'로 교체 가능)
            style: TextStyle(
              color: textColor,
              fontSize: 32,
              fontFamily: 'Standard', // ← 이전 요청 반영(필요 시 'Pretendard'로 변경)
              fontWeight: FontWeight.bold,
              height: 0.03,           // Figma 값 그대로 (줄간격 매우 타이트)
              letterSpacing: 0.40,
            ),
          ),
        ],
      ),
    );

    // 터치 가능하도록 InkWell로 감쌉니다. onPressed가 없으면 비활성 느낌으로 그대로 렌더링
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: button,
      ),
    );
  }
  // static Widget _buildButton(
  //   BuildContext context, {
  //   required String label,
  //   required Widget icon,             // 아이콘을 위젯으로 받음(SVG/아이콘 모두 OK)
  //   required Color backgroundColor,   // 버튼 배경색
  //   required Color textColor,         // 텍스트/아이콘 기본색
  //   required Color strokeColor,       // 버튼 외곽선(스트로크) 색
  //   required VoidCallback onPressed,
  // }) {
  //   return SizedBox(
  //     height: 120,
  //     width: double.infinity,
  //     child: ElevatedButton.icon(
  //       onPressed: onPressed,
  //       icon: icon,
  //       label: Text(
  //         label,
  //         style: const TextStyle(
  //           fontFamily: 'Standard',  // 요청: 폰트 패밀리 Standard
  //           fontSize: 32,            // 요청: 폰트 크기 32
  //           fontWeight: FontWeight.bold,
  //         ),
  //       ),
  //       style: ElevatedButton.styleFrom(
  //         backgroundColor: backgroundColor,                 // 배경색
  //         foregroundColor: textColor,                       // 텍스트/아이콘 색
  //         side: BorderSide(color: strokeColor, width: 2),   // 외곽선(스트로크)
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(16),
  //         ),
  //         padding: const EdgeInsets.symmetric(horizontal: 16),
  //       ),
  //     ),
  //   );
  // }
}