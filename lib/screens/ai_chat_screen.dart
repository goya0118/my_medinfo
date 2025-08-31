import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medinfo/screens/home_screen.dart';
import 'package:uuid/uuid.dart';
import '../models/drug_info.dart';
import '../services/medication_database_helper.dart'; // ✅ 새로 추가
import 'package:speech_to_text/speech_to_text.dart';

// 채팅 메시지를 표현하는 간단한 클래스
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, {this.isUser = false});
}

class AiChatScreen extends StatefulWidget {
  final DrugInfo? drugInfo;
  const AiChatScreen({super.key, this.drugInfo});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final MedicationDatabaseHelper _dbHelper = MedicationDatabaseHelper(); // ✅ 새로 추가
  bool _isLoading = false;
  String _loadingMessage = "AI가 답변을 생각 중입니다..."; // ✅ 동적 로딩 메시지

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  final String _sessionId = const Uuid().v4();

  final FocusNode _composerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _generateInitialMessage();

    _textController.addListener(_onComposerChanged);
    _composerFocusNode.addListener(() => setState(() {}));
  }

  void _generateInitialMessage() async {
    // 1. 약물 정보가 있는 경우 (바코드 스캔)
    if (widget.drugInfo != null) {
      try {
        final atcCode = widget.drugInfo!.atcCode;
        final engName = widget.drugInfo!.engName;

        if (atcCode == null ||
            engName == null ||
            atcCode.isEmpty ||
            engName.isEmpty) {
          throw Exception('ATC 코드 또는 영문명이 없습니다.');
        }

        final firstWordOfEngName = engName.split(' ')[0];
        final fileName = '${atcCode}_$firstWordOfEngName.json';
        final assetPath = 'lib/widgets/drug_info_jsonfiles/$fileName';

        final jsonString = await rootBundle.loadString(assetPath);
        final jsonData = json.decode(jsonString);

        final productName = jsonData['product_name'] ?? widget.drugInfo!.itemName;
        final summary = jsonData['summary'];
        final efficacy = summary['efficacy'] ?? '정보 없음';
        final dosage = summary['dosage'] ?? '정보 없음';

        const delay = Duration(milliseconds: 800);

        _addMessage(
          "안녕하세요! 검색하신 약물은 ${productName}입니다.",
          isUser: false,
        );
        await Future.delayed(delay);
        _addMessage(
          efficacy,
          isUser: false,
        );
        await Future.delayed(delay);
        _addMessage(
          dosage,
          isUser: false,
        );
        await Future.delayed(delay);
        _addMessage(
          "해당 약에 대해 더 궁금하신 내용이 있으신가요?",
          isUser: false,
        );
      } catch (e) {
        print('초기 메시지 생성 오류 (파일 없음): $e');
        const delay = Duration(milliseconds: 800);
        _addMessage(
          "안녕하세요! 검색된 약물은 ${widget.drugInfo!.itemName}입니다.",
          isUser: false,
        );
        await Future.delayed(delay);
        _addMessage(
          "죄송하지만 아직 해당 약물에 대한 상세 정보가 준비되지 않아 안내해 드리기 어렵습니다.",
          isUser: false,
        );
      }
    }
    // 2. 약물 정보가 없는 경우 (메인 화면에서 진입)
    else {
      _addMessage(
        "안녕하세요! 의약품에 대해 궁금한 점을 무엇이든 물어보세요.",
        isUser: false,
      );
    }
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _textController.text = result.recognizedWords;
        });
      },
      localeId: 'ko_KR',
    );
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _handleMicButtonPressed() {
    if (!_speechEnabled || _isLoading) return;

    if (_isListening) {
      _stopListening();
      if (_textController.text.trim().isNotEmpty) {
        _handleSubmitted(_textController.text);
      }
    } else {
      _textController.clear();
      _startListening();
    }
  }

  void _addMessage(String text, {bool isUser = false}) {
    setState(() {
      _messages.insert(0, ChatMessage(text, isUser: isUser));
      if (!isUser) {
        _isLoading = false;
        SemanticsService.announce(text, TextDirection.ltr);
      }
    });
    Timer(
        const Duration(milliseconds: 100), () => _scrollController.jumpTo(0));
  }

  // ✅ 복약기록 확인 기능 추가
  Future<void> _handleSubmitted(String text, {bool isSecondRequest = false}) async {
    if (!isSecondRequest) {
      _textController.clear();
      if (text.trim().isEmpty) return;
      _addMessage(text, isUser: true);
    }

    setState(() {
      _isLoading = true;
      if (!isSecondRequest) {
        _loadingMessage = "AI가 답변을 생각 중입니다...";
      }
    });

    const apiUrl =
        'https://kjyfi4w1u5.execute-api.ap-northeast-2.amazonaws.com/say-1-3team-final-prod1/say-1-3team-final-BedrockChatApi';

    String completionData = '';

    try {
      final Map<String, dynamic> requestBody = {
        'prompt': text,
        'sessionId': _sessionId,
      };

      // 만약 특정 약물 정보가 있다면, 'drugName'을 추가로 보냅니다.
      if (widget.drugInfo != null) {
        requestBody['drugName'] = widget.drugInfo!.itemName;
      }

      // ✅ 추가: 두 번째 요청인지 표시
      if (isSecondRequest) {
        requestBody['isFollowUp'] = true;
      }

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseBody = json.decode(utf8.decode(response.bodyBytes));
        String content = '죄송합니다. 답변을 이해할 수 없습니다.';

        // ✅ 수정: completionData 추출
        try {
          if (responseBody is Map && responseBody.containsKey('completion')) {
            completionData = responseBody['completion'];
          } else if (responseBody is List &&
              responseBody.isNotEmpty &&
              responseBody[0] is Map &&
              responseBody[0].containsKey('completion')) {
            completionData = responseBody[0]['completion'];
          } else if (responseBody is List &&
              responseBody.isNotEmpty &&
              responseBody[0] is String) {
            completionData = responseBody[0] as String;
          } else {
            completionData = '예상치 못한 답변 형식입니다: $responseBody';
          }

          // ✅ 새로 추가: 복약기록 확인 액션 처리
          try {
            final actionData = json.decode(completionData);
            if (actionData['action'] == 'CHECK_MEDICATION_RECORD') {
              await _handleCheckRecordAction();
              return;
            }
          } catch (e) {
            // JSON이 아니면 일반 텍스트로 처리
            content = completionData;
          }

          content = completionData;
        } catch (e) {
          content = '답변 처리 중 오류가 발생했습니다: $e';
        }

        _addMessage(content, isUser: false);
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        _addMessage(
            '오류가 발생했습니다. (상태 코드: ${response.statusCode})\n응답: $errorBody',
            isUser: false);
      }
    } catch (e) {
      _addMessage('API 호출 중 오류가 발생했습니다: $e', isUser: false);
    } finally {
      if (mounted) {
        // ✅ 복약기록 확인 중이 아닐 때만 로딩 해제
        if (!completionData.contains('CHECK_MEDICATION_RECORD')) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // ✅ 새로 추가: 복약기록 확인 액션 처리
  Future<void> _handleCheckRecordAction() async {
    _addMessage("복약기록을 확인하여 상호작용이 있는지 살펴볼게요.", isUser: false);

    setState(() {
      _isLoading = true;
      _loadingMessage = "복약기록을 확인하는 중입니다...";
    });

    final records = await _dbHelper.getAllMedicationRecords();
    final recordNames = records.map((r) => r.medicationName).join(', ');

    if (recordNames.isEmpty) {
      _addMessage("저장된 복약기록이 없습니다. 확인이 필요하시면 복약기록을 먼저 추가해주세요.", isUser: false);
      setState(() => _isLoading = false);
      return;
    }

    final secondPrompt = "현재 제 복약기록에는 '${recordNames}'이(가) 있습니다. 지금 보고 있는 약인 '${widget.drugInfo!.itemName}'과(와) 함께 복용해도 괜찮은지 확인해주세요.";

    _handleSubmitted(secondPrompt, isSecondRequest: true);
  }

  void _onComposerChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _composerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = widget.drugInfo != null
        ? 'AI 상담 ${widget.drugInfo!.itemName}'
        : 'AI 상담';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: TitleHeader(
        title: widget.drugInfo != null
            ? RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: 'AI 상담: ',
                      style: TextStyle(
                        color: Color(0xFF5B32F4),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: widget.drugInfo!.itemName,
                      style: const TextStyle(
                        color: Color(0xFF5B32F4),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            : const Text('AI 상담',
                style: TextStyle(
                  color: Color(0xFF5B32F4),
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xff5B32F4)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
            icon: SvgPicture.asset('assets/images/icon-home-disable.svg'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (_, int index) => _buildChatBubble(_messages[index]),
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text(_loadingMessage, // ✅ 동적 로딩 메시지 사용
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    final isUser = message.isUser;

    final bg = isUser ? const Color(0xFF5B32F4) : const Color(0xFFF6F6FA);
    final fg = isUser ? Colors.white : const Color(0xFF222222);
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment: align,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: SelectableText(
                message.text,
                style: TextStyle(color: fg, fontSize: 18, height: 1.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    const radius = 8.0;
    const borderColor = Color(0xFF8E8E93);

    // 토글 조건: 입력창에 포커스가 있거나, 텍스트가 1자 이상이면 '보내기' 표시
    final bool hasText = _textController.text.trim().isNotEmpty;
    final bool showSend = _composerFocusNode.hasFocus || hasText;

    return Material(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
        ),
        side: BorderSide(
          color: borderColor,
          width: 1,
        ),
      ),
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 본체
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF7F7FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(radius),
                topRight: Radius.circular(radius),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _composerFocusNode,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: _isLoading ? null : _handleSubmitted,
                      decoration: const InputDecoration.collapsed(
                        hintText: '질문을 입력하거나 마이크를 누르세요',
                        hintStyle: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 18,
                          height: 1.1,
                        ),
                      ),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),

                  // === 오른쪽 버튼 한 자리에서 스위칭 ===
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: showSend
                        ? IconButton(
                            key: const ValueKey('send'),
                            icon: const Icon(Icons.send),
                            iconSize: 24,
                            color: const Color(0xff5B32F4),
                            onPressed: _isLoading
                                ? null
                                : () => _handleSubmitted(_textController.text),
                          )
                        : IconButton(
                            key: const ValueKey('mic'),
                            icon: Icon(
                              _isListening
                                  ? Icons.stop_circle_outlined
                                  : Icons.mic,
                            ),
                            iconSize: 24,
                            color: _isListening
                                ? Colors.redAccent
                                : const Color(0xff5B32F4),
                            onPressed: _isLoading || !_speechEnabled
                                ? null
                                : _handleMicButtonPressed,
                          ),
                  ),
                ],
              ),
            ),
          ),

          // 아래 테두리 가리개(상/좌/우만 보더 느낌)
          Positioned(
            left: -2,
            right: -2,
            bottom: -2,
            height: 4,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ],
      ),
    );
  }
}