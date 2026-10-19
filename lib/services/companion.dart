import 'dart:convert';
import 'dart:io';

import '../data/store.dart';

/// The study companion ships switched off. To turn it on:
///   1. set [companionEnabled] to true,
///   2. fill in an OpenAI-compatible base URL, key and model below (or point
///      them at your own proxy),
///   3. rebuild. Nothing else in the app depends on it.
const companionEnabled = false;

const companionBaseUrl = 'https://api.openai.com/v1';
const companionApiKey = '';
const companionModel = 'gpt-4o-mini';

class CompanionMessage {
  const CompanionMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}

/// A careful study companion: it reads a little of the bundled library,
/// puts it in front of the model, and passes the answer back. It never gives
/// rulings; the system frame sends legal questions to a scholar.
class CompanionService {
  CompanionService(this._store);

  final AlimStore _store;

  static const _system = '''
You are Alim, a gentle study companion for a Muslim reader.
Speak warmly and briefly. Never issue fatwas and never give rulings on halal
or haram; for anything legal or personal, point to a qualified scholar.
Ground answers in the Qur'an and authentic hadith. When the app gives you
context passages, quote only from them and cite the references as given.
If the context does not cover the question, say so and answer cautiously from
well-known material, marking uncertainty. Close with one small, practical
suggestion when it fits.
''';

  Future<String> reply({
    required List<CompanionMessage> history,
    required String question,
  }) async {
    if (!companionEnabled) {
      throw StateError('The companion is switched off.');
    }
    if (companionApiKey.isEmpty) {
      throw StateError('No companion key is set.');
    }
    final context = await _context(question);
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('$companionBaseUrl/chat/completions'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $companionApiKey');
      request.write(jsonEncode({
        'model': companionModel,
        'temperature': 0.4,
        'max_tokens': 500,
        'messages': [
          {
            'role': 'system',
            'content': context.isEmpty
                ? _system
                : '$_system\n\nContext from the reader\'s library:\n$context',
          },
          for (final m in history.take(12))
            {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
          {'role': 'user', 'content': question},
        ],
      }));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Companion error ${response.statusCode}');
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final choices = data['choices'];
      String? message;
      if (choices is List && choices.isNotEmpty && choices.first is Map) {
        final inner = (choices.first as Map)['message'];
        if (inner is Map && inner['content'] is String) {
          message = inner['content'] as String;
        }
      }
      if (message == null || message.trim().isEmpty) {
        throw const HttpException('The companion returned nothing.');
      }
      return message.trim();
    } finally {
      client.close(force: true);
    }
  }

  /// A handful of passages that share words with the question.
  Future<String> _context(String question) async {
    final q = question.trim();
    if (q.length < 3) return '';
    final ayat = await _store.searchAyat(q, limit: 3);
    final hadith = await _store.searchHadith(q, limit: 3);
    final lines = <String>[];
    for (final a in ayat) {
      lines.add(
        'Qur\'an ${a.surah}:${a.ayah}: ${a.textEn}',
      );
    }
    for (final h in hadith) {
      lines.add(
        '${_collectionName(h.collection)} no. ${h.numberInBook}: ${h.textEn}',
      );
    }
    return lines.join('\n');
  }

  String _collectionName(String id) => switch (id) {
        'bukhari' => 'Sahih al-Bukhari',
        'muslim' => 'Sahih Muslim',
        'nawawi' => 'Forty Hadith of an-Nawawi',
        'qudsi' => 'Forty Hadith Qudsi',
        _ => id,
      };
}
