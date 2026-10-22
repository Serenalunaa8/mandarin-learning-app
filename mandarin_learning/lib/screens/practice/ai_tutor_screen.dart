import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<AiProvider> _availableProviders = [];
  String? _providerStatusError;
  AiProvider _selectedProvider = AiProvider.gemini;

  final List<String> _quickSuggestions = [
    'Perbedaan 的, 得, 地',
    'Cara membedakan Nada 2 dan Nada 3',
    'Kapan pakai 不 vs 没?',
    'Percakapan pesan makanan',
    'Tips menghafal Hanzi',
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailableProviders();
    _messages.add(
      AiChatMessage(
        text:
            'Halo! Aku Xiao Xiong, AI Tutor Mandarin pribadimu 🐼. '
            'Ada topik tata bahasa atau kosakata yang ingin kamu tanyakan hari ini?',
        isUser: false,
        timestamp: DateTime.now(),
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

  Future<void> _loadAvailableProviders() async {
    if (mounted) {
      setState(() {
        _providerStatusError = null;
      });
    }
    try {
      final providers = await AiTutorService.instance.getAvailableProviders();
      final preferences = await SharedPreferences.getInstance();
      final selectedId = preferences.getString('ai_tutor_provider');
      if (!mounted) return;
      setState(() {
        _availableProviders = providers;
        if (providers.isNotEmpty) {
          _selectedProvider = providers.firstWhere(
            (provider) => provider.id == selectedId,
            orElse: () => providers.first,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _availableProviders = AiProvider.values;
      });
    }
  }

  Future<void> _selectProvider(AiProvider provider) async {
    setState(() => _selectedProvider = provider);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('ai_tutor_provider', provider.id);
  }

  Future<void> _showApiKeySettingsDialog() async {
    final geminiKey = await AiTutorService.instance.getApiKey(AiProvider.gemini) ?? '';
    final claudeKey = await AiTutorService.instance.getApiKey(AiProvider.anthropic) ?? '';
    final openAiKey = await AiTutorService.instance.getApiKey(AiProvider.openAi) ?? '';
    final groqKey = await AiTutorService.instance.getApiKey(AiProvider.groq) ?? '';

    final geminiController = TextEditingController(text: geminiKey);
    final claudeController = TextEditingController(text: claudeKey);
    final openAiController = TextEditingController(text: openAiKey);
    final groqController = TextEditingController(text: groqKey);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.key_rounded, color: AppColors.primaryGreen),
                        SizedBox(width: 8),
                        Text(
                          'Pengaturan API Key LLM',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Masukkan API Key milikmu untuk menghubungkan Claude, Gemini, OpenAI, atau Groq secara langsung tanpa batasan.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),

                // Gemini Field
                _buildApiKeyInput(
                  label: 'Google Gemini API Key',
                  controller: geminiController,
                  hint: 'AIzaSy...',
                  helper: 'Dapatkan gratis di aistudio.google.com',
                ),
                const SizedBox(height: 12),

                // Claude Field
                _buildApiKeyInput(
                  label: 'Anthropic Claude API Key',
                  controller: claudeController,
                  hint: 'sk-ant-api...',
                  helper: 'Dapatkan di console.anthropic.com',
                ),
                const SizedBox(height: 12),

                // OpenAI Field
                _buildApiKeyInput(
                  label: 'OpenAI GPT API Key',
                  controller: openAiController,
                  hint: 'sk-proj-...',
                  helper: 'Dapatkan di platform.openai.com',
                ),
                const SizedBox(height: 12),

                // Groq Field
                _buildApiKeyInput(
                  label: 'Groq API Key',
                  controller: groqController,
                  hint: 'gsk_...',
                  helper: 'Dapatkan gratis di console.groq.com',
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      await AiTutorService.instance.saveApiKey(
                        AiProvider.gemini,
                        geminiController.text,
                      );
                      await AiTutorService.instance.saveApiKey(
                        AiProvider.anthropic,
                        claudeController.text,
                      );
                      await AiTutorService.instance.saveApiKey(
                        AiProvider.openAi,
                        openAiController.text,
                      );
                      await AiTutorService.instance.saveApiKey(
                        AiProvider.groq,
                        groqController.text,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pengaturan API Key berhasil disimpan!'),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                        setState(() {});
                      }
                    },
                    child: const Text(
                      'Simpan Pengaturan API Key',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildApiKeyInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.black26),
            helperText: helper,
            helperStyle: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isGenerating) return;

    _textController.clear();
    final provider = _selectedProvider;
    setState(() {
      _messages.add(
        AiChatMessage(text: trimmed, isUser: true, timestamp: DateTime.now()),
      );
      _isGenerating = true;
    });

    _scrollToBottom();

    String response;
    try {
      response = await AiTutorService.instance.askAiTutor(
        trimmed,
        provider: provider,
      );
    } catch (error) {
      response =
          'Tidak dapat menghubungi ${provider.label}. Membuka panduan lokal Xiao Xiong:\n\n'
          'Detail error: $error';
    }

    if (!mounted) return;

    setState(() {
      _isGenerating = false;
      _messages.add(
        AiChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
          provider: provider,
          modelBadge: '${provider.label} • ${provider.model}',
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
        actions: [
          PopupMenuButton<AiProvider>(
            tooltip: 'Pilih model AI',
            initialValue: _selectedProvider,
            onSelected: _isGenerating ? null : _selectProvider,
            itemBuilder: (context) => [
              for (final provider in _availableProviders)
                PopupMenuItem(
                  value: provider,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            provider == _selectedProvider
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: provider == _selectedProvider
                                ? AppColors.primaryGreen
                                : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(provider.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 22),
                        child: Text(
                          provider.model,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primaryGreen),
                  const SizedBox(width: 4),
                  Text(
                    _selectedProvider.label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, size: 18),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Atur API Key LLM',
            icon: const Icon(Icons.vpn_key_rounded, color: AppColors.primaryDark),
            onPressed: _showApiKeySettingsDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quick suggestions horizontal chips
            Container(
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 6),
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

            if (_providerStatusError != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Kamu dapat menghubungkan API Key LLM sendiri atau menggunakan Xiao Xiong offline.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _showApiKeySettingsDialog,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Atur Key', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                    ),
                  ],
                ),
              ),

            // Message list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
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
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Tutor sedang mengetik...',
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
                        hintText: 'Tanyakan tata bahasa atau kosakata...',
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
                      color: AppColors.primary,
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
            color: AppColors.primary,
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
              height: 1.3,
            ),
          ),
        ),
      );
    }

    final provider = msg.provider;
    final Color badgeBg;
    final Color badgeText;
    final IconData badgeIcon;
    switch (provider) {
      case AiProvider.gemini:
        badgeBg = const Color(0xFFE0F2FE);
        badgeText = const Color(0xFF0369A1);
        badgeIcon = Icons.auto_awesome_rounded;
        break;
      case AiProvider.anthropic:
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFB45309);
        badgeIcon = Icons.psychology_rounded;
        break;
      case AiProvider.openAi:
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF15803D);
        badgeIcon = Icons.smart_toy_rounded;
        break;
      case AiProvider.groq:
        badgeBg = const Color(0xFFF3E8FF);
        badgeText = const Color(0xFF7E22CE);
        badgeIcon = Icons.bolt_rounded;
        break;
      case null:
        badgeBg = const Color(0xFFECFDF5);
        badgeText = const Color(0xFF047857);
        badgeIcon = Icons.support_agent_rounded;
        break;
    }

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
                    if (msg.modelBadge != null || provider != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: badgeText.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 12, color: badgeText),
                            const SizedBox(width: 4),
                            Text(
                              msg.modelBadge ?? provider?.label ?? 'Xiao Xiong',
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
                              // Ekstrak karakter mandarin atau baca jawaban
                              final mandarinText = msg.audioText ?? '';
                              if (mandarinText.isNotEmpty) {
                                AudioService.instance.speak(mandarinText);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
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
