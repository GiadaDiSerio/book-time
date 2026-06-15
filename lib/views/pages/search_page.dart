import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../controllers/app_controller.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/suggestions_widget.dart';
import '../dialogs/add_book_sheet.dart';

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

  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['PER TE', 'SCOPRI'];

  Future<void> searchBooks(String query) async {
    _debounce?.cancel();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchResults = [];
    });

    try {
      final appController = context.read<AppController>();
      final docs = await apiService.searchBooks(query, appController.languageCode);
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
    final appController = context.watch<AppController>();
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24), // Makes it more pill-shaped, often looks better when small
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, child) {
                    if (value.text.isNotEmpty) {
                      return IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          // Simula un onChanged con stringa vuota per resettare i risultati
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          setState(() {
                            _searchResults = [];
                            _errorMessage = null;
                            _isLoading = false;
                          });
                        },
                      );
                    }
                    return const SizedBox.shrink();
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

          // Sezione Categorie (Pills)
          SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(_categories.length, (index) {
                final isSelected = index == _selectedCategoryIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      _categories[index],
                      style: TextStyle(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.onPrimary 
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }),
            ),
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
                                  if (_selectedCategoryIndex == 0) ...[
                                    SuggestionsWidget(
                                      key: ValueKey('author_${appController.languageCode}_$_refreshCounter'),
                                      mode: SuggestionMode.author,
                                    ),
                                    SuggestionsWidget(
                                      key: ValueKey('fav_genre_${appController.languageCode}_$_refreshCounter'),
                                      mode: SuggestionMode.genre,
                                      specificGenre: 'favorite',
                                      showLoadingIndicator: false,
                                    ),
                                  ] else if (_selectedCategoryIndex == 1) ...[
                                    SuggestionsWidget(
                                      key: ValueKey('scopri1_${appController.languageCode}_$_refreshCounter'),
                                      mode: SuggestionMode.genre,
                                      showLoadingIndicator: true,
                                    ),
                                    SuggestionsWidget(
                                      key: ValueKey('gen_thriller_${appController.languageCode}_$_refreshCounter'),
                                      mode: SuggestionMode.genre,
                                      specificGenre: 'thriller',
                                      showLoadingIndicator: false,
                                    ),
                                    SuggestionsWidget(
                                      key: ValueKey('gen_fantasy_${appController.languageCode}_$_refreshCounter'),
                                      mode: SuggestionMode.genre,
                                      specificGenre: 'fantasy',
                                      showLoadingIndicator: false,
                                    ),
                                    SuggestionsWidget(
                                      key: ValueKey('gen_romanzo_${appController.languageCode}_$_refreshCounter'),
                                      mode: SuggestionMode.genre,
                                      specificGenre: 'romanzo',
                                      showLoadingIndicator: false,
                                    ),
                                    SuggestionsWidget(
                                      key: ValueKey('gen_scifi_${appController.languageCode}_$_refreshCounter'),
                                      mode: SuggestionMode.genre,
                                      specificGenre: 'fantascienza',
                                      showLoadingIndicator: false,
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      '↓ Trascina verso il basso per aggiornare i suggerimenti',
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
