import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/transaction_record.dart';

/// AI Chat Service that integrates with Google Gemini API.
/// Users provide their own API key in settings.
class AiChatService {
  AiChatService._();

  static final AiChatService instance = AiChatService._();

  static const String _apiKeyKey = 'ai_gemini_api_key_v1';
  static const String _historyKey = 'ai_chat_history_v1';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  String _apiKey = '';
  List<ChatMessage> _history = [];
  bool _loaded = false;

  bool get isConfigured => _apiKey.isNotEmpty;
  List<ChatMessage> get history => List.unmodifiable(_history);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_apiKeyKey) ?? '';
    _loadHistory(prefs);
    _loaded = true;
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_apiKey.isEmpty) {
      await prefs.remove(_apiKeyKey);
    } else {
      await prefs.setString(_apiKeyKey, _apiKey);
    }
  }

  Future<String> getApiKey() async {
    await ensureLoaded();
    return _apiKey;
  }

  /// Build a financial context summary for the AI prompt.
  String buildFinancialContext({
    required List<TransactionRecord> transactions,
    required int totalBalance,
    required String currencySymbol,
    required String languageCode,
  }) {
    final now = DateTime.now();
    final thisMonth = transactions.where((tx) =>
        tx.transactionDate.month == now.month &&
        tx.transactionDate.year == now.year);

    final income = thisMonth
        .where((tx) => !tx.isExpense && tx.category != 'transfer_in')
        .fold<int>(0, (s, tx) => s + tx.amount);
    final expense = thisMonth
        .where((tx) => tx.isExpense && tx.category != 'transfer_out')
        .fold<int>(0, (s, tx) => s + tx.amount);

    final categoryExpense = <String, int>{};
    for (final tx in thisMonth.where((tx) =>
        tx.isExpense && tx.category != 'transfer_out')) {
      categoryExpense[tx.category] =
          (categoryExpense[tx.category] ?? 0) + tx.amount;
    }
    final topCategories = categoryExpense.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final txCount = thisMonth.length;
    final net = income - expense;
    final savingRate = income > 0 ? ((net / income) * 100).round() : 0;

    final buf = StringBuffer();
    buf.writeln('=== USER FINANCIAL CONTEXT ===');
    buf.writeln('Current balance: $currencySymbol $totalBalance');
    buf.writeln('This month income: $currencySymbol $income');
    buf.writeln('This month expense: $currencySymbol $expense');
    buf.writeln('Net this month: $currencySymbol $net');
    buf.writeln('Saving rate: $savingRate%');
    buf.writeln('Transaction count this month: $txCount');
    buf.writeln('Top expense categories:');
    for (final entry in topCategories.take(5)) {
      buf.writeln('  - ${entry.key}: $currencySymbol ${entry.value}');
    }
    buf.writeln('Total transactions all-time: ${transactions.length}');
    buf.writeln('Date: ${now.day}/${now.month}/${now.year}');
    buf.writeln('Language preference: ${languageCode == 'en' ? 'English' : 'Indonesian'}');
    buf.writeln('===');

    return buf.toString();
  }

  /// Send a message to Gemini and get a response.
  Future<String> chat({
    required String userMessage,
    required String financialContext,
    required String languageCode,
  }) async {
    if (!isConfigured) {
      return languageCode == 'en'
          ? 'Please set your Gemini API key in Settings → AI Assistant to use this feature.'
          : 'Silakan atur API key Gemini di Pengaturan → Asisten AI untuk menggunakan fitur ini.';
    }

    // Add user message to history
    _history.add(ChatMessage(
      role: ChatRole.user,
      content: userMessage,
      timestamp: DateTime.now(),
    ));

    try {
      final systemPrompt = _buildSystemPrompt(languageCode, financialContext);
      final response = await _callGemini(systemPrompt, userMessage);

      _history.add(ChatMessage(
        role: ChatRole.assistant,
        content: response,
        timestamp: DateTime.now(),
      ));

      await _saveHistory();
      return response;
    } catch (e) {
      final errorMsg = languageCode == 'en'
          ? 'Sorry, I couldn\'t process your request. Error: ${e.toString().length > 100 ? e.toString().substring(0, 100) : e}'
          : 'Maaf, saya tidak bisa memproses permintaan. Error: ${e.toString().length > 100 ? e.toString().substring(0, 100) : e}';

      _history.add(ChatMessage(
        role: ChatRole.assistant,
        content: errorMsg,
        timestamp: DateTime.now(),
      ));
      await _saveHistory();
      return errorMsg;
    }
  }

  String _buildSystemPrompt(String languageCode, String financialContext) {
    final lang = languageCode == 'en' ? 'English' : 'Indonesian (Bahasa Indonesia)';
    return '''You are CatatUang AI, a friendly and knowledgeable personal finance assistant built into the CatatUang app.

Your role:
- Answer financial questions based on the user's actual transaction data
- Give practical, actionable advice for budgeting and saving
- Analyze spending patterns and suggest improvements
- Be encouraging and supportive, never judgmental
- Keep responses concise (2-4 paragraphs max)
- Always respond in $lang

$financialContext

Rules:
- Never make up data not in the context
- If you don't have enough data, say so honestly
- Focus on practical tips, not generic advice
- Use the actual numbers from the context when relevant
- Don't recommend specific financial products or investments
- Be warm and conversational, like a helpful friend
''';
  }

  Future<String> _callGemini(String systemPrompt, String userMessage) async {
    final url = Uri.parse('$_baseUrl?key=$_apiKey');

    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': '$systemPrompt\n\nUser question: $userMessage'},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topP': 0.95,
        'topK': 40,
        'maxOutputTokens': 1024,
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
      ],
    });

    final httpClient = _SimpleHttpClient();
    final response = await httpClient.post(url, body);

    if (response.statusCode != 200) {
      throw Exception('Gemini API error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Empty response from Gemini');
    }

    return (parts[0]['text'] as String?) ?? 'No response';
  }

  void clearHistory() {
    _history.clear();
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_historyKey);
    });
  }

  void _loadHistory(SharedPreferences prefs) {
    final raw = prefs.getStringList(_historyKey) ?? [];
    _history = raw.map((json) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return ChatMessage(
          role: map['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
          content: map['content'] as String? ?? '',
          timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
              DateTime.now(),
        );
      } catch (_) {
        return ChatMessage(
          role: ChatRole.assistant,
          content: '',
          timestamp: DateTime.now(),
        );
      }
    }).where((m) => m.content.isNotEmpty).toList();

    // Keep max 50 messages
    if (_history.length > 50) {
      _history = _history.sublist(_history.length - 50);
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final limited = _history.length > 50
        ? _history.sublist(_history.length - 50)
        : _history;
    final raw = limited.map((m) => jsonEncode({
          'role': m.role == ChatRole.user ? 'user' : 'assistant',
          'content': m.content,
          'timestamp': m.timestamp.toIso8601String(),
        })).toList();
    await prefs.setStringList(_historyKey, raw);
  }
}

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final ChatRole role;
  final String content;
  final DateTime timestamp;
}

/// Minimal HTTP client using dart:io HttpClient
class _SimpleHttpClient {
  Future<_HttpResponse> post(Uri url, String body) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(url);
      request.headers.set('Content-Type', 'application/json');
      request.write(body);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      return _HttpResponse(response.statusCode, responseBody);
    } finally {
      client.close();
    }
  }
}

class _HttpResponse {
  const _HttpResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}
