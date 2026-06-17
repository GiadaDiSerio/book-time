import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

/// Servizio dedicato alle chiamate verso l'API di Open Library.
/// Separa la logica di rete dall'interfaccia utente (SoC).
class ApiService {
  static const String _baseUrl = 'https://openlibrary.org';

  /// Cerca libri per titolo o autore
  Future<List<dynamic>> searchBooks(String query, String languageCode) async {
    if (query.isEmpty) return [];

    final url = Uri.parse(
      '$_baseUrl/search.json?q=${Uri.encodeComponent(query)}&language=$languageCode&limit=20',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['docs'] as List? ?? [];
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
  Future<String> fetchBookPlotByKey(String? bookKey) async {
    if (bookKey == null) return 'Nessuna trama disponibile.';

    try {
      final url = Uri.parse('$_baseUrl$bookKey.json');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['description'] != null) {
          if (data['description'] is String) {
            return data['description'];
          } else if (data['description'] is Map && data['description']['value'] != null) {
            return data['description']['value'];
          }
        }
        return 'Nessuna trama disponibile in italiano/inglese.';
      } else {
        return 'Impossibile caricare la trama.';
      }
    } catch (e) {
      return 'Errore durante il caricamento della trama.';
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
            return await fetchBookPlotByKey(bookKey);
          }
        }
        return 'Nessuna trama disponibile.';
      } else {
        return 'Impossibile caricare la trama.';
      }
    } catch (e) {
      return 'Errore durante il caricamento della trama.';
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
      'arte', 'scienza', 'psicologia', 'classici', 'romanzi rosa',
      'saggistica', 'umorismo', 'filosofia', 'fumetti', 'cucina',
      'viaggi', 'religione', 'musica', 'natura', 'crescita personale',
      'young adult', 'distopia', 'architettura', 'true crime', 'fotografia',
    ];

    final Map<String, String> genreTranslations = {
      'romanzo': 'novel',
      'thriller': 'thriller',
      'fantasy': 'fantasy',
      'avventura': 'adventure',
      'giallo': 'mystery',
      'fantascienza': 'science fiction',
      'horror': 'horror',
      'poesia': 'poetry',
      'storia': 'history',
      'biografia': 'biography',
      'arte': 'art',
      'scienza': 'science',
      'psicologia': 'psychology',
      'classici': 'classics',
      'romanzi rosa': 'romance',
      'saggistica': 'essays',
      'umorismo': 'humor',
      'filosofia': 'philosophy',
      'fumetti': 'comics',
      'cucina': 'cooking',
      'viaggi': 'travel',
      'religione': 'religion',
      'musica': 'music',
      'natura': 'nature',
      'crescita personale': 'self-help',
      'young adult': 'young adult',
      'distopia': 'dystopian',
      'architettura': 'architecture',
      'true crime': 'true crime',
      'fotografia': 'photography',
    };

    if (specificGenre == 'favorite') {
      String selectedSubject = subjects[Random().nextInt(subjects.length)];
      
      if (existingBookTitles.isNotEmpty) {
        // Scegliamo un libro a caso tra quelli salvati dall'utente
        final randomBookTitle = existingBookTitles[Random().nextInt(existingBookTitles.length)];
        try {
          final subjectUrl = Uri.parse('$_baseUrl/search.json?title=${Uri.encodeComponent(randomBookTitle)}&limit=1');
          final subResp = await http.get(subjectUrl);
          if (subResp.statusCode == 200) {
            final data = json.decode(subResp.body);
            final docs = data['docs'] as List? ?? [];
            if (docs.isNotEmpty && docs[0]['subject'] != null) {
              final bookSubjects = docs[0]['subject'] as List;
              final englishValues = genreTranslations.values.toList();
              // Cerchiamo un genere che coincida con quelli tradotti in inglese o con i termini in italiano
              final validSubjects = bookSubjects
                  .map((s) => s.toString().toLowerCase())
                  .where((s) => englishValues.contains(s) || subjects.contains(s))
                  .toList();
              if (validSubjects.isNotEmpty) {
                final foundSubject = validSubjects.first;
                if (englishValues.contains(foundSubject)) {
                  selectedSubject = genreTranslations.entries.firstWhere((e) => e.value == foundSubject).key;
                } else {
                  selectedSubject = foundSubject;
                }
              }
            }
          }
        } catch (_) {}

        final englishSubjectForQuery = genreTranslations[selectedSubject] ?? selectedSubject;
        query = 'subject=${Uri.encodeComponent(englishSubjectForQuery)}';
        suggestionReason = 'Perché hai letto "$randomBookTitle": ${selectedSubject[0].toUpperCase()}${selectedSubject.substring(1)}';
      } else {
        final englishSubjectForQuery = genreTranslations[selectedSubject] ?? selectedSubject;
        query = 'subject=${Uri.encodeComponent(englishSubjectForQuery)}';
        suggestionReason = 'In evidenza: ${selectedSubject[0].toUpperCase()}${selectedSubject.substring(1)}';
      }
    } else if (specificGenre != null) {
      final englishSubjectForQuery = genreTranslations[specificGenre.toLowerCase()] ?? specificGenre;
      query = 'subject=${Uri.encodeComponent(englishSubjectForQuery)}';
      suggestionReason = '${specificGenre[0].toUpperCase()}${specificGenre.substring(1)}';
    } else if (isAuthorMode && validAuthors.isNotEmpty) {
      final randomAuthor = validAuthors[Random().nextInt(validAuthors.length)];
      final cleanAuthor = randomAuthor.split(',').first.trim();
      query = 'author=${Uri.encodeComponent(cleanAuthor)}';
      suggestionReason = 'Perché ti piace $cleanAuthor';
    } else {
      final randomSubject = subjects[Random().nextInt(subjects.length)];
      final englishSubjectForQuery = genreTranslations[randomSubject] ?? randomSubject;
      query = 'subject=${Uri.encodeComponent(englishSubjectForQuery)}';
      suggestionReason = '${randomSubject[0].toUpperCase()}${randomSubject.substring(1)}';
    }

    final url = Uri.parse('$_baseUrl/search.json?$query&language=$languageCode&limit=40');
    
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
