import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http; // ✅ 수정: 'package.http' -> 'package:http'
import 'package:uuid/uuid.dart';
import '../models/drug_info.dart';
import '../services/medication_database_helper.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:medinfo/screens/home_screen.dart';

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
  final MedicationDatabaseHelper _dbHelper = MedicationDatabaseHelper();
  final SpeechToText _speechToText = SpeechToText();
  final String _sessionId = const Uuid().v4();

  bool _isLoading = false;
  String _loadingMessage = "AI가 답변을 생각 중입니다...";
  bool _speechEnabled = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _generateInitialMessage();
  }

  Future<void> _generateInitialMessage() async {
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

        final productName =
            jsonData['product_name'] ?? widget.drugInfo!.itemName;
        final summary = jsonData['summary'];
        final efficacy = summary['efficacy'] ?? '정보 없음';
        final dosage = summary['dosage'] ?? '정보 없음';

        const delay = Duration(milliseconds: 800);

        _addMessage("안녕하세요! 검색하신 약물은 ${productName}입니다.", isUser: false);
        await Future.delayed(delay);
        _addMessage(efficacy, isUser: false);
        await Future.delayed(delay);
        _addMessage(dosage, isUser: false);
        await Future.delayed(delay);
        _addMessage("해당 약에 대해 더 궁금하신 내용이 있으신가요?", isUser: false);
      } catch (e) {
        print('초기 메시지 생성 오류 (파일 없음): $e');
        const delay = Duration(milliseconds: 800);
        _addMessage("안녕하세요! 검색된 약물은 ${widget.drugInfo!.itemName}입니다.",
            isUser: false);
        await Future.delayed(delay);
        _addMessage("죄송하지만 아직 해당 약물에 대한 상세 정보가 준비되지 않아 안내해 드리기 어렵습니다.",
            isUser: false);
      }
    } else {
      _addMessage("안녕하세요! 의약품에 대해 궁금한 점을 무엇이든 물어보세요.", isUser: false);
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

    const apiUrl = 'https://kjyfi4w1u5.execute-api.ap-northeast-2.amazonaws.com/say-1-3team-final-prod1/say-1-3team-final-BedrockChatApi';
    
    String completionData = ''; 

    try {
      final Map<String, dynamic> requestBody = {
        'prompt': text,
        'sessionId': _sessionId,
      };
      if (widget.drugInfo != null) {
        requestBody['drugName'] = widget.drugInfo!.itemName;
      }
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
        completionData = responseBody[0] as String;

        try {
          final actionData = json.decode(completionData);
          if (actionData['action'] == 'CHECK_MEDICATION_RECORD') {
            await _handleCheckRecordAction();
            return;
          }
        } catch (e) {
          _addMessage(completionData, isUser: false);
        }
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        _addMessage('오류가 발생했습니다. (상태 코드: ${response.statusCode})\n응답: $errorBody', isUser: false);
      }
    } catch (e) {
      _addMessage('API 호출 중 오류가 발생했습니다: $e', isUser: false);
    } finally {
      if (mounted) {
        if (!completionData.contains('CHECK_MEDICATION_RECORD')) {
           setState(() {
             _isLoading = false;
           });
        }
      }
    }
  }

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
                  Text(_loadingMessage,
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
                style: TextStyle(color: fg, fontSize: 16, height: 1.2),
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
                          fontSize: 16,
                          height: 1.2
                        ),
                      ),
                      style: const TextStyle(fontSize: 16),
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