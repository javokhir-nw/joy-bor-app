import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/listing_card.dart';
import '../../../listings/presentation/listing_detail_screen.dart';

class AiSearchTab extends StatefulWidget {
  const AiSearchTab({super.key});
  @override
  State<AiSearchTab> createState() => _AiSearchTabState();
}

class _AiSearchTabState extends State<AiSearchTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];
  final List<Map<String, dynamic>> _messages = [];
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('gemini')
          .get();
      setState(() => _apiKey = doc['api_key'] ?? '');
    } catch (_) {}
  }

  static const _systemPrompt = '''
Sen uy-joy qidiruv yordamchisisisan. Quyidagi QOIDA va KALIT SO'ZLARGA QAT'IY AMAL QIL:

CATEGORY ANIQLASH (faqat quyidagi so'zlar bo'lsa):
- "kvartira", "apartment", "daire" → category: "Kvartira"
- "uy", "house", "cottage", "dom", "hovli" → category: "Uy"
- "xona", "room", "komnata" → category: "Xona"
- "ofis", "office" → category: "Ofis"
- "yer", "участок", "land" → category: "Yer"
- Agar yuqoridagi so'zlardan HECH BIRI bo'lmasa → category: null

MUHIM: "uy" va "kvartira" TURLI category. "uy" desa faqat category:"Uy". "kvartira" desa faqat category:"Kvartira". Aralashtirma.

XONALAR: "N xonali" → minRooms:N, maxRooms:N

NARX: "million", "mln" → UZS. "\$", "dollar" → USD. "gacha" → maxPrice. "dan" → minPrice.

IJARA MUDDATI: "kunlik" | "oylik" | "yillik". Aytilmasa → null.

reply qisqa va o'zbek tilida yoz. Hech qachon "topilmadi" yozma.

Faqat sof JSON qaytar, markdown yoki izoh yozma:
{"reply":"string","filters":{"category":"Kvartira|Uy|Xona|Ofis|Yer|null","minPrice":null,"maxPrice":null,"currency":"USD|UZS|null","minRooms":null,"maxRooms":null,"period":"kunlik|oylik|yillik|null","address":null}}
''';

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _loading = true;
      _results = [];
    });
    _controller.clear();
    _scrollDown();

    try {
      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            ..._messages.map((m) => {
                  'role': m['role'] == 'user' ? 'user' : 'assistant',
                  'content': m['text'],
                }),
          ],
          'max_tokens': 300,
          'temperature': 0.1,
        }),
      );

      final raw = jsonDecode(res.body);
      String aiText =
          raw['choices'][0]['message']['content'] as String? ?? '';

      // JSON tozalash
      aiText = aiText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      // JSON boshlanish va tugash joyini topish
      final jsonStart = aiText.indexOf('{');
      final jsonEnd = aiText.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('JSON topilmadi');
      }
      aiText = aiText.substring(jsonStart, jsonEnd + 1);

      final parsed = jsonDecode(aiText) as Map<String, dynamic>;
      final reply = parsed['reply'] as String? ?? '...';
      final filters =
          parsed['filters'] as Map<String, dynamic>? ?? {};

      setState(() => _messages.add({'role': 'ai', 'text': reply}));
      await _queryListings(filters);
    } catch (e) {
      setState(() => _messages
          .add({'role': 'ai', 'text': 'Xato yuz berdi, qayta urinib ko\'ring'}));
    } finally {
      setState(() => _loading = false);
      _scrollDown();
    }
  }

  Future<void> _queryListings(Map<String, dynamic> f) async {
    Query q = FirebaseFirestore.instance
        .collection('listings')
        .where('isActive', isEqualTo: true);

    if (f['category'] != null && f['category'] != 'null') {
      q = q.where('category', isEqualTo: f['category']);
    }
    if (f['period'] != null && f['period'] != 'null') {
      q = q.where('period', isEqualTo: f['period']);
    }
    if (f['currency'] != null && f['currency'] != 'null') {
      q = q.where('currency', isEqualTo: f['currency']);
    }

    final snap = await q.limit(20).get();
    var docs = snap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .toList();

    // Client-side filterlar
    if (f['minPrice'] != null) {
      docs = docs
          .where((d) => (d['price'] ?? 0) >= f['minPrice'])
          .toList();
    }
    if (f['maxPrice'] != null) {
      docs = docs
          .where((d) => (d['price'] ?? 0) <= f['maxPrice'])
          .toList();
    }
    if (f['minRooms'] != null) {
      docs = docs
          .where((d) => (d['rooms'] ?? 0) >= f['minRooms'])
          .toList();
    }
    if (f['maxRooms'] != null) {
      docs = docs
          .where((d) => (d['rooms'] ?? 0) <= f['maxRooms'])
          .toList();
    }
    if (f['address'] != null && f['address'] != 'null') {
      final addr = (f['address'] as String).toLowerCase();
      docs = docs
          .where((d) =>
              (d['address'] ?? '').toString().toLowerCase().contains(addr))
          .toList();
    }

    setState(() => _results = docs);
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 300), () {
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
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            if (_messages.isEmpty) _buildWelcome(),
            ..._messages.map(_buildMessage),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary)),
              ),
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text("${_results.length} ta e'lon topildi",
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              ..._results.map((data) => GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ListingDetailScreen(data: data))),
                    child: ListingCard(data: data),
                  )),
            ],
          ],
        ),
      ),
      _buildInput(),
    ]);
  }

  Widget _buildWelcome() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary]),
            borderRadius: BorderRadius.circular(20),
          ),
          child:
              const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 16),
        const Text('AI Qidiruv',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Xohishingizni yozing, men topaman!',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip("2 xonali kvartira, 500\$ gacha"),
          _chip("Chilonzorda uy ijarasi"),
          _chip("Ofis, oylik, arzon"),
        ]),
      ]),
    );
  }

  Widget _chip(String text) => GestureDetector(
        onTap: () {
          _controller.text = text;
          _send();
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(text,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ),
      );

  Widget _buildMessage(Map<String, dynamic> m) {
    final isUser = m['role'] == 'user';
    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(m['text'],
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14)),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border:
            Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Xohishingizni yozing...',
              hintStyle:
                  const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _loading ? null : _send,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}