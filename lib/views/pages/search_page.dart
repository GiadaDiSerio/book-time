import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
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
  
  // Controller per gestire lo scroll della pagina dei suggerimenti
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _timeoutTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
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

  final List<String> _allSubjects = [
    'romanzo', 'thriller', 'fantasy', 'avventura', 'giallo',
    'fantascienza', 'horror', 'poesia', 'storia', 'biografia',
    'arte', 'scienza', 'psicologia', 'classici', 'romanzi rosa',
    'saggistica', 'umorismo', 'filosofia', 'fumetti', 'cucina',
    'viaggi', 'religione', 'musica', 'natura', 'crescita personale',
    'young adult', 'distopia', 'architettura', 'true crime', 'fotografia',
  ];
  List<String> _currentScopriGenres = [];
  List<String> _currentPerTeExtraSections = [];

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  int _loadingWidgetsCount = 0;
  bool _isSuggestionsLoading = true;
  bool _hasTimedOut = false;
  Timer? _timeoutTimer;
  Completer<void>? _refreshCompleter;

  void _onSuggestionsLoadingChanged(bool isLoading) {
    if (!mounted) return;
    setState(() {
      if (isLoading) {
        _loadingWidgetsCount++;
      } else {
        _loadingWidgetsCount--;
        if (_loadingWidgetsCount <= 0) {
          _loadingWidgetsCount = 0;
          _isSuggestionsLoading = false;
          _timeoutTimer?.cancel();
          if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
            _refreshCompleter!.complete();
            _refreshCompleter = null;
          }
        }
      }
    });
  }

  void _onSuggestionsResultChanged(bool hasResults) {
    if (!mounted) return;
    if (hasResults) {
      setState(() {
        _hasTimedOut = false; // Nasconde l'errore se i dati arrivano tardi
      });
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      setState(() {
        _hasTimedOut = true;
        _isSuggestionsLoading = false;
      });
      if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete();
        _refreshCompleter = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _generateScopriGenres();
    _startTimeoutTimer();
  }

  void _generateScopriGenres() {
    final copy = List<String>.from(_allSubjects)
      ..removeWhere((genre) => _currentScopriGenres.contains(genre))
      ..shuffle();
    _currentScopriGenres = copy.take(5).toList();

    bool hasBooks = false;
    try {
      final appController = context.read<AppController>();
      hasBooks = appController.booksRead.isNotEmpty || 
                 appController.booksToRead.isNotEmpty || 
                 appController.booksReading.isNotEmpty;
    } catch (_) {}

    final pool = ['new_releases', 'short_reads', 'mood']..shuffle();
    if (hasBooks) {
      _currentPerTeExtraSections = ['author', 'favorite', pool.first]..shuffle();
    } else {
      _currentPerTeExtraSections = pool.take(3).toList();
    }
  }

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
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, child) {
              if (value.text.isNotEmpty) {
                return const SizedBox.shrink();
              }
              return SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(_categories.length, (index) {
                      final isSelected = index == _selectedCategoryIndex;
                      return GestureDetector(
                        onTap: () {
                          if (_selectedCategoryIndex == index) return;
                          if (_scrollController.hasClients) {
                            _scrollController.jumpTo(0);
                          }
                          setState(() {
                            _selectedCategoryIndex = index;
                            _loadingWidgetsCount = 0;
                            _isSuggestionsLoading = true;
                            _hasTimedOut = false;
                            _timeoutTimer?.cancel();
                          });
                          _startTimeoutTimer();
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
              );
            },
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
                            key: _refreshIndicatorKey,
                            onRefresh: () async {
                              _refreshCompleter = Completer<void>();
                              setState(() {
                                _loadingWidgetsCount = 0;
                                _isSuggestionsLoading = true;
                                _hasTimedOut = false;
                                _refreshCounter++;
                                _generateScopriGenres();
                              });
                              _startTimeoutTimer();
                              return _refreshCompleter!.future;
                            },
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  const SizedBox(height: 8),
                                  if (_selectedCategoryIndex == 0) ...[
                                    if (appController.booksRead.isEmpty && appController.booksReading.isEmpty && appController.booksToRead.isEmpty) ...[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                                        child: Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(128), // 0.5 opacity
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(51)), // 0.2 opacity
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Benvenuto su Book Time!',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'La tua libreria è ancora vuota. Cerca il tuo libro preferito o esplora i titoli qui sotto per iniziare a ricevere consigli su misura per te.',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      for (int i = 0; i < _currentPerTeExtraSections.length; i++)
                                        SuggestionsWidget(
                                          key: ValueKey('pop_${_currentPerTeExtraSections[i]}_${appController.languageCode}_$_refreshCounter'),
                                          mode: SuggestionMode.genre,
                                          specificGenre: _currentPerTeExtraSections[i],
                                          onLoadingStateChanged: _onSuggestionsLoadingChanged,
                                          onHasResults: _onSuggestionsResultChanged,
                                        ),
                                    ] else ...[
                                      for (int i = 0; i < _currentPerTeExtraSections.length; i++)
                                        if (_currentPerTeExtraSections[i] == 'author')
                                          SuggestionsWidget(
                                            key: ValueKey('author_${appController.languageCode}_$_refreshCounter'),
                                            mode: SuggestionMode.author,
                                            onLoadingStateChanged: _onSuggestionsLoadingChanged,
                                            onHasResults: _onSuggestionsResultChanged,
                                          )
                                        else if (_currentPerTeExtraSections[i] == 'favorite')
                                          SuggestionsWidget(
                                            key: ValueKey('fav_genre_${appController.languageCode}_$_refreshCounter'),
                                            mode: SuggestionMode.genre,
                                            specificGenre: 'favorite',
                                            onLoadingStateChanged: _onSuggestionsLoadingChanged,
                                            onHasResults: _onSuggestionsResultChanged,
                                          )
                                        else
                                          SuggestionsWidget(
                                            key: ValueKey('${_currentPerTeExtraSections[i]}_${appController.languageCode}_$_refreshCounter'),
                                            mode: SuggestionMode.genre,
                                            specificGenre: _currentPerTeExtraSections[i],
                                            onLoadingStateChanged: _onSuggestionsLoadingChanged,
                                            onHasResults: _onSuggestionsResultChanged,
                                          ),
                                    ],
                                  ] else if (_selectedCategoryIndex == 1) ...[
                                    for (int i = 0; i < _currentScopriGenres.length; i++)
                                      SuggestionsWidget(
                                        key: ValueKey('scopri_${_currentScopriGenres[i]}_${appController.languageCode}_$_refreshCounter'),
                                        mode: SuggestionMode.genre,
                                        specificGenre: _currentScopriGenres[i],
                                        onLoadingStateChanged: _onSuggestionsLoadingChanged,
                                        onHasResults: _onSuggestionsResultChanged,
                                      ),
                                  ],
                                  if (!_isSuggestionsLoading && _hasTimedOut) ...[
                                    const SizedBox(height: 48),
                                    Icon(
                                      Icons.cloud_off_rounded,
                                      color: Colors.grey[400],
                                      size: 56,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Non è stato possibile caricare i suggerimenti.\nControlla la connessione e trascina per riprovare.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 16),
                                  ] else if (!_isSuggestionsLoading) ...[
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

                          // Controllo se il libro è già presente nelle liste dell'utente
                          final isAlreadyAdded = appController.booksReading.any((b) => b.title.toLowerCase() == title.toLowerCase()) ||
                                                 appController.booksToRead.any((b) => b.title.toLowerCase() == title.toLowerCase()) ||
                                                 appController.booksRead.any((b) => b.title.toLowerCase() == title.toLowerCase());

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
                            trailing: IconButton(
                              icon: isAlreadyAdded
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.add_circle_outline),
                              onPressed: isAlreadyAdded
                                  ? () {
                                      // Rimuovi il libro
                                      Book? bookToRemove;
                                      for (final b in [...appController.booksReading, ...appController.booksToRead, ...appController.booksRead]) {
                                        if (b.title.toLowerCase() == title.toLowerCase()) {
                                          bookToRemove = b;
                                          break;
                                        }
                                      }
                                      if (bookToRemove != null) {
                                        appController.removeBook(bookToRemove.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Libro rimosso dalla libreria.')),
                                        );
                                      }
                                    }
                                  : () {
                                      final bookKey = book['key'];
                                      showAddBookSheet(
                                        context,
                                        title: title,
                                        authors: authors,
                                        imageUrl: imageUrl,
                                        bookKey: bookKey,
                                      );
                                    },
                            ),
                            onTap: isAlreadyAdded
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Questo libro è già nella tua libreria!')),
                                    );
                                  }
                                : () {
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
