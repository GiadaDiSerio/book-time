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
      model: 'gemini-2.0-flash',
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
Sei un traduttore esperto di letteratura.
Ti fornirò un elenco JSON di libri (titolo e autore originali).
Devi restituire l'elenco in JSON in cui la chiave "title" contiene il TITOLO UFFICIALE in italiano di quel libro.
Se non esiste un'edizione italiana nota, traduci letteralmente il titolo.
Restituisci SOLO codice JSON valido in questo formato: [{"index": X, "title": "Titolo Tradotto"}] e nessuna formattazione markdown (niente ```json).

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

  /// Genera una trama coinvolgente in italiano
  Future<String> generateItalianPlot(String title, String author, String fallbackPlot) async {
    final key = '$title - $author';
    
    if (_plotCache.containsKey(key)) {
      return _plotCache[key]!;
    }

    final promptStr = """
Scrivi una sinossi avvincente, senza spoiler e ben formattata in paragrafi (in italiano) per il seguente libro.
Titolo: $title
Autore: $author
Trama originale (potrebbe essere vuota o asettica): $fallbackPlot

Assicurati di rispondere SOLO con la trama in italiano e nessun testo introduttivo.
""";

    try {
      final response = await _model.generateContent([Content.text(promptStr)]);
      final plot = response.text?.trim() ?? 'Impossibile generare la trama al momento.';
      
      _plotCache[key] = plot;
      return plot;
    } catch (e) {
      print('Errore in Gemini durante la generazione della trama: $e');
      return fallbackPlot.isNotEmpty && fallbackPlot != 'Nessuna trama disponibile.' 
          ? fallbackPlot 
          : 'Impossibile generare la trama a causa di un errore (forse limite richieste).';
    }
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
