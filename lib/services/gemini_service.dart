import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  late final GenerativeModel _model;
  
  // Cache in memoria per evitare di richiedere a Gemini traduzioni già fatte (risparmiamo rate limits e tempo!)
  final Map<String, String> _titleCache = {};
  final Map<String, String> _plotCache = {};

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Nessuna GEMINI_API_KEY trovata nel file .env');
    }
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );
  }

  /// Traduce e corregge i titoli e gli autori di una lista di libri (JSON).
  Future<List<dynamic>> translateSearchDocs(List<dynamic> docs) async {
    if (docs.isEmpty) return docs;

    // Raccogliamo solo i titoli da tradurre, controllando prima la cache
    final List<Map<String, dynamic>> toTranslate = [];
    final List<dynamic> translatedDocs = List.from(docs);

    for (int i = 0; i < docs.length; i++) {
      final book = docs[i];
      final title = book['title']?.toString() ?? '';
      final author = (book['author_name'] as List?)?.join(', ') ?? '';
      final key = '$title - $author';

      if (_titleCache.containsKey(key)) {
        // Usa la cache se l'abbiamo già tradotto!
        translatedDocs[i] = Map<String, dynamic>.from(book);
        translatedDocs[i]['title'] = _titleCache[key];
      } else if (title.isNotEmpty) {
        toTranslate.add({
          'index': i,
          'title': title,
          'author': author,
          'key': key,
        });
      }
    }

    if (toTranslate.isEmpty) {
      return translatedDocs; // Tutto era in cache!
    }

    // Costruiamo il prompt rigoroso
    final promptStr = """
You are a tool that translates book titles and authors into Italian. 
I will provide you with a list of books in JSON format, each with an "index", "title", and "author".
You must search online for the OFFICIAL ITALIAN title of each book. If an official Italian edition exists, return that title.
*rules*: 
- Return the list in JSON format where the "title" key contains the OFFICIAL ITALIAN title of that book.
- Do not change the "index" or "author" fields.
- Return ONLY valid JSON code in this format: [{"index": X, "title": "Translated Title"}] and no markdown formatting (no ```json).
- Do not add any extra text, explanations, or comments.

Libri:
${jsonEncode(toTranslate.map((e) => {"index": e["index"], "title": e["title"], "author": e["author"]}).toList())}
""";

    try {
      final response = await _model.generateContent([Content.text(promptStr)]);
      String responseText = response.text ?? '[]';
      
      // Estraiamo il JSON puro dalla risposta (gestisce markdown, thinking, testo extra)
      responseText = _extractJsonArray(responseText);
      
      final List<dynamic> resultList = jsonDecode(responseText);
      
      for (final item in resultList) {
        final index = item['index'] as int;
        final translatedTitle = item['title'] as String;
        
        // Aggiorniamo la lista da restituire
        final originalBook = translatedDocs[index];
        translatedDocs[index] = Map<String, dynamic>.from(originalBook);
        translatedDocs[index]['title'] = translatedTitle;

        // Salviamo in cache
        final key = toTranslate.firstWhere((element) => element['index'] == index)['key'];
        _titleCache[key] = translatedTitle;
      }
    } catch (e) {
      print('Errore in Gemini durante la traduzione dei titoli: $e');
      // In caso di errore di Gemini (es. rate limit), restituiamo i titoli originali in inglese per non rompere l'app
    }

    return translatedDocs;
  }

  /// Estrae un array JSON puro da una risposta potenzialmente sporca
  /// (con markdown, thinking, testo extra, ecc.)
  String _extractJsonArray(String raw) {
    // Prima puliamo eventuali blocchi markdown
    raw = raw.replaceAll(RegExp(r'```json\s*', caseSensitive: false), '');
    raw = raw.replaceAll(RegExp(r'```\s*'), '');
    raw = raw.trim();
    
    // Cerchiamo il primo array JSON valido nella risposta
    final match = RegExp(r'\[[\s\S]*\]').firstMatch(raw);
    if (match != null) {
      return match.group(0)!;
    }
    
    // Se non troviamo nulla, restituiamo un array vuoto
    return '[]';
  }
}

// Istanza globale (in una vera app si inietta con un service locator o Provider)
final geminiService = GeminiService();
