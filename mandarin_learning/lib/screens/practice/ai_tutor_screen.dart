import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../services/ai_tutor_service.dart';
import '../../services/audio_service.dart';
import '../../services/supabase_service.dart';
import '../../providers/auth_provider.dart';
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
  String? _activeConversationId;

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
    _messages.add(_welcomeMessage());
  }

  AiChatMessage _welcomeMessage() => AiChatMessage(
        text: 'Halo! Aku Xiao Xiong, AI Tutor Mandarin pribadimu 🐼.\n\n'
            'Aku terhubung langsung dengan database kosakata HSK 1-6 aplikasi ini. '
            'Tanyakan apa saja seputar kosakata Mandarin, tata bahasa, pelafalan nada, kuis, atau fitur aplikasi!',
        isUser: false,
        timestamp: DateTime.now(),
        mode: AiTutorMode.appApi,
        modelBadge: 'Xiao Xiong • Database Terhubung',
      );

  Future<void> _startNewConversation() async {
    if (_isGenerating) return;
    setState(() {
      _activeConversationId = null;
      _messages
        ..clear()
        ..add(_welcomeMessage());
    });
    _scrollToBottom();
  }

  Future<void> _showConversationHistory() async {
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masuk ke akun untuk menyimpan dan melihat riwayat percakapan.')),
      );
      return;
    }
    try {
      final rows = await SupabaseService.instance.fetchAiConversations(userId);
      if (!mounted) return;
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.7,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(children: [
                  const Expanded(child: Text('Percakapan sebelumnya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  TextButton.icon(onPressed: () { Navigator.pop(sheetContext); _startNewConversation(); }, icon: const Icon(Icons.add), label: const Text('Baru')),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('Belum ada percakapan tersimpan.'))
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final messages = row['messages'] as List? ?? const [];
                          final lastText = messages.isEmpty ? '' : (messages.last as Map)['text']?.toString() ?? '';
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
                            title: Text(row['title']?.toString() ?? 'Percakapan', maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(lastText, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => Navigator.pop(sheetContext, row),
                          );
                        },
                      ),
              ),
            ]),
          ),
        ),
      );
      if (selected != null && mounted) _openConversation(selected);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Riwayat belum dapat dimuat. Jalankan migrasi database terlebih dahulu. ($error)')),
      );
    }
  }

  void _openConversation(Map<String, dynamic> row) {
    final storedMessages = row['messages'] as List? ?? const [];
    final loaded = storedMessages.whereType<Map>().map((item) {
      final isUser = item['role'] == 'user';
      final text = item['text']?.toString() ?? '';
      final timestamp = DateTime.tryParse(item['timestamp']?.toString() ?? '') ?? DateTime.now();
      return AiChatMessage(
        text: text,
        isUser: isUser,
        timestamp: timestamp,
        mode: AiTutorMode.appApi,
        modelBadge: isUser ? null : 'Xiao Xiong • Database Terhubung',
        audioText: isUser ? null : AudioService.instance.extractMandarinText(text),
      );
    }).toList();
    setState(() {
      _activeConversationId = row['id'].toString();
      _messages
        ..clear()
        ..addAll(loaded);
    });
    _scrollToBottom();
  }

  Future<void> _persistConversation() async {
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId == null) return;
    final turns = _messages
        .where((message) => !message.text.startsWith('Halo! Aku Xiao Xiong'))
        .map((message) => <String, dynamic>{
              'role': message.isUser ? 'user' : 'assistant',
              'text': message.text,
              'timestamp': message.timestamp.toUtc().toIso8601String(),
            })
        .toList();
    if (turns.isEmpty) return;
    final firstPrompt = turns.first['text'] as String;
    final title = firstPrompt.length > 60 ? '${firstPrompt.substring(0, 57)}…' : firstPrompt;
    try {
      final id = await SupabaseService.instance.saveAiConversation(
        userId: userId,
        conversationId: _activeConversationId,
        title: title,
        messages: turns,
      );
      if (mounted) setState(() => _activeConversationId = id);
    } catch (error) {
      debugPrint('[AiTutorScreen] Gagal menyimpan riwayat chat: $error');
    }
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
    const currentMode = AiTutorMode.appApi;
    final history = _messages
        .where(
          (message) =>
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

    await _persistConversation();

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
          modelBadge: 'Xiao Xiong • Database Terhubung',
          audioText: AudioService.instance.extractMandarinText(response),
        ),
      );
    });

    await _persistConversation();

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
        actions: [
          IconButton(tooltip: 'Percakapan baru', onPressed: _startNewConversation, icon: const Icon(Icons.add_comment_outlined)),
          IconButton(tooltip: 'Riwayat percakapan', onPressed: _showConversationHistory, icon: const Icon(Icons.history_rounded)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status info: Satu AI Tutor yang terhubung ke Database
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: AppColors.primaryGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xiao Xiong AI Tutor',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Terhubung Database Kosakata HSK 1-6 • Khusus Mandarin',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: Color(0xFF15803D),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Database Aktif',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Xiao Xiong sedang mencari di database kosakata...',
                            style: TextStyle(
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
                        hintText: 'Tanyakan seputar kosakata atau materi Mandarin...',
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
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
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

    const badgeBg = Color(0xFFF0FDF4);
    const badgeText = Color(0xFF15803D);
    const badgeIcon = Icons.psychology_rounded;

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
                    if (msg.modelBadge != null || msg.mode != null) ...[
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
                              msg.modelBadge ?? 'Xiao Xiong • Database Terhubung',
                              style: const TextStyle(
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
