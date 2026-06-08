import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_state.dart';
import 'add_book_sheet.dart';

enum SuggestionMode { author, genre }

class SuggestionsWidget extends StatefulWidget {
  final SuggestionMode mode;

  const SuggestionsWidget({super.key, this.mode = SuggestionMode.author});

  @override
  State<SuggestionsWidget> createState() => _SuggestionsWidgetState();
}

class _SuggestionsWidgetState extends State<SuggestionsWidget> {
  List<dynamic> _suggestions = [];
  bool _isLoading = true;
  String _suggestionReason = 'Scelti per te';

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String query = '';

      // Raccogliamo autori dai libri con voti alti (4 o 5 stelle)
      List<String> validAuthors = appState.booksRead
          .where((b) => b.rating >= 4 && b.author != 'Autore sconosciuto')
          .map((b) => b.author)
          .toSet()
          .toList();

      // Se non ci sono voti alti, raccogliamo autori da TUTTE le liste come fallback
      if (validAuthors.isEmpty) {
        final allBooks = [
          ...appState.booksRead,
          ...appState.booksReading,
          ...appState.booksToRead,
        ];
        validAuthors = allBooks
            .map((b) => b.author)
            .where((a) => a != 'Autore sconosciuto')
            .toSet()
            .toList();
      }

      final subjects = [
        'romanzo', 'thriller', 'fantasy', 'avventura', 'giallo',
        'fantascienza', 'horror', 'poesia', 'storia', 'biografia',
        'filosofia', 'arte', 'scienza', 'psicologia', 'classici',
      ];

      if (widget.mode == SuggestionMode.author && validAuthors.isNotEmpty) {
        // Modalità autore: suggerimenti basati su un autore dalle liste
        final randomAuthor = validAuthors[Random().nextInt(validAuthors.length)];
        final cleanAuthor = randomAuthor.split(',').first.trim();
        query = 'author=${Uri.encodeComponent(cleanAuthor)}';
        _suggestionReason = 'Perché ti piace $cleanAuthor';
      } else {
        // Modalità genere (o fallback se non ci sono autori)
        final randomSubject = subjects[Random().nextInt(subjects.length)];
        query = 'subject=${Uri.encodeComponent(randomSubject)}';
        _suggestionReason = 'Esplora: ${randomSubject[0].toUpperCase()}${randomSubject.substring(1)}';
      }

      final url = Uri.parse('https://openlibrary.org/search.json?$query&language=${appState.languageCode}&limit=15');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final docs = data['docs'] as List? ?? [];
        
        // Filtriamo i libri che abbiamo già nelle nostre liste!
        final allMyBookTitles = [
          ...appState.booksRead.map((b) => b.title.toLowerCase()),
          ...appState.booksReading.map((b) => b.title.toLowerCase()),
          ...appState.booksToRead.map((b) => b.title.toLowerCase()),
        ];

        final filteredDocs = docs.where((book) {
          final title = (book['title'] ?? '').toString().toLowerCase();
          final hasCover = book['cover_i'] != null;
          return hasCover && !allMyBookTitles.contains(title); // Solo con copertina e non già letti
        }).take(8).toList(); // Prendiamo i primi 8 validi

        if (mounted) {
          setState(() {
            _suggestions = filteredDocs;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_suggestions.isEmpty) {
      return const SizedBox.shrink(); // Non mostrare nulla se non ci sono suggerimenti
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            _suggestionReason,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              final book = _suggestions[index];
              final coverId = book['cover_i'];
              final imageUrl = 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';
              final title = book['title'] ?? 'Sconosciuto';
              final authors = (book['author_name'] as List?)?.join(', ') ?? 'Autore sconosciuto';
              final bookKey = book['key'];

              return GestureDetector(
                onTap: () => showAddBookSheet(
                  context,
                  title: title,
                  authors: authors,
                  imageUrl: imageUrl,
                  bookKey: bookKey,
                  onBookAdded: () {
                    setState(() {
                      _suggestions.remove(book);
                    });
                  },
                ),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          height: 150,
                          width: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 150,
                            width: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.book, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(),
      ],
    );
  }
}
