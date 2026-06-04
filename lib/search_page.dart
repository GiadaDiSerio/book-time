import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Serve per leggere il formato JSON che ci manda Google
import 'app_state.dart';
import 'responsive_wrapper.dart';
import 'suggestions_widget.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // Questo "controller" legge cosa scrive l'utente nella barra di ricerca
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Qui salveremo la lista dei libri trovati
  List<dynamic> _searchResults = [];

  // Questa variabile ci dice se stiamo aspettando i risultati (per mostrare la rotellina di caricamento)
  bool _isLoading = false;

  // Messaggio di errore da mostrare sullo schermo
  String? _errorMessage;

  // Contatore per forzare il refresh dei suggerimenti
  int _refreshCounter = 0;

  // Questa è la funzione che chiama le API di Open Library (gratuite, senza API key!)
  Future<void> searchBooks(String query) async {
    _debounce?.cancel();
    if (query.isEmpty) return; // Se l'utente non ha scritto nulla, fermati

    setState(() {
      _isLoading = true; // Mostra il caricamento
      _errorMessage = null; // Resetta eventuali errori precedenti
      _searchResults = []; // Pulisci i risultati precedenti
    });

    // L'indirizzo web delle API di Open Library (gratuite e senza limiti!)
    final url = Uri.parse(
      'https://openlibrary.org/search.json?q=${Uri.encodeComponent(query)}&language=${appState.languageCode}&limit=20',
    );

    try {
      print('--- Inizio ricerca per: $query ---');
      print('URL: $url');
      final response = await http.get(url); // Facciamo la richiesta a internet
      print('Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Se la risposta è OK (200), trasformiamo il testo JSON in una mappa Dart
        final data = json.decode(response.body);
        // Open Library usa 'docs' invece di 'items'
        final docs = data['docs'] as List? ?? [];
        print('Numero risultati: ${docs.length}');
        setState(() {
          _searchResults = docs;
          if (_searchResults.isEmpty) {
            _errorMessage = 'Nessun libro trovato per "$query"';
          }
        });
      } else {
        setState(() {
          if (response.statusCode == 422) {
            _errorMessage = 'Ricerca troppo breve o non valida. Prova a scrivere parole intere.';
          } else {
            _errorMessage = 'Si è verificato un problema nella ricerca. Riprova più tardi.';
          }
        });
        print('Errore nella ricerca: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = 'Errore di connessione. Controlla la tua rete e riprova.';
      });
      print('Errore di connessione: $e');
      print('Stack trace: $stackTrace');
    } finally {
      setState(() {
        _isLoading = false; // Nascondi il caricamento alla fine
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapper(
        maxWidth: 700,
        child: Column(
        children: [
          // La barra di ricerca in alto
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Titolo o Autore',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    // Quando premo la lente di ingrandimento, avvia la ricerca
                    searchBooks(_searchController.text);
                  },
                ),
              ),
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                if (value.trim().isEmpty) {
                  setState(() {
                    _searchResults = [];
                    _errorMessage = null;
                    _isLoading = false;
                  });
                } else {
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    searchBooks(value);
                  });
                }
              },
              onSubmitted: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                searchBooks(value);
              }, // Avvia anche se premo "Invio" sulla tastiera
            ),
          ),

          // La lista dei risultati (o errore o caricamento o suggerimenti)
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  ) // Rotellina di caricamento
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                color: Colors.grey[400],
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _searchResults.isEmpty
                        ? RefreshIndicator(
                            onRefresh: () async {
                              setState(() {
                                _refreshCounter++;
                              });
                            },
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  const SizedBox(height: 8),
                                  SuggestionsWidget(
                                    key: ValueKey('author_${appState.languageCode}_$_refreshCounter'),
                                    mode: SuggestionMode.author,
                                  ),
                                  SuggestionsWidget(
                                    key: ValueKey('genre_${appState.languageCode}_$_refreshCounter'),
                                    mode: SuggestionMode.genre,
                                  ),
                                  const SizedBox(height: 16),
                                  const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      '↓ Scorri in basso per aggiornare i suggerimenti',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final book = _searchResults[index];

                          // Estraiamo i dati da Open Library
                          // I campi sono diversi da Google Books:
                          // - 'title' per il titolo
                          // - 'author_name' per gli autori (è una lista)
                          // - 'cover_i' per l'ID della copertina
                          final title = book['title'] ?? 'Titolo sconosciuto';
                          final authors = (book['author_name'] as List?)
                                  ?.join(', ') ??
                              'Autore sconosciuto';
                          // La copertina si costruisce così con Open Library
                          final coverId = book['cover_i'];
                          final imageUrl = coverId != null
                              ? 'https://covers.openlibrary.org/b/id/$coverId-M.jpg'
                              : null;

                          return ListTile(
                            leading: imageUrl != null
                                ? Image.network(
                                    imageUrl,
                                    width: 50,
                                    fit: BoxFit.cover,
                                    // Se l'immagine non si carica, mostra un'icona
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.book, size: 50),
                                  )
                                : const Icon(Icons.book, size: 50),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(authors),
                            trailing: const Icon(
                              Icons.add_circle_outline,
                            ), // Pulsante per aggiungere
                            onTap: () {
                              final bookKey = book['key'];
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (context) {
                                  bool isLoadingPlot = true;
                                  String plot = 'Caricamento trama...';

                                  return StatefulBuilder(
                                    builder: (context, setStateBottomSheet) {
                                      if (isLoadingPlot && bookKey != null) {
                                        isLoadingPlot = false;
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
                                            if (mounted) setStateBottomSheet(() { plot = fetchedPlot; });
                                          } else {
                                            if (mounted) setStateBottomSheet(() { plot = 'Impossibile caricare la trama.'; });
                                          }
                                        }).catchError((e) {
                                          if (mounted) setStateBottomSheet(() { plot = 'Errore durante il caricamento della trama.'; });
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
                                                  'Aggiungi "$title"',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF7B1FA2),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
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
                                              ListTile(
                                                leading: const Icon(Icons.bookmark_border, color: Color(0xFF7B1FA2)),
                                                title: const Text('Aggiungi a "Da leggere"'),
                                                onTap: () {
                                                  final messenger = ScaffoldMessenger.of(context);
                                                  appState.addBookToRead(title, author: authors, coverUrl: imageUrl);
                                                  Navigator.pop(context);
                                                  messenger.showSnackBar(const SnackBar(content: Text('Aggiunto a "Da leggere"')));
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.menu_book, color: Colors.blue),
                                                title: const Text('Aggiungi a "In lettura"'),
                                                onTap: () {
                                                  final pageMessenger = ScaffoldMessenger.of(context);
                                                  Navigator.pop(context); // Chiudi il bottom sheet
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
                                                          hintText: 'Es: 350',
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
                                                  appState.addBookRead(title, author: authors, coverUrl: imageUrl);
                                                  Navigator.pop(context);
                                                  messenger.showSnackBar(const SnackBar(content: Text('Aggiunto ai "Letti"!')));
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
                            },
                          );
                        },
                      ),
          ),
        ],
        ),
    );
  }
}
