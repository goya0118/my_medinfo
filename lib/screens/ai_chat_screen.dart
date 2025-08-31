import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medinfo/screens/home_screen.dart';
import 'package:uuid/uuid.dart';
import '../models/drug_info.dart';
import '../services/medication_database_helper.dart';
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
  final MedicationDatabaseHelper _dbHelper = MedicationDatabaseHelper();
  bool _isLoading = false;
  String _loadingMessage = "AI가 답변을 생각 중입니다...";

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  final String _sessionId = const Uuid().v4();
  final FocusNode _composerFocusNode = FocusNode();

  // API 원본 JSON 데이터를 저장할 상태 변수
  Map<String, dynamic>? _rawApiData;

  @override
  void initState() {
    super.initState();
    _initSpeech();

    // 위젯이 생성될 때 drugInfo에 포함된 rawApiData를 상태 변수에 저장
    if (widget.drugInfo?.rawApiData != null) {
      _rawApiData = widget.drugInfo!.rawApiData;
    }

    _generateInitialMessage();

    _textController.addListener(_onComposerChanged);
    _composerFocusNode.addListener(() => setState(() {}));
  }

  // 초기 메시지 생성
  void _generateInitialMessage() async {
    if (widget.drugInfo != null) {
      try {
        final atcCode = widget.drugInfo!.atcCode;
        final engName = widget.drugInfo!.engName;

        if (atcCode == null || engName == null || atcCode.isEmpty || engName.isEmpty) {
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

        _addMessage("안녕하세요! 검색하신 약물은 ${productName}입니다.", isUser: false);
        await Future.delayed(delay);
        _addMessage(efficacy, isUser: false);
        await Future.delayed(delay);
        _addMessage(dosage, isUser: false);
        await Future.delayed(delay);
        _addMessage("해당 약에 대해 더 궁금하신 내용이 있으신가요?", isUser: false);
      } catch (e) {
        print('로컬 상세 정보 파일 없음. API 기본 정보를 바탕으로 Bedrock 요약을 요청합니다.');
        if (widget.drugInfo!.rawApiData != null) {
          await _summarizeWithBedrock(widget.drugInfo!.rawApiData!);
        } else {
          const delay = Duration(milliseconds: 800);
          _addMessage("안녕하세요! 검색된 약물은 ${widget.drugInfo!.itemName}입니다.", isUser: false);
          await Future.delayed(delay);
          _addMessage("죄송하지만 아직 해당 약물에 대한 상세 정보가 준비되지 않아 안내해 드리기 어렵습니다.", isUser: false);
        }
      }
    } else {
      _addMessage("안녕하세요! 의약품에 대해 궁금한 점을 무엇이든 물어보세요.", isUser: false);
    }
  }

  // Bedrock으로 첫 요약 요청
  Future<void> _summarizeWithBedrock(Map<String, dynamic> apiData) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = "AI가 약물 정보를 요약 중입니다...";
    });

    final prompt = """
    당신은 약사입니다. 다음은 대한민국 식약처 API를 통해 얻은 의약품 정보의 JSON 데이터입니다.
    이 데이터를 보고 사용자가 이해하기 쉽게 약에 대한 핵심 정보를 두세 문장으로 요약해서 설명해주세요.
    설명에는 약의 이름과 제조사가 반드시 포함되어야 합니다.
    "안녕하세요! 검색하신 약은 [약 이름]이며, [제조사]에서 만들었어요. 이 약은 주로 [효능효과 요약]에 사용됩니다." 와 같은 친절한 말투로 설명해주세요.
    [JSON 데이터]
    ${json.encode(apiData)}
    """;
    
    // ✅ .env 파일에서 API URL 불러오기
    final apiUrl = dotenv.env['API_GATEWAY_URL']!;

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'prompt': prompt, 'sessionId': _sessionId}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseBody = json.decode(utf8.decode(response.bodyBytes));
        String summary = responseBody[0] as String? ?? '요약 정보를 가져오는 데 실패했습니다.';
        _addMessage(summary, isUser: false);
        await Future.delayed(const Duration(milliseconds: 500));
        _addMessage("해당 약에 대해 더 궁금하신 점이 있나요?", isUser: false);
      } else {
        _addMessage('정보 요약 중 오류가 발생했습니다. (상태 코드: ${response.statusCode})', isUser: false);
      }
    } catch (e) {
      _addMessage('정보 요약 중 네트워크 오류가 발생했습니다: $e', isUser: false);
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // 사용자 질문 제출 처리
  Future<void> _handleSubmitted(String text, {bool isSecondRequest = false}) async {
    if (!isSecondRequest) {
      _textController.clear();
      if (text.trim().isEmpty) return;
      _addMessage(text, isUser: true);
    }

    setState(() {
      _isLoading = true;
      if (!isSecondRequest) { _loadingMessage = "AI가 답변을 생각 중입니다..."; }
    });
    
    // ✅ .env 파일에서 API URL 불러오기
    final apiUrl = dotenv.env['API_GATEWAY_URL']!;
    String completionData = '';

    try {
      final Map<String, dynamic> requestBody = {
        'prompt': text,
        'sessionId': _sessionId,
      };

      if (widget.drugInfo != null) {
        requestBody['drugName'] = widget.drugInfo!.itemName;
      }
      
      // API 원본 데이터가 있다면 'fullApiContext' 키로 함께 전송
      if (_rawApiData != null) {
        requestBody['fullApiContext'] = _rawApiData;
      }

      if (isSecondRequest) {
        requestBody['isFollowUp'] = true;
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseBody = json.decode(utf8.decode(response.bodyBytes));
        String content = '죄송합니다. 답변을 이해할 수 없습니다.';
        try {
          if (responseBody is List && responseBody.isNotEmpty) {
            completionData = responseBody[0] as String;
          } else {
            completionData = '예상치 못한 답변 형식입니다: $responseBody';
          }
          final actionData = json.decode(completionData);
          if (actionData['action'] == 'CHECK_MEDICATION_RECORD') {
            await _handleCheckRecordAction();
            return;
          }
        } catch (e) {
          content = completionData;
        }
        _addMessage(content, isUser: false);
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        _addMessage('오류가 발생했습니다. (상태 코드: ${response.statusCode})\n응답: $errorBody', isUser: false);
      }
    } catch (e) {
      _addMessage('API 호출 중 오류가 발생했습니다: $e', isUser: false);
    } finally {
      if (mounted) {
        if (!completionData.contains('CHECK_MEDICATION_RECORD')) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  // --- 이하 코드는 기존과 동일 ---

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(
        onResult: (result) => setState(() { _textController.text = result.recognizedWords; }),
        localeId: 'ko_KR');
    setState(() { _isListening = true; });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() { _isListening = false; });
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
    Timer(const Duration(milliseconds: 100), () => _scrollController.jumpTo(0));
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

  void _onComposerChanged() => setState(() {});

  @override
  void dispose() {
    _composerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: TitleHeader(
            title: widget.drugInfo != null
                ? RichText(
                    text: TextSpan(children: [
                    const TextSpan(text: 'AI 상담: ', style: TextStyle(color: Color(0xFF5B32F4), fontSize: 24, fontWeight: FontWeight.w700)),
                    TextSpan(text: widget.drugInfo!.itemName, style: const TextStyle(color: Color(0xFF5B32F4), fontSize: 16, fontWeight: FontWeight.w700)),
                  ]))
                : const Text('AI 상담', style: TextStyle(color: Color(0xFF5B32F4), fontSize: 32, fontWeight: FontWeight.w700)),
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xff5B32F4)), onPressed: () => Navigator.of(context).pop()),
            actions: [
              IconButton(onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeScreen()), (Route<dynamic> route) => false),
                  icon: SvgPicture.asset('assets/images/icon-home-disable.svg')),
            ]),
        body: Column(children: [
          Expanded(child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (_, int index) => _buildChatBubble(_messages[index]))),
          if (_isLoading)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text(_loadingMessage, style: TextStyle(color: Colors.grey[600])),
                ])),
          _buildMessageComposer(),
        ]));
  }

  Widget _buildChatBubble(ChatMessage message) {
    final isUser = message.isUser;
    final bg = isUser ? const Color(0xFF5B32F4) : const Color(0xFFF6F6FA);
    final fg = isUser ? Colors.white : const Color(0xFF222222);
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Column(crossAxisAlignment: align, children: [
          ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                          bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16))),
                  child: SelectableText(message.text, style: TextStyle(color: fg, fontSize: 18, height: 1.1)))),
        ]));
  }

  Widget _buildMessageComposer() {
    final bool hasText = _textController.text.trim().isNotEmpty;
    final bool showSend = _composerFocusNode.hasFocus || hasText;
    return Material(
        color: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(8.0), topRight: Radius.circular(8.0)),
            side: BorderSide(color: Color(0xFF8E8E93), width: 1)),
        child: Container(
            decoration: const BoxDecoration(
                color: Color(0xFFF7F7FA),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(8.0), topRight: Radius.circular(8.0))),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SafeArea(
                top: false,
                child: Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _textController,
                          focusNode: _composerFocusNode,
                          minLines: 1,
                          maxLines: 4,
                          onSubmitted: _isLoading ? null : _handleSubmitted,
                          decoration: const InputDecoration.collapsed(
                              hintText: '질문을 입력하거나 마이크를 누르세요',
                              hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 18, height: 1.1)),
                          style: const TextStyle(fontSize: 18))),
                  AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                      child: showSend
                          ? IconButton(
                              key: const ValueKey('send'),
                              icon: const Icon(Icons.send),
                              iconSize: 24,
                              color: const Color(0xff5B32F4),
                              onPressed: _isLoading ? null : () => _handleSubmitted(_textController.text))
                          : IconButton(
                              key: const ValueKey('mic'),
                              icon: Icon(_isListening ? Icons.stop_circle_outlined : Icons.mic),
                              iconSize: 24,
                              color: _isListening ? Colors.redAccent : const Color(0xff5B32F4),
                              onPressed: _isLoading || !_speechEnabled ? null : _handleMicButtonPressed))
                ]))));
  }
}