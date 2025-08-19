import 'package:flutter/material.dart';
import 'dart:async';
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
      _isLoading = !isUser;
    });
    Timer(const Duration(milliseconds: 100), () => _scrollController.jumpTo(0));
  }

  void _handleSubmitted(String text) {
    _textController.clear();
    if (text.trim().isEmpty) return;

    _addMessage(text, isUser: true);

    Future.delayed(const Duration(milliseconds: 1500), () {
      _addMessage('${widget.drugInfo.itemName}의 "${text}"에 대한 답변입니다. (이것은 실제 AI 답변이 아닙니다)', isUser: false);
    });
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
              // ✅ 1. 누락되었던 itemBuilder 추가
              itemBuilder: (_, int index) {
                final message = _messages[index];
                return _buildChatBubble(message);
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  // ✅ 2. return 구문이 빠져있던 _buildChatBubble 함수 수정
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
        // ✅ 3. BoxShadow(...) 부분을 실제 코드로 수정
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
                onSubmitted: _handleSubmitted,
                decoration: const InputDecoration.collapsed(
                  hintText: '질문을 입력하거나 마이크를 누르세요',
                ),
              ),
            ),
            IconButton(
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              color: Colors.deepPurple,
              onPressed: _speechEnabled
                  ? (_isListening ? _stopListening : _startListening)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.send),
              color: Colors.deepPurple,
              onPressed: () => _handleSubmitted(_textController.text),
            ),
          ],
        ),
      ),
    );
  }
}