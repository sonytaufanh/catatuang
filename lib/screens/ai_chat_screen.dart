import 'package:flutter/material.dart';

import '../data/models/transaction_record.dart';
import '../data/transaction_store.dart';
import '../services/ai_chat_service.dart';
import '../services/app_animations.dart';
import '../services/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/master_data_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _loading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await AiChatService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() => _initialized = true);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    _controller.clear();
    setState(() => _loading = true);
    _scrollToBottom();

    final settings = AppSettingsScope.of(context);
    final transactions = transactionsNotifier.value;
    final totalBalance = MasterDataService.instance.openingBalanceTotal +
        _totalBalance(transactions);

    final context_ = AiChatService.instance.buildFinancialContext(
      transactions: transactions,
      totalBalance: totalBalance,
      currencySymbol: settings.currencySymbol,
      languageCode: settings.languageCode,
    );

    await AiChatService.instance.chat(
      userMessage: text,
      financialContext: context_,
      languageCode: settings.languageCode,
    );

    if (!mounted) return;
    setState(() => _loading = false);
    _scrollToBottom();
  }

  int _totalBalance(List<TransactionRecord> txs) {
    var total = 0;
    for (final tx in txs) {
      total += tx.isExpense ? -tx.amount : tx.amount;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final settings = AppSettingsScope.of(context);
    final messages = AiChatService.instance.history;
    final isConfigured = AiChatService.instance.isConfigured;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: AppUiTokens.brandGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppUiTokens.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(t.t('ai_assistant')),
          ],
        ),
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: t.t('clear_chat'),
              onPressed: () {
                AiChatService.instance.clearHistory();
                setState(() {});
              },
            ),
          IconButton(
            icon: const Icon(Icons.key_rounded),
            tooltip: 'API Key',
            onPressed: () => _showApiKeyDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Expanded chat area
          Expanded(
            child: !_initialized
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? _buildWelcomeState(t, settings, isConfigured)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemCount: messages.length + (_loading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length && _loading) {
                            return _buildTypingIndicator();
                          }
                          return _buildMessageBubble(
                            messages[index],
                            settings,
                          );
                        },
                      ),
          ),
          // Input area
          _buildInputArea(t, isConfigured),
        ],
      ),
    );
  }

  Widget _buildWelcomeState(
    AppLocalizations t,
    AppSettings settings,
    bool isConfigured,
  ) {
    final isEn = settings.languageCode == 'en';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppUiTokens.brandGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppUiTokens.brandBlue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppUiTokens.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isEn ? 'CatatUang AI Assistant' : 'Asisten AI CatatUang',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEn
                ? 'Ask me anything about your finances. I can analyze your spending, suggest budgets, and give personalized tips.'
                : 'Tanya apa saja tentang keuanganmu. Saya bisa analisis pengeluaran, sarankan anggaran, dan beri tips personal.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppUiTokens.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          if (!isConfigured)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppUiTokens.warningSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppUiTokens.warningSoftBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.key_rounded,
                    size: 18,
                    color: AppUiTokens.warningMedium,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEn
                          ? 'Set your Gemini API key to start chatting. Tap the key icon above.'
                          : 'Atur API key Gemini untuk mulai chat. Tap ikon kunci di atas.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppUiTokens.warningSoftText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text(
            isEn ? 'Try asking:' : 'Coba tanyakan:',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppUiTokens.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          ..._buildSuggestionChips(isEn),
        ],
      ),
    );
  }

  List<Widget> _buildSuggestionChips(bool isEn) {
    final suggestions = isEn
        ? [
            'How am I doing financially this month?',
            'Which category should I cut back on?',
            'Can I afford a big purchase of 2 million?',
            'Give me a weekly budget plan',
          ]
        : [
            'Bagaimana kondisi keuangan saya bulan ini?',
            'Kategori mana yang harus saya kurangi?',
            'Bisakah saya beli sesuatu seharga 2 juta?',
            'Buatkan rencana anggaran mingguan',
          ];

    return suggestions.map((text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: PressableScale(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _controller.text = text;
            _sendMessage();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppUiTokens.surfaceBlueSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppUiTokens.brandBlueBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 14,
                  color: AppUiTokens.brandBlueDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppUiTokens.brandBlueDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildMessageBubble(ChatMessage message, AppSettings settings) {
    final isUser = message.role == ChatRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: AppUiTokens.brandGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppUiTokens.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppUiTokens.brandBlue
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppUiTokens.borderSoft),
                boxShadow: [
                  BoxShadow(
                    color: AppUiTokens.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                message.content,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isUser
                      ? AppUiTokens.white
                      : AppUiTokens.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: AppUiTokens.brandGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppUiTokens.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppUiTokens.borderSoft),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppUiTokens.brandBlue.withValues(
              alpha: 0.3 + (0.7 * (1 - (value - value.floor()))),
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputArea(AppLocalizations t, bool isConfigured) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: AppUiTokens.borderSoft),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: isConfigured,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: isConfigured
                    ? t.t('ask_ai_hint')
                    : t.t('ai_key_required'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppUiTokens.surfaceMuted,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          PressableScale(
            borderRadius: BorderRadius.circular(999),
            onTap: _loading || !isConfigured ? null : _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: isConfigured && !_loading
                    ? AppUiTokens.brandGradient
                    : null,
                color: isConfigured && !_loading
                    ? null
                    : AppUiTokens.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                size: 18,
                color: isConfigured && !_loading
                    ? AppUiTokens.white
                    : AppUiTokens.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showApiKeyDialog() async {
    final settings = AppSettingsScope.of(context);
    final isEn = settings.languageCode == 'en';
    final currentKey = await AiChatService.instance.getApiKey();
    final keyController = TextEditingController(text: currentKey);

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: AppUiTokens.brandGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.key_rounded,
                        color: AppUiTokens.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEn ? 'Gemini API Key' : 'API Key Gemini',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isEn
                      ? 'Get your free API key from Google AI Studio (aistudio.google.com). The key stays on your device only.'
                      : 'Dapatkan API key gratis dari Google AI Studio (aistudio.google.com). Key hanya disimpan di perangkat kamu.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppUiTokens.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: keyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'AIzaSy...',
                    labelText: 'API Key',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(isEn ? 'Cancel' : 'Batal'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text(isEn ? 'Save' : 'Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != true) return;
    await AiChatService.instance.setApiKey(keyController.text.trim());
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
