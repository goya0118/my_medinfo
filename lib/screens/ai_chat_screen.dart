import 'package:flutter/material.dart';
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
  final DrugInfo drugInfo;
  const AiChatScreen({super.key, required this.drugInfo});

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
  
  // 채팅 화면이 열릴 때마다 고유한 세션 ID를 생성합니다.
  final String _sessionId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _addMessage('안녕하세요! ${widget.drugInfo.itemName}에 대해 무엇이 궁금하신가요?', isUser: false);
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

  void _addMessage(String text, {bool isUser = false}) {
    setState(() {
      _messages.insert(0, ChatMessage(text, isUser: isUser));
      if (!isUser) {
        _isLoading = false;
      }
    });
    Timer(const Duration(milliseconds: 100), () => _scrollController.jumpTo(0));
  }

  void _handleSubmitted(String text) async {
    _textController.clear();
    if (text.trim().isEmpty) return;

    _addMessage(text, isUser: true);

    setState(() {
      _isLoading = true;
    });

    const apiUrl = 'https://kjyfi4w1u5.execute-api.ap-northeast-2.amazonaws.com/say-1-3team-final-prod1/say-1-3team-final-BedrockChatApi';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'prompt': text,
          'sessionId': _sessionId 
        }),
      ).timeout(const Duration(seconds: 20));

      // 디버깅용 print는 그대로 둡니다.
      print('--- Server Response ---');
      print('Status Code: ${response.statusCode}');
      print('Raw Body: ${utf8.decode(response.bodyBytes)}');
      print('-----------------------');

      if (response.statusCode == 200) {
        // 1. 서버 응답을 Dart 객체로 디코딩합니다.
        final responseBody = json.decode(utf8.decode(response.bodyBytes));
        
        // 2. 보기 좋게 들여쓰기 된 JSON 문자열로 다시 변환합니다.
        const encoder = JsonEncoder.withIndent('  '); // 2칸 들여쓰기
        final formattedJsonString = encoder.convert(responseBody);

        // 3. 변환된 전체 문자열을 채팅 메시지로 추가합니다.
        _addMessage(formattedJsonString, isUser: false);

      } else {
        // 오류 발생 시에는 원본 응답 본문을 그대로 보여줍니다.
        final errorBody = utf8.decode(response.bodyBytes);
        _addMessage('오류가 발생했습니다. (상태 코드: ${response.statusCode})\n응답: $errorBody', isUser: false);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.drugInfo.itemName} AI 상담'),
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
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text("AI가 답변을 생각 중입니다...", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    final bubbleAlignment = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.isUser ? Colors.deepPurple : Colors.grey[200];
    final textColor = message.isUser ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: bubbleAlignment,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
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
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              color: Colors.deepPurple,
              onPressed: _isLoading || !_speechEnabled
                  ? null
                  : (_isListening ? _stopListening : _startListening),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              color: Colors.deepPurple,
              onPressed: _isLoading ? null : () => _handleSubmitted(_textController.text),
            ),
          ],
        ),
      ),
    );
  }
}