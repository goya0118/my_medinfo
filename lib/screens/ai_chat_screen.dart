import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/drug_info.dart';
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
        ? '${widget.drugInfo!.itemName} AI 상담'
        : 'AI 약사에게 질문하기';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: Colors.deepPurple.shade100,
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
    final bubbleAlignment =
        message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.isUser ? Colors.deepPurple : Colors.grey[200];
    final textColor = message.isUser ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: bubbleAlignment,
        children: [
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message.text,
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 2,
            color: Colors.grey.withOpacity(0.1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                onSubmitted: _isLoading ? null : _handleSubmitted,
                decoration: const InputDecoration.collapsed(
                  hintText: '질문을 입력하거나 마이크를 누르세요',
                ),
              ),
            ),
            IconButton(
              icon: Icon(_isListening ? Icons.stop_circle_outlined : Icons.mic),
              color: _isListening ? Colors.redAccent : Colors.deepPurple,
              onPressed: _handleMicButtonPressed,
            ),
            IconButton(
              icon: const Icon(Icons.send),
              color: Colors.deepPurple,
              onPressed: _isLoading
                  ? null
                  : () => _handleSubmitted(_textController.text),
            ),
          ],
        ),
      ),
    );
  }
}