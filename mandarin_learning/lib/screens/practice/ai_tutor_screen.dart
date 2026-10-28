import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/ai_tutor_service.dart';
import '../../services/audio_service.dart';
import '../../services/supabase_service.dart';
import '../../providers/auth_provider.dart';

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

  final List<String> _quickSuggestions = [
    '💡 Perbedaan 的, 得, 地',
    '🎯 Cara bedakan Nada 2 & 3',
    '⚖️ Kapan pakai 不 vs 没?',
    '🍜 Percakapan pesan makanan',
    '🗣️ Perbedaan 想 vs 要',
    '✨ Perbedaan 能, 会, 可以',
    '📝 Struktur kalimat dasar',
    '🧠 Tips menghafal Hanzi',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_welcomeMessage());
  }

  AiChatMessage _welcomeMessage() => AiChatMessage(
        text: 'Halo! Aku LingLing (玲玲), AI Tutor Mandarin pribadimu 🐼.\n\n'
            'Kamu bisa menanyakan apa saja seputar kosakata Mandarin, tata bahasa (grammar), pelafalan nada, hingga latihan percakapan sehari-hari!',
        isUser: false,
        timestamp: DateTime.now(),
        mode: AiTutorMode.appApi,
        modelBadge: 'LingLing (玲玲) • AI Tutor',
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
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Masuk ke akun untuk menyimpan dan melihat riwayat percakapan.')),
            ],
          ),
          backgroundColor: const Color(0xFF334155),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    try {
      final rows = await SupabaseService.instance.fetchAiConversations(userId);
      if (!mounted) return;
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.65,
              child: Column(
                children: [
                  // Grab handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, color: Color(0xFFE0533C), size: 22),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Riwayat Percakapan',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _startNewConversation();
                          },
                          icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFFE0533C)),
                          label: const Text(
                            'Baru',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0533C)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFEFE8E1)),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/image/beranda/maskot_02_baca_buku.png',
                                    width: 64,
                                    height: 64,
                                    errorBuilder: (context, error, stackTrace) => const Text('🐼', style: TextStyle(fontSize: 40)),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Belum ada percakapan tersimpan.',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Mulai tanyakan materi Mandarin apa saja!',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, _) => const Divider(height: 1, indent: 68, color: Color(0xFFF8F5F2)),
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              final messages = row['messages'] as List? ?? const [];
                              final lastText = messages.isEmpty ? '' : (messages.last as Map)['text']?.toString() ?? '';
                              return ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1EE),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFFD5CC)),
                                  ),
                                  child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFE0533C), size: 20),
                                ),
                                title: Text(
                                  row['title']?.toString() ?? 'Percakapan',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                                ),
                                subtitle: Text(
                                  lastText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                                onTap: () => Navigator.pop(sheetContext, row),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (selected != null && mounted) _openConversation(selected);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Riwayat belum dapat dimuat: $error')),
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
        modelBadge: isUser ? null : 'LingLing (玲玲) • AI Tutor',
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
        .where((message) => !message.text.startsWith('Halo! Aku'))
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
              !message.text.startsWith('Halo! Aku') &&
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
          modelBadge: 'LingLing (玲玲) • AI Tutor',
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

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F4),
      body: Stack(
        children: [
          // Latar belakang panorama Paviliun Danau Tiongkok klasik
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 145,
            child: Opacity(
              opacity: 0.18,
              child: Image.asset(
                'assets/image/background/02_chinese_lake_garden.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),
          // Lapisan gradasi halus di atas banner pemandangan
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 145,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFAF7F4).withValues(alpha: 0.45),
                    const Color(0xFFFAF7F4).withValues(alpha: 0.85),
                    const Color(0xFFFAF7F4),
                  ],
                ),
              ),
            ),
          ),
          // Aksen awan tradisional di sudut kanan atas
          Positioned(
            top: 25,
            right: -15,
            child: Opacity(
              opacity: 0.35,
              child: Image.asset(
                'assets/image/beranda/awan_kecil.png',
                width: 72,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),
          // Aksen kilau halus
          Positioned(
            top: 52,
            left: 28,
            child: Opacity(
              opacity: 0.35,
              child: Image.asset(
                'assets/image/beranda/kilau_01.png',
                width: 18,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildQuickSuggestions(),
                Expanded(child: _buildMessagesList()),
                if (_isGenerating) _buildGeneratingIndicator(),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEFE8E1), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Tombol Kembali
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEFE8E1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF334155),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Avatar Tutor LingLing & Indikator Status
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1EE),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD5CC), width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE0533C).withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/image/beranda/maskot_02_baca_buku.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Text('🐼', style: TextStyle(fontSize: 22)),
                  ),
                ),
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Info Tutor
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'LingLing (玲玲)',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1EE),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFD5CC)),
                      ),
                      child: const Text(
                        'AI TUTOR',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE0533C),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Row(
                  children: [
                    Icon(Icons.circle, size: 7, color: Color(0xFFF59E0B)),
                    SizedBox(width: 4),
                    Text(
                      'Tutor Mandarin Aktif • Siap Membantu 🌸',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tombol Obrolan Baru
          IconButton(
            tooltip: 'Percakapan baru',
            onPressed: _startNewConversation,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEFE8E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.add_comment_rounded, size: 18, color: Color(0xFFE0533C)),
            ),
          ),

          // Tombol Riwayat
          IconButton(
            tooltip: 'Riwayat percakapan',
            onPressed: _showConversationHistory,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEFE8E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.history_rounded, size: 18, color: Color(0xFFE0533C)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _quickSuggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final suggestion = _quickSuggestions[index];
          return GestureDetector(
            onTap: () => _sendMessage(suggestion.replaceAll(RegExp(r'^[^\w\s]+\s*'), '')),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFD5CC)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE0533C).withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  suggestion,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFFF1EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD5CC)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0533C).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Mascot Semangat + Nihao bubble
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Image.asset(
                        'assets/image/beranda/maskot_03_semangat.png',
                        width: 70,
                        height: 70,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Text('🐼', style: TextStyle(fontSize: 48)),
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Image.asset(
                        'assets/image/beranda/bubel_nihao.png',
                        width: 38,
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '你好! Ni Hao!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFC53030),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text('✨', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Aku LingLing, tutor pribadimu. Siap membimbingmu belajar kosakata, tata bahasa, dan percakapan Mandarin!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Feature pills in welcome banner
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildFeatureTag('📖 Kosakata HSK', const Color(0xFFE0533C)),
              _buildFeatureTag('⚖️ Tata Bahasa', const Color(0xFFD97706)),
              _buildFeatureTag('🗣️ Pelafalan Nada', const Color(0xFFEA580C)),
              _buildFeatureTag('🍜 Percakapan', const Color(0xFFB91C1C)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    final showWelcomeBanner = _messages.length <= 1;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: _messages.length + (showWelcomeBanner ? 1 : 0),
      itemBuilder: (context, index) {
        if (showWelcomeBanner && index == 0) {
          return _buildWelcomeBanner();
        }
        final msg = _messages[showWelcomeBanner ? index - 1 : index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildGeneratingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1EE),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD5CC)),
            ),
            child: Center(
              child: Image.asset(
                'assets/image/beranda/maskot_04_lup.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Text('🐼', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: const Color(0xFFFFD5CC)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE0533C).withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFE0533C),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'LingLing (玲玲) sedang merangkai penjelasan...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg) {
    final timeStr = _formatTime(msg.timestamp);

    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE0533C), Color(0xFFC53030)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x28E0533C),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  msg.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                timeStr,
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    // Balasan AI Tutor (LingLing)
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 36),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1EE),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD5CC)),
              ),
              child: Center(
                child: Image.asset(
                  'assets/image/beranda/maskot_02_baca_buku.png',
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Text('🐼', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(color: const Color(0xFFEFE8E1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header balasan: Model badge & tombol salin
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1EE),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFFD5CC)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.psychology_rounded, size: 12, color: Color(0xFFE0533C)),
                                  const SizedBox(width: 4),
                                  Text(
                                    msg.modelBadge ?? 'LingLing (玲玲) • AI Tutor',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFC53030),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: msg.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Teks disalin ke papan klip!'),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF7F4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Teks Penjelasan AI
                        SelectableText(
                          msg.text,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 14,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        // Tombol Audio TTS jika terdapat teks Mandarin
                        if (msg.audioText?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              final mandarinText = msg.audioText ?? '';
                              if (mandarinText.isNotEmpty) {
                                AudioService.instance.speak(mandarinText);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFED7AA)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.volume_up_rounded,
                                    size: 16,
                                    color: Color(0xFFEA580C),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Dengarkan Pelafalan Mandarin',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF9A3412),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      timeStr,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
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

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEFE8E1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFEFE8E1)),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 14),
                    child: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      decoration: const InputDecoration(
                        hintText: 'Tanyakan kosakata, grammar, atau hanzi...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_textController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() => _textController.clear());
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isGenerating ? null : () => _sendMessage(_textController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE0533C), Color(0xFFC53030)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE0533C).withValues(alpha: 0.32),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
