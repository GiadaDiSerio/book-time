import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'storage_service.dart';

/// Servizio dedicato alle chiamate verso l'API di Open Library.
/// Separa la logica di rete dall'interfaccia utente (SoC).
class ApiService {
  static const String _baseUrl = 'https://openlibrary.org';

  void clearSuggestionsCache() {
    // Svuota solo se volessimo una pulizia forzata
  }

  Future<List<dynamic>?> getCachedSuggestions(String cacheKey) async {
    final cacheString = await storageService.getString('cache_$cacheKey');
    if (cacheString != null) {
      try {
        final decoded = json.decode(cacheString) as List<dynamic>;
        return decoded;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

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
    final cacheKey = '${isAuthorMode}_${specificGenre}_$languageCode';
    // Rimuoviamo il ritorno anticipato, verrà gestito dal widget!
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
      String matchedBookTitle = '';
      bool foundMatch = false;
      
      if (existingBookTitles.isNotEmpty) {
        // Mischiamo i titoli per provare con più libri se il primo non ha generi validi
        final titlesToTry = existingBookTitles.toList()..shuffle();
        
        for (final title in titlesToTry.take(5)) {
          try {
            // Cerchiamo fino a 3 edizioni per essere sicuri di trovarne una con i 'subject'
            final subjectUrl = Uri.parse('$_baseUrl/search.json?title=${Uri.encodeComponent(title)}&limit=3&fields=subject');
            final subResp = await http.get(subjectUrl);
            if (subResp.statusCode == 200) {
              final data = json.decode(subResp.body);
              final docs = data['docs'] as List? ?? [];
              
              for (var doc in docs) {
                if (doc['subject'] != null) {
                  final bookSubjects = doc['subject'] as List;
                  for (var s in bookSubjects) {
                    final subjectStr = s.toString().toLowerCase();
                    for (var entry in genreTranslations.entries) {
                      if (RegExp(r'\b' + entry.value + r'\b').hasMatch(subjectStr) ||
                          RegExp(r'\b' + entry.key + r'\b').hasMatch(subjectStr)) {
                        selectedSubject = entry.key;
                        matchedBookTitle = title;
                        foundMatch = true;
                        break;
                      }
                    }
                    if (foundMatch) break;
                  }
                }
                if (foundMatch) break;
              }
            }
          } catch (_) {}
          
          if (foundMatch) break;
        }

        final englishSubjectForQuery = genreTranslations[selectedSubject] ?? selectedSubject;
        query = 'subject=${Uri.encodeComponent(englishSubjectForQuery)}';
        
        if (foundMatch) {
          // Non c'è bisogno di displaySubject
          suggestionReason = 'Perché hai letto "$matchedBookTitle"';
        } else {
          // Se anche dopo 5 libri non troviamo nulla di mappato, proponiamo un genere a caso
          final randomSubject = subjects[Random().nextInt(subjects.length)];
          final englishSubjectForQuery = genreTranslations[randomSubject] ?? randomSubject;
          query = 'subject=${Uri.encodeComponent(englishSubjectForQuery)}';
          suggestionReason = 'Ti potrebbe piacere: ${randomSubject[0].toUpperCase()}${randomSubject.substring(1)}';
        }
      } else {
        final englishSubjectForQuery = genreTranslations[selectedSubject] ?? selectedSubject;
        query = 'subject=${Uri.encodeComponent(englishSubjectForQuery)}';
        suggestionReason = 'Ti potrebbe piacere: ${selectedSubject[0].toUpperCase()}${selectedSubject.substring(1)}';
      }
    } else if (specificGenre != null) {
      if (specificGenre == 'new_releases') {
        final randomSubject = subjects[Random().nextInt(subjects.length)];
        final englishSubjectForQuery = genreTranslations[randomSubject] ?? randomSubject;
        query = 'subject=${Uri.encodeComponent(englishSubjectForQuery)}&sort=new';
        suggestionReason = 'Nuove uscite da scoprire';
      } else if (specificGenre == 'short_reads') {
        query = 'subject=short_stories';
        suggestionReason = 'Letture veloci e racconti';
      } else if (specificGenre == 'mood') {
        final moods = {
          'Rilassati con un po\' di umorismo': 'humor',
          'Un tocco di romanticismo': 'romance',
          'Adrenalina pura': 'thriller',
          'Un viaggio in un altro mondo': 'fantasy',
          'Riflessioni profonde': 'philosophy'
        };
        final moodKeys = moods.keys.toList();
        final selectedMoodLabel = moodKeys[Random().nextInt(moodKeys.length)];
        final moodSubject = moods[selectedMoodLabel]!;
        query = 'subject=${Uri.encodeComponent(moodSubject)}';
        suggestionReason = selectedMoodLabel;
      } else if (specificGenre == 'trending') {
        query = 'subject=best_sellers';
        suggestionReason = 'I più popolari del momento';
      } else if (specificGenre == 'classic') {
        query = 'subject=classic_literature';
        suggestionReason = 'I grandi classici';
      } else if (specificGenre == 'page_turner') {
        query = 'subject=thriller';
        suggestionReason = 'Da leggere tutto d\'un fiato';
      } else {
        final englishSubjectForQuery = genreTranslations[specificGenre.toLowerCase()] ?? specificGenre;
        query = 'subject=${Uri.encodeComponent(englishSubjectForQuery)}';
        suggestionReason = '${specificGenre[0].toUpperCase()}${specificGenre.substring(1)}';
      }
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

    final url = Uri.parse('$_baseUrl/search.json?$query&language=$languageCode&limit=5&fields=key,title,author_name,cover_i');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final docs = data['docs'] as List? ?? [];
        
        var filteredDocs = docs.where((book) {
          final title = (book['title'] ?? '').toString().toLowerCase();
          return !existingBookTitles.contains(title);
        }).toList();
        filteredDocs.shuffle();
        filteredDocs = filteredDocs.take(5).toList();

        // Fallback: se dopo il filtro i risultati sono zero, peschiamo un genere casuale
        if (filteredDocs.isEmpty) {
          final randomSubject = subjects[Random().nextInt(subjects.length)];
          final englishSubjectForQuery = genreTranslations[randomSubject] ?? randomSubject;
          final fallbackQuery = 'subject=${Uri.encodeComponent(englishSubjectForQuery)}';
          final fallbackUrl = Uri.parse('$_baseUrl/search.json?$fallbackQuery&language=$languageCode&limit=5&fields=key,title,author_name,cover_i');
          final fallbackResponse = await http.get(fallbackUrl);
          
          if (fallbackResponse.statusCode == 200) {
            final fallbackData = json.decode(fallbackResponse.body);
            final fallbackDocs = fallbackData['docs'] as List? ?? [];
            filteredDocs = fallbackDocs.where((book) {
              final title = (book['title'] ?? '').toString().toLowerCase();
              return !existingBookTitles.contains(title);
            }).toList();
            filteredDocs.shuffle();
            filteredDocs = filteredDocs.take(5).toList();
            suggestionReason = 'Ti potrebbe piacere: ${randomSubject[0].toUpperCase()}${randomSubject.substring(1)}';
          }
        }

        final result = [suggestionReason, filteredDocs];
        if (filteredDocs.isNotEmpty) {
          await storageService.saveString('cache_$cacheKey', json.encode(result));
        }
        return result;
      }
      return [suggestionReason, []];
    } catch (e) {
      return [suggestionReason, []];
    }
  }
}

// Istanza globale del servizio (in una vera architettura verrebbe iniettato)
final apiService = ApiService();
