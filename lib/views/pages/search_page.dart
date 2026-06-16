import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/gemini_service.dart';
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
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['PER TE', 'SCOPRI'];

  // Cache per i caroselli
  bool _isLoadingSuggestions = false;
  List<Map<String, dynamic>> _perTeCarousels = [];
  List<Map<String, dynamic>> _scopriCarousels = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCategoryData(_selectedCategoryIndex);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategoryData(int categoryIndex) async {
    // Evitiamo di ricaricare se abbiamo già i dati e non è un refresh forzato
    if (categoryIndex == 0 && _perTeCarousels.isNotEmpty) return;
    if (categoryIndex == 1 && _scopriCarousels.isNotEmpty) return;

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final appController = context.read<AppController>();
      List<String> validAuthors = appController.booksRead
          .where((b) => b.rating >= 4 && b.author != 'Autore sconosciuto')
          .map((b) => b.author)
          .toSet()
          .toList();

      if (validAuthors.isEmpty) {
        final allBooks = [
          ...appController.booksRead,
          ...appController.booksReading,
          ...appController.booksToRead,
        ];
        validAuthors = allBooks
            .map((b) => b.author)
            .where((a) => a != 'Autore sconosciuto')
            .toSet()
            .toList();
      }

      final allMyBookTitles = [
        ...appController.booksRead.map((b) => b.title.toLowerCase()),
        ...appController.booksReading.map((b) => b.title.toLowerCase()),
        ...appController.booksToRead.map((b) => b.title.toLowerCase()),
      ];

      List<Future<List<dynamic>>> fetchTasks = [];

      if (categoryIndex == 0) { // PER TE
        fetchTasks.add(apiService.fetchSuggestions(
          validAuthors: validAuthors,
          isAuthorMode: true,
          languageCode: appController.languageCode,
          existingBookTitles: allMyBookTitles,
        ));
        fetchTasks.add(apiService.fetchSuggestions(
          validAuthors: validAuthors,
          isAuthorMode: false,
          languageCode: appController.languageCode,
          existingBookTitles: allMyBookTitles,
          specificGenre: 'favorite',
        ));
      } else { // SCOPRI
        fetchTasks.add(apiService.fetchSuggestions(
          validAuthors: validAuthors,
          isAuthorMode: false,
          languageCode: appController.languageCode,
          existingBookTitles: allMyBookTitles,
        ));
        fetchTasks.add(apiService.fetchSuggestions(
          validAuthors: validAuthors,
          isAuthorMode: false,
          languageCode: appController.languageCode,
          existingBookTitles: allMyBookTitles,
          specificGenre: 'thriller',
        ));
        fetchTasks.add(apiService.fetchSuggestions(
          validAuthors: validAuthors,
          isAuthorMode: false,
          languageCode: appController.languageCode,
          existingBookTitles: allMyBookTitles,
          specificGenre: 'fantasy',
        ));
        fetchTasks.add(apiService.fetchSuggestions(
          validAuthors: validAuthors,
          isAuthorMode: false,
          languageCode: appController.languageCode,
          existingBookTitles: allMyBookTitles,
          specificGenre: 'romanzo',
        ));
        fetchTasks.add(apiService.fetchSuggestions(
          validAuthors: validAuthors,
          isAuthorMode: false,
          languageCode: appController.languageCode,
          existingBookTitles: allMyBookTitles,
          specificGenre: 'fantascienza',
        ));
      }

      final results = await Future.wait(fetchTasks);
      
      // Ora raccogliamo tutti i libri in una singola lista
      List<dynamic> allBooks = [];
      for (var result in results) {
        if (result.length == 2) {
          allBooks.addAll(result[1] as List<dynamic>);
        }
      }

      // 1 SOLA chiamata a Gemini per tradurre tutti i titoli di tutti i caroselli!
      final translatedBooks = await geminiService.translateSearchDocs(allBooks);

      // Ri-smistiamo i libri nei rispettivi caroselli
      int pointer = 0;
      List<Map<String, dynamic>> finalCarousels = [];
      
      for (var result in results) {
        if (result.length == 2) {
          final String title = result[0];
          final List<dynamic> originalDocs = result[1];
          final int count = originalDocs.length;
          
          final docsForThisCarousel = translatedBooks.sublist(pointer, pointer + count);
          finalCarousels.add({
            'title': title,
            'docs': docsForThisCarousel,
          });
          pointer += count;
        }
      }

      if (mounted) {
        setState(() {
          if (categoryIndex == 0) {
            _perTeCarousels = finalCarousels;
          } else {
            _scopriCarousels = finalCarousels;
          }
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      print('Errore fetch category data: $e');
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
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
          _errorMessage = 'Nessun libro trovato per "\$query"';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24), 
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
              }, 
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
                    if (_selectedCategoryIndex != index) {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });
                      _fetchCategoryData(index);
                    }
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

          // La lista dei risultati o caroselli
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
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
                                if (_selectedCategoryIndex == 0) _perTeCarousels.clear();
                                else _scopriCarousels.clear();
                              });
                              await _fetchCategoryData(_selectedCategoryIndex);
                            },
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  const SizedBox(height: 8),
                                  if (_isLoadingSuggestions)
                                    const Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: Center(child: CircularProgressIndicator()),
                                    )
                                  else if (_selectedCategoryIndex == 0)
                                    ..._perTeCarousels.map((carousel) => SuggestionsWidget(
                                      title: carousel['title'],
                                      suggestions: carousel['docs'],
                                    ))
                                  else if (_selectedCategoryIndex == 1)
                                    ..._scopriCarousels.map((carousel) => SuggestionsWidget(
                                      title: carousel['title'],
                                      suggestions: carousel['docs'],
                                    )),
                                  
                                  const SizedBox(height: 16),
                                  if (!_isLoadingSuggestions)
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

                          final title = book['title'] ?? 'Titolo sconosciuto';
                          final authors = (book['author_name'] as List?)
                                  ?.join(', ') ??
                              'Autore sconosciuto';
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
                            ), 
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
