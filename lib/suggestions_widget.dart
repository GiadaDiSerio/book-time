import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_state.dart';
import 'rating_dialog.dart';

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

  void _showAddDialog(BuildContext context, Map<String, dynamic> book) {
    final title = book['title'] ?? 'Titolo sconosciuto';
    final authors = (book['author_name'] as List?)?.join(', ') ?? 'Autore sconosciuto';
    final coverId = book['cover_i'];
    final imageUrl = coverId != null ? 'https://covers.openlibrary.org/b/id/$coverId-M.jpg' : null;
    final bookKey = book['key'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permette al bottom sheet di prendere più spazio
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isLoadingPlot = true;
        String plot = 'Caricamento trama...';

        return StatefulBuilder(
          builder: (context, setStateBottomSheet) {
            // Fetch trama al primo avvio
            if (isLoadingPlot && bookKey != null) {
              isLoadingPlot = false; // Prevents multiple calls
              http.get(Uri.parse('https://openlibrary.org$bookKey.json')).then((response) {
                if (response.statusCode == 200) {
                  final data = json.decode(response.body);
                  String fetchedPlot = 'Nessuna trama disponibile in italiano/inglese.';
                  if (data['description'] != null) {
                    if (data['description'] is String) {
                      fetchedPlot = data['description'];
                    } else if (data['description'] is Map && data['description']['value'] != null) {
                      fetchedPlot = data['description']['value'];
                    }
                  }
                  if (mounted) {
                    setStateBottomSheet(() {
                      plot = fetchedPlot;
                    });
                  }
                } else {
                  if (mounted) {
                    setStateBottomSheet(() {
                      plot = 'Impossibile caricare la trama.';
                    });
                  }
                }
              }).catchError((e) {
                if (mounted) {
                  setStateBottomSheet(() {
                    plot = 'Errore durante il caricamento della trama.';
                  });
                }
              });
            } else if (isLoadingPlot) {
              isLoadingPlot = false;
              plot = 'Nessuna trama disponibile.';
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7B1FA2),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Text(
                      authors,
                      style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Trama box
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          plot,
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.justify,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    // Bottoni opzioni
                    ListTile(
                      leading: const Icon(Icons.bookmark_border, color: Color(0xFF7B1FA2)),
                      title: const Text('Aggiungi a "Da leggere"'),
                      onTap: () {
                        final messenger = ScaffoldMessenger.of(context);
                        appState.addBookToRead(title, author: authors, coverUrl: imageUrl);
                        Navigator.pop(context);
                        messenger.showSnackBar(const SnackBar(content: Text('Aggiunto a "Da leggere"')));
                        setState(() { _suggestions.remove(book); });
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.menu_book, color: Colors.blue),
                      title: const Text('Aggiungi a "In lettura"'),
                      onTap: () {
                        final pageMessenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context); 
                        
                        final pagesController = TextEditingController();
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Quante pagine ha il libro?'),
                            content: TextField(
                              controller: pagesController,
                              keyboardType: TextInputType.number,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: 'Numero di pagine',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('ANNULLA'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  final pages = int.tryParse(pagesController.text);
                                  if (pages != null && pages > 0) {
                                    appState.addBookReading(title, author: authors, totalPages: pages, coverUrl: imageUrl);
                                    Navigator.pop(dialogContext);
                                    pageMessenger.showSnackBar(const SnackBar(content: Text('Aggiunto a "In lettura"')));
                                    setState(() { _suggestions.remove(book); });
                                  }
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B1FA2), foregroundColor: Colors.white),
                                child: const Text('AGGIUNGI'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                      title: const Text('Aggiungi come "Letto"'),
                      onTap: () {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        showRatingDialog(context, title, (rating) {
                          appState.addBookRead(title, author: authors, coverUrl: imageUrl, rating: rating);
                          messenger.showSnackBar(const SnackBar(content: Text('Aggiunto ai "Letti"!')));
                          setState(() { _suggestions.remove(book); });
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7B1FA2),
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

              return GestureDetector(
                onTap: () => _showAddDialog(context, book),
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
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
