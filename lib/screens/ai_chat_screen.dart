import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'dart:convert';
// [수정] 'package.http'를 'package:http'로 변경
import 'package:http/http.dart' as http;
import 'package:medinfo/screens/home_screen.dart';
import 'package:uuid/uuid.dart';
import '../models/drug_info.dart';
import 'package:speech_to_text/speech_to_text.dart';

// (이하 코드는 이전과 동일)

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
  bool _isLoading = false;

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  final String _sessionId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _generateInitialMessage();
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

  void _handleSubmitted(String text) async {
    _textController.clear();
    if (text.trim().isEmpty) return;

    _addMessage(text, isUser: true);

    setState(() {
      _isLoading = true;
    });

    const apiUrl =
        'https://kjyfi4w1u5.execute-api.ap-northeast-2.amazonaws.com/say-1-3team-final-prod1/say-1-3team-final-BedrockChatApi';

    try {
      // ✅ 수정: 앱에서 프롬프트를 제거하고, 서버로 보낼 데이터를 구성합니다.
      final Map<String, String> requestBody = {
        'prompt': text,
        'sessionId': _sessionId,
      };

      // 만약 특정 약물 정보가 있다면, 'drugName'을 추가로 보냅니다.
      if (widget.drugInfo != null) {
        requestBody['drugName'] = widget.drugInfo!.itemName;
      }

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestBody), // ✅ 수정된 requestBody를 전송
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseBody = json.decode(utf8.decode(response.bodyBytes));
        String content = '죄송합니다. 답변을 이해할 수 없습니다.';
        // ... (이하 응답 처리 로직은 동일)
        try {
          if (responseBody is Map && responseBody.containsKey('completion')) {
            content = responseBody['completion'];
          } else if (responseBody is List &&
              responseBody.isNotEmpty &&
              responseBody[0] is Map &&
              responseBody[0].containsKey('completion')) {
            content = responseBody[0]['completion'];
          } else if (responseBody is List &&
              responseBody.isNotEmpty &&
              responseBody[0] is String) {
            content = responseBody[0];
          } else {
            content = '예상치 못한 답변 형식입니다: $responseBody';
          }
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = widget.drugInfo != null
        ? 'AI 상담: ${widget.drugInfo!.itemName}'
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
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: widget.drugInfo!.itemName,
                      style: const TextStyle(
                        color: Color(0xFF5B32F4),
                        fontSize: 20, // 원하는 작은 크기
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
                  Text("AI가 답변을 생각 중입니다...",
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
                style: TextStyle(color: fg, fontSize: 20, height: 1.2),
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

    return Material(
      // 둥근 사각형 테두리를 “밖쪽”으로 그립니다.
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
        ),
        side: const BorderSide(
          color: borderColor,
          width: 1,
          // ↓ Flutter 버전에 따라 지원. 에러 나면 이 줄만 지우세요.
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 본체: 배경/패딩
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
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: _isLoading ? null : _handleSubmitted,
                      decoration: const InputDecoration.collapsed(
                        hintText: '질문을 입력하거나 마이크를 누르세요',
                        hintStyle: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 20,
                          height: 1.2
                        ),
                      ),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isListening ? Icons.stop_circle_outlined : Icons.mic),
                    color: _isListening ? Colors.redAccent : Color(0xff5B32F4),
                    onPressed: _handleMicButtonPressed,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: Color(0xff5B32F4),
                    onPressed: _isLoading ? null : () => _handleSubmitted(_textController.text),
                  ),
                ],
              ),
            ),
          ),

          // 아랫변 가리개: 같은 배경색으로 살짝 덮어 “상/좌/우만 보더”
          Positioned(
            left: -2, right: -2, bottom: -2, height: 4,
            child: Container(
              // 화면 배경색(스크린 배경이 흰색이면 Colors.white 써도 됩니다)
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ],
      ),
    );
  }
}