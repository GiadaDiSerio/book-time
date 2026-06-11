import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'app_state.dart';
import 'responsive_wrapper.dart';
import 'suggestions_widget.dart';
import 'add_book_sheet.dart';

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

  Future<void> searchBooks(String query) async {
    _debounce?.cancel();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchResults = [];
    });

    try {
      final appState = context.read<AppState>();
      final docs = await apiService.searchBooks(query, appState.languageCode);
      setState(() {
        _searchResults = docs;
        if (_searchResults.isEmpty) {
          _errorMessage = 'Nessun libro trovato per "$query"';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false; // Nascondi il caricamento alla fine
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
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
                              showAddBookSheet(
                                context,
                                title: title,
                                authors: authors,
                                imageUrl: imageUrl,
                                bookKey: bookKey,
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
