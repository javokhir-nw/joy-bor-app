import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class ModerationService {
  static Future<void> analyze({
    required String docId,
    required String title,
    required String description,
    required int price,
    required String currency,
  }) async {
    try {
      // API kalitni Firestore dan olish
      final configDoc = await FirebaseFirestore.instance
          .collection('config')
          .doc('groq')
          .get();

      final apiKey = configDoc.data()?['api_key'] ?? '';
      if (apiKey.isEmpty) return;

      final prompt = '''
Bu ilova FAQAT uy-joy ijarasi va sotuviga mo'ljallangan. E'lonni tahlil qil va faqat JSON qaytар.

Sarlavha: $title
Tavsif: ${description.isEmpty ? '(kiritilmagan)' : description}
Narx: $price $currency

JSON format:
{
  "riskLevel": "clean | low_risk | medium_risk | high_risk",
  "reason": "aniq sabab, faqat bu e'longa tegishli (max 80 belgi)",
  "issues": ["faqat e'londa HAQIQATAN mavjud muammolar"]
}

MUHIM: issues massiviga faqat e'londa haqiqatan mavjud bo'lgan muammolarni yoz. Yo'q muammoni yozma.

riskLevel qoidalari:
- high_risk: (1) uy-joy emas (bilet, mashina, kiyim, ovqat va boshqa tovarlar), YOKI (2) haqorat/so'kish bor, YOKI (3) qurol/xavfli buyum, YOKI (4) firibgarlik (avans, oldindan to'lov)
- medium_risk: uy-joy, lekin narx g'ayritabiiy yoki tavsif bo'sh/noaniq
- low_risk: uy-joy e'loni, kichik kamchilik bor
- clean: to'liq uy-joy e'loni, muammo yo'q

Misol 1 — "kinoga bilet": riskLevel=high_risk, reason="Uy-joy emas, bilet sotilmoqda", issues=["uy-joy emas"]
Misol 2 — "kvartira ijara 500usd": riskLevel=clean, reason="To'g'ri uy-joy e'loni", issues=[]
''';

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {
              'role': 'system',
              'content':
                  'Faqat sof JSON qaytар. Hech qanday izoh, markdown yoki qo\'shimcha matn yozma.'
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 200,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode != 200) return;

      final raw = jsonDecode(response.body);
      final content =
          raw['choices'][0]['message']['content'] as String? ?? '';

      // JSON tozalash (ba'zan model ```json ... ``` qo'shib yuboradi)
      final cleaned = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final aiResult = jsonDecode(cleaned) as Map<String, dynamic>;
      final riskLevel = aiResult['riskLevel'] ?? 'medium_risk';

      await FirebaseFirestore.instance
          .collection('listings')
          .doc(docId)
          .update({
        'riskLevel': riskLevel,
        'aiAnalysis': {
          'riskLevel': riskLevel,
          'reason': aiResult['reason'] ?? '',
          'issues': aiResult['issues'] ?? [],
          'analyzedAt': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      // AI xato bersa moderationStatus pending qoladi, admin baribir ko'radi
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(docId)
          .update({
        'riskLevel': 'medium_risk',
        'aiAnalysis': {
          'riskLevel': 'medium_risk',
          'reason': 'AI tahlil xatosi, qo\'lda tekshiring',
          'issues': [],
          'analyzedAt': FieldValue.serverTimestamp(),
        },
      });
    }
  }
}