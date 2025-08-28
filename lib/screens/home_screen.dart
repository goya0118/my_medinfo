import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'barcode_scanner_screen.dart';
import 'ai_chat_screen.dart'; // AiChatScreen을 import 합니다.
import 'medication_record_screen.dart';
import 'add_medication_record_screen.dart';

/// 상단 타이틀 바 (AppBar 대체용)
class TitleHeader extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;              // String → Widget
  final String? leadingSvg;
  final Widget? leading;
  final List<Widget>? actions;     // ← actions 지원
  final double height;

  const TitleHeader({
    super.key,
    this.title = const Text(
      '내꺼약',
      style: TextStyle(
        color: Color(0xFF5B32F4),
        fontSize: 32,
        fontFamily: 'Pretendard',
        fontWeight: FontWeight.w700,
      ),
    ),
    this.leadingSvg,
    this.leading,
    this.actions,
    this.height = 90,
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
              // leading: IconButton이면 그대로 배치 (패딩/제약 직접 설정 권장)
              if (leading != null) ...[
                // IconButton 기본 48x48이라 padding/constraints 줄이면 더 깔끔
                ConstrainedBox(
                  constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                  child: IconButton(
                    // 사용자가 준 leading이 IconButton이 아닐 수도 있으니 처리
                    icon: leading is IconButton
                        ? (leading as IconButton).icon
                        : leading!,
                    onPressed: leading is IconButton
                        ? (leading as IconButton).onPressed
                        : null,
                    padding: EdgeInsets.zero,
                    iconSize: 30,
                    splashRadius: 24,
                    color: const Color(0xff5B32F4),
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (leadingSvg != null) ...[
                SizedBox(
                  width: 37, height: 37,
                  child: SvgPicture.asset(leadingSvg!),
                ),
                const SizedBox(width: 8),
              ],

              // Title (왼쪽 정렬 유지)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: title,
                ),
              ),

              // actions 렌더링
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Row(mainAxisSize: MainAxisSize.min, children: actions!),
              ],
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
      appBar: TitleHeader(
        title: Text(
          '내꺼약',
          style: TextStyle(
            color: Color(0xFF5B32F4),
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        leadingSvg: 'assets/images/bi.svg',
        actions: [
          IconButton(
            icon: SvgPicture.asset('assets/images/icon-alarm-on.svg', width: 30, height: 30),
            // icon: const Icon(Icons.alarm_on, color: Color(0xff5B32F4)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('알림 기능 준비 중입니다')),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(                     // ← 스크롤 없음
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '안녕하세요 김조흔님',
              style: TextStyle(
                fontSize: 28,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(height: 20),

            buildButton(
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

            buildButton(
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

            buildButton(
              context,
              label: '복약 기록 관리',
              icon: SvgPicture.asset('assets/images/icon-view-event.svg', width: 28, height: 28),
              backgroundColor: Colors.white,
              textColor: const Color(0xFF5B32F4),
              strokeColor: const Color(0xFF5B32F4),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MedicationRecordScreen(),
                  ),
                  // ScaffoldMessenger.of(context).showSnackBar(
                  //   const SnackBar(content: Text('복약 기록 관리 기능은 준비 중입니다.')),
                  // );
                );
              },
            ),

            const SizedBox(height: 20),

            buildButton(
              context,
              label: '복약 기록 추가',
              icon: SvgPicture.asset('assets/images/icon-add-event.svg', width: 28, height: 28),
              backgroundColor: Colors.white,
              textColor: const Color(0xFF5B32F4),
              strokeColor: const Color(0xFF5B32F4),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddMedicationRecordScreen(),
                  ),
                );
              },
            ),


            const Spacer(),                 // 남는 공간은 하단으로 밀어 고정감 유지

            const Padding(
              padding: EdgeInsets.only(left: 10, right: 10),
              child: Text(
                "* 내꺼약은 공신력 있는 기관의 자료를 바탕으로 일반적인 복용 정보를 제공 합니다만, 최종 복용 결정은 반드시 의사·약사와 상담하세요.",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF828282),
                  fontFamily: 'Pretendard',
                  height: 1.0,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  /// 버튼 위젯 빌더 (공통 스타일)
  static Widget buildButton(
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
      height: 90,
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
          // 아이콘 영역 34x34
          SizedBox(
            width: 34,
            height: 34,
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
              fontSize: 28,
              fontFamily: 'Pretandard', // ← 이전 요청 반영(필요 시 'Pretendard'로 변경)
              fontWeight: FontWeight.bold,
              height: 0.05,           // Figma 값 그대로 (줄간격 매우 타이트)
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

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 2; // 0:카메라 1:음성검색 2:홈 3:기록관리 4:기록추가

  final _pages = [
    BarcodeScannerScreen(),
    AiChatScreen(), // 음성 질문 화면(or 마이크 진입 화면)
    HomeScreen(),
    MedicationRecordScreen(),
    AddMedicationRecordScreen(), // 신규 추가 화면이 있다면
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      // 바텀바를 감싸서 그림자/높이/배경을 Figma처럼
      bottomNavigationBar: Container(
        height: 100,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x3F000000), // #00000063 근사
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF5B32F4),
            unselectedItemColor: const Color(0xFF828282),
            selectedLabelStyle: const TextStyle(
              fontSize: 12,
              letterSpacing: 0.4,
              // fontFamily: 'Pretendard', // 등록돼 있으면 주석 해제
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              letterSpacing: 0.4,
            ),
            // 아이콘 사이 간격/패딩을 키워 Figma 느낌 살리기
            selectedIconTheme: const IconThemeData(size: 32),
            unselectedIconTheme: const IconThemeData(size: 32),
            items: [
              BottomNavigationBarItem(
                icon: SvgPicture.asset('assets/images/icon-scan-disable.svg'),
                activeIcon: SvgPicture.asset('assets/images/icon-scan-active.svg'),
                label: '카메라',
              ),
              BottomNavigationBarItem(
                icon: SvgPicture.asset('assets/images/icon-audio-disable.svg'),
                activeIcon: SvgPicture.asset('assets/images/icon-audio-active.svg'),
                label: '음성검색',
              ),
              BottomNavigationBarItem(
                icon: SvgPicture.asset('assets/images/icon-home-disable.svg'),
                activeIcon: SvgPicture.asset('assets/images/icon-home-active.svg'),
                label: '홈',
              ),
              BottomNavigationBarItem(
                icon: SvgPicture.asset('assets/images/icon-view-event-disable.svg'),
                activeIcon: SvgPicture.asset('assets/images/icon-view-event-active.svg'),
                label: '기록관리',
              ),
              BottomNavigationBarItem(
                icon: SvgPicture.asset('assets/images/icon-add-event-disable.svg'),
                activeIcon: SvgPicture.asset('assets/images/icon-add-event-active.svg'),
                label: '기록추가',
              ),
            ],
          ),
        ),
      ),
    );
  }
}