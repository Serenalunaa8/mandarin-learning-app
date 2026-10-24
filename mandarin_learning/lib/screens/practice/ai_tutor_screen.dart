import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/ai_tutor_service.dart';
import '../../services/audio_service.dart';
import '../../widgets/mascot_widget.dart';

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiChatMessage> _messages = [];
  bool _isGenerating = false;

  AiTutorMode _selectedMode = AiTutorMode.appApi;

  final List<String> _quickSuggestions = [
    'Perbedaan 的, 得, 地',
    'Cara membedakan Nada 2 dan Nada 3',
    'Kapan pakai 不 vs 没?',
    'Perbedaan 想 (xiǎng) vs 要 (yào)',
    'Perbedaan 能, 会, 可以',
    'Struktur kalimat dasar Mandarin',
    'Percakapan pesan makanan',
    'Tips menghafal Hanzi',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      AiChatMessage(
        text:
            'Halo! Aku Xiao Xiong, AI Tutor Mandarin pribadimu 🐼.\n\n'
            'Pilih AI Tutor + Supabase untuk belajar Mandarin dari database aplikasi, '
            'atau Gemini Murni untuk bertanya berbagai hal.',
        isUser: false,
        timestamp: DateTime.now(),
        mode: AiTutorMode.appApi,
        modelBadge: 'Xiao Xiong Assistant',
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isGenerating) return;

    _textController.clear();
    final currentMode = _selectedMode;
    final history = _messages
        .where(
          (message) =>
              message.mode == currentMode &&
              !message.text.startsWith('Halo! Aku Xiao Xiong') &&
              !message.text.startsWith('Belum bisa mendapat jawaban:'),
        )
        .toList()
        .reversed
        .take(8)
        .toList()
        .reversed
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'model',
            'text': message.text,
          },
        )
        .toList();
    setState(() {
      _messages.add(
        AiChatMessage(
          text: trimmed,
          isUser: true,
          timestamp: DateTime.now(),
          mode: currentMode,
        ),
      );
      _isGenerating = true;
    });

    _scrollToBottom();

    String response;
    try {
      response = await AiTutorService.instance.askAiTutor(
        trimmed,
        mode: currentMode,
        history: history,
      );
    } catch (error) {
      final detail = error.toString().replaceFirst('Bad state: ', '');
      response = 'Belum bisa mendapat jawaban: $detail';
    }

    if (!mounted) return;

    setState(() {
      _isGenerating = false;
      _messages.add(
        AiChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
          mode: currentMode,
          modelBadge: currentMode == AiTutorMode.appApi
              ? 'AI Tutor • API aplikasi + Supabase'
              : 'Gemini Murni • Tanpa konteks database',
          audioText: AudioService.instance.extractMandarinText(response),
        ),
      );
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotWidget(size: 30, pose: MascotPose.headOnly),
            SizedBox(width: 8),
            Text('AI Tutor Mandarin'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Dua mode: konteks aplikasi atau Gemini umum.
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      label: 'AI Tutor + Supabase',
                      icon: Icons.psychology_rounded,
                      selected: _selectedMode == AiTutorMode.appApi,
                      color: AppColors.primaryGreen,
                      onTap: () =>
                          setState(() => _selectedMode = AiTutorMode.appApi),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _ModeButton(
                      label: 'Gemini Murni',
                      icon: Icons.auto_awesome_rounded,
                      selected: _selectedMode == AiTutorMode.gemini,
                      color: const Color(0xFF2563EB),
                      onTap: () =>
                          setState(() => _selectedMode = AiTutorMode.gemini),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                _selectedMode == AiTutorMode.appApi
                    ? 'Tutor memakai referensi kosakata dari database Supabase.'
                    : 'Gemini menjawab berbagai topik tanpa konteks database.',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),

            // Quick suggestions horizontal chips
            Container(
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _quickSuggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final suggestion = _quickSuggestions[index];
                  return ActionChip(
                    label: Text(suggestion),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFBBF7D0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () => _sendMessage(suggestion),
                  );
                },
              ),
            ),

            // Message list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),

            // Generating indicator
            if (_isGenerating)
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 8),
                child: Row(
                  children: [
                    const MascotWidget(size: 26, pose: MascotPose.headOnly),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _selectedMode == AiTutorMode.appApi
                                  ? AppColors.primaryGreen
                                  : const Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedMode == AiTutorMode.appApi
                                ? 'AI sedang mencari konteks belajar...'
                                : 'Gemini sedang menyiapkan jawaban...',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Input field & Send button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: _selectedMode == AiTutorMode.appApi
                            ? 'Tanyakan tentang Mandarin...'
                            : 'Tanyakan langsung kepada Gemini...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _selectedMode == AiTutorMode.appApi
                          ? AppColors.primaryGreen
                          : const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => _sendMessage(_textController.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    final mode = msg.mode;
    final isGemini = mode == AiTutorMode.gemini;
    final badgeBg = isGemini
        ? const Color(0xFFEFF6FF)
        : const Color(0xFFF0FDF4);
    final badgeText = isGemini
        ? const Color(0xFF1D4ED8)
        : const Color(0xFF15803D);
    final badgeIcon = isGemini
        ? Icons.auto_awesome_rounded
        : Icons.psychology_rounded;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 36),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MascotWidget(size: 34, pose: MascotPose.headOnly),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.modelBadge != null || mode != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: badgeText.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 13, color: badgeText),
                            const SizedBox(width: 5),
                            Text(
                              msg.modelBadge ??
                                  (isGemini
                                      ? 'Gemini Murni'
                                      : 'AI Tutor • API aplikasi + Supabase'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: badgeText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Text(
                      msg.text,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Action toolbar: Audio TTS if text contains Chinese
                    if (msg.audioText?.isNotEmpty ?? false)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final mandarinText = msg.audioText ?? '';
                              if (mandarinText.isNotEmpty) {
                                AudioService.instance.speak(mandarinText);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.volume_up_rounded,
                                    size: 16,
                                    color: AppColors.primaryDark,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Dengar',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : AppColors.textDark,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
