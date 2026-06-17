import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'gemini_service.dart';
import 'translation_service.dart';

/// Servizio dedicato alle chiamate verso l'API di Open Library.
/// Separa la logica di rete dall'interfaccia utente (SoC).
class ApiService {
  static const String _baseUrl = 'https://openlibrary.org';

  /// Cerca libri per titolo o autore
  Future<List<dynamic>> searchBooks(String query, String languageCode) async {
    if (query.isEmpty) return [];

    final url = Uri.parse(
      '$_baseUrl/search.json?q=${Uri.encodeComponent(query)}&language=$languageCode&limit=10',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final docs = data['docs'] as List? ?? [];
        return await geminiService.translateSearchDocs(docs);
      } else if (response.statusCode == 422) {
        throw Exception('Ricerca troppo breve o non valida. Prova a scrivere parole intere.');
      } else {
        throw Exception('Si è verificato un problema nella ricerca. Riprova più tardi.');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Ricerca')) {
        rethrow;
      }
      throw Exception('Errore di connessione. Controlla la tua rete e riprova.');
    }
  }

  /// Recupera la descrizione di un libro dalla sua chiave
  Future<String> fetchBookPlotByKey(String? bookKey, String title, String author) async {
    if (bookKey == null) return await translationService.translatePlot('Nessuna trama disponibile.');

    try {
      final url = Uri.parse('$_baseUrl$bookKey.json');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String fallbackPlot = 'Nessuna trama disponibile in italiano/inglese.';
        if (data['description'] != null) {
          if (data['description'] is String) {
            fallbackPlot = data['description'];
          } else if (data['description'] is Map && data['description']['value'] != null) {
            fallbackPlot = data['description']['value'];
          }
        }
        return await translationService.translatePlot(fallbackPlot);
      } else {
        return await translationService.translatePlot('Impossibile caricare la trama originale.');
      }
    } catch (e) {
      return await translationService.translatePlot('Errore durante il caricamento della trama.');
    }
  }

  /// Cerca la trama di un libro tramite il suo titolo e autore
  Future<String> fetchBookPlot(String title, String author) async {
    try {
      final searchUrl = Uri.parse(
        '$_baseUrl/search.json?title=${Uri.encodeComponent(title)}&author=${Uri.encodeComponent(author)}&limit=1',
      );
      final searchResponse = await http.get(searchUrl);

      if (searchResponse.statusCode == 200) {
        final searchData = json.decode(searchResponse.body);
        final docs = searchData['docs'] as List? ?? [];
        if (docs.isNotEmpty) {
          final bookKey = docs[0]['key'];
          if (bookKey != null) {
            return await fetchBookPlotByKey(bookKey, title, author);
          }
        }
        return await translationService.translatePlot('Nessuna trama disponibile.');
      } else {
        return await translationService.translatePlot('Impossibile caricare la trama.');
      }
    } catch (e) {
      return await translationService.translatePlot('Errore durante il caricamento della trama.');
    }
  }

  /// Recupera suggerimenti di libri per autore o genere
  Future<List<dynamic>> fetchSuggestions({
    required List<String> validAuthors,
    required bool isAuthorMode,
    required String languageCode,
    required List<String> existingBookTitles,
    String? specificGenre,
  }) async {
    String query = '';
    String suggestionReason = '';

    final subjects = [
      'romanzo', 'thriller', 'fantasy', 'avventura', 'giallo',
      'fantascienza', 'horror', 'poesia', 'storia', 'biografia',
      'filosofia', 'arte', 'scienza', 'psicologia', 'classici',
    ];

    if (specificGenre == 'favorite') {
      final randomSubject = subjects[Random().nextInt(subjects.length)];
      query = 'subject=${Uri.encodeComponent(randomSubject)}';
      suggestionReason = 'Siccome ti piace il ${randomSubject[0].toUpperCase()}${randomSubject.substring(1)}';
    } else if (specificGenre != null) {
      query = 'subject=${Uri.encodeComponent(specificGenre)}';
      suggestionReason = '${specificGenre[0].toUpperCase()}${specificGenre.substring(1)}';
    } else if (isAuthorMode && validAuthors.isNotEmpty) {
      final randomAuthor = validAuthors[Random().nextInt(validAuthors.length)];
      final cleanAuthor = randomAuthor.split(',').first.trim();
      query = 'author=${Uri.encodeComponent(cleanAuthor)}';
      suggestionReason = 'Perché ti piace $cleanAuthor';
    } else {
      final randomSubject = subjects[Random().nextInt(subjects.length)];
      query = 'subject=${Uri.encodeComponent(randomSubject)}';
      suggestionReason = '${randomSubject[0].toUpperCase()}${randomSubject.substring(1)}';
    }

    final url = Uri.parse('$_baseUrl/search.json?$query&language=$languageCode&limit=15');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final docs = data['docs'] as List? ?? [];
        
        final filteredDocs = docs.where((book) {
          final title = (book['title'] ?? '').toString().toLowerCase();
          final hasCover = book['cover_i'] != null;
          return hasCover && !existingBookTitles.contains(title);
        }).take(8).toList();

        return [suggestionReason, filteredDocs];
      }
      return [suggestionReason, []];
    } catch (e) {
      return [suggestionReason, []];
    }
  }
}

// Istanza globale del servizio (in una vera architettura verrebbe iniettato)
final apiService = ApiService();
