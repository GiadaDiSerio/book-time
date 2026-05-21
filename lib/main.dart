import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'search_page.dart';
import 'timer_page.dart';
import 'app_state.dart';
import 'responsive_wrapper.dart';
import 'book_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.loadState();
  runApp(const BookTimeApp());
}

class BookTimeApp extends StatelessWidget {
  const BookTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Time',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // Default: Profilo

  @override
  void initState() {
    super.initState();
    if (appState.isFirstLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWelcomeDialog();
      });
    }
  }

  // Dialog di benvenuto al primo avvio
  void _showWelcomeDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Benvenuto su Book Time! 📚'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Username:',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Es: mariorossi',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                appState.setUserName(name);
                Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B1FA2),
              foregroundColor: Colors.white,
            ),
            child: const Text('INIZIAMO!'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: appState.userName);
    final ImagePicker picker = ImagePicker();
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final hasImage = appState.profileImageBase64.isNotEmpty;
            return AlertDialog(
              title: const Text('Modifica Profilo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        try {
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 300,
                            maxHeight: 300,
                            imageQuality: 70,
                          );
                          if (image != null) {
                            final bytes = await image.readAsBytes();
                            final base64String = base64Encode(bytes);
                            appState.setProfileImage(base64String);
                            setStateDialog(() {});
                          }
                        } catch (e) {
                          debugPrint("Errore selezione immagine: $e");
                        }
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: const Color(0xFF7B1FA2),
                            backgroundImage: hasImage 
                                ? MemoryImage(base64Decode(appState.profileImageBase64))
                                : null,
                            child: hasImage
                                ? null
                                : const Icon(Icons.person, size: 40, color: Colors.white),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_a_photo, size: 18, color: Color(0xFF7B1FA2)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tocca l\'icona per cambiare foto',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.none,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'Es: mariorossi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ANNULLA'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      appState.setUserName(name);
                      Navigator.pop(dialogContext);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B1FA2),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('SALVA'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Impostazioni'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Lingua dei risultati:'),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: appState.languageCode,
                    items: const [
                      DropdownMenuItem(value: 'ita', child: Text('Italiano')),
                      DropdownMenuItem(value: 'eng', child: Text('English')),
                      DropdownMenuItem(value: 'spa', child: Text('Español')),
                      DropdownMenuItem(value: 'fre', child: Text('Français')),
                      DropdownMenuItem(value: 'ger', child: Text('Deutsch')),
                    ],
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        appState.setLanguageCode(newValue);
                        setStateDialog(() {});
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CHIUDI'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // ============================================
  // DETTAGLIO LIBRO — Bottom sheet con trama
  // ============================================
  Future<String> _fetchBookPlot(String title, String author) async {
    try {
      final searchResponse = await http.get(Uri.parse(
        'https://openlibrary.org/search.json?title=${Uri.encodeComponent(title)}&limit=1',
      ));
      if (searchResponse.statusCode == 200) {
        final data = json.decode(searchResponse.body);
        final docs = data['docs'] as List? ?? [];
        if (docs.isNotEmpty && docs[0]['key'] != null) {
          final bookKey = docs[0]['key'];
          final descResponse = await http.get(
            Uri.parse('https://openlibrary.org$bookKey.json'),
          );
          if (descResponse.statusCode == 200) {
            final descData = json.decode(descResponse.body);
            if (descData['description'] != null) {
              if (descData['description'] is String) {
                return descData['description'];
              } else if (descData['description'] is Map &&
                  descData['description']['value'] != null) {
                return descData['description']['value'];
              }
            }
          }
        }
      }
      return 'Nessuna trama disponibile.';
    } catch (e) {
      return 'Errore nel caricamento della trama.';
    }
  }

  void _showBookDetailSheet(Book book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        String plot = 'Caricamento trama...';
        bool hasFetched = false;

        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            if (!hasFetched) {
              hasFetched = true;
              _fetchBookPlot(book.title, book.author).then((fetchedPlot) {
                if (mounted) {
                  setStateSheet(() {
                    plot = fetchedPlot;
                  });
                }
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Copertina grande
                      if (book.coverUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            book.coverUrl!,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, st) => Container(
                              height: 200,
                              width: 130,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.book, size: 60, color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 200,
                          width: 130,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.book, size: 60, color: Colors.grey),
                        ),
                      const SizedBox(height: 16),
                      // Titolo
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          book.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7B1FA2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Autore
                      Text(
                        book.author,
                        style: const TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                      // Progresso (se in lettura)
                      if (book.totalPages > 0) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: book.progress,
                                  backgroundColor: Colors.grey[200],
                                  color: const Color(0xFF7B1FA2),
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${book.currentPage}/${book.totalPages}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(),
                      // Trama
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trama',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7B1FA2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: SingleChildScrollView(
                                child: Text(
                                  plot,
                                  style: const TextStyle(fontSize: 14),
                                  textAlign: TextAlign.justify,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================
  // TAB PROFILO — Profilo, statistiche e
  // liste libri orizzontali
  // ============================================
  Widget _buildProfileTab() {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, child) {
        return ResponsiveWrapper(
          maxWidth: 700,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // --- Card profilo utente ---
              GestureDetector(
                onTap: _showEditProfileDialog,
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF7B1FA2),
                        backgroundImage: appState.profileImageBase64.isNotEmpty
                            ? MemoryImage(base64Decode(appState.profileImageBase64))
                            : null,
                        child: appState.profileImageBase64.isNotEmpty
                            ? null
                            : const Icon(Icons.person, size: 35, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.userName.isNotEmpty
                                  ? appState.userName
                                  : 'Username',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '📚 Lettore appassionato',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit, color: Colors.grey, size: 20),
                    ],
                  ),
                ),
              ),

              // --- Sezione statistiche ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Libri letti',
                        '${appState.totalBooksRead}',
                        Icons.menu_book,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Tempo letto',
                        appState.formattedTotalTime,
                        Icons.timer,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==========================================
              // SEZIONE: Libri in lettura (orizzontale)
              // ==========================================
              _buildSectionHeader(
                '📖 In lettura',
                appState.booksReading.length,
                onTap: () => _openBookListPage(BookCategory.reading),
              ),
              _buildHorizontalBookList(
                appState.booksReading,
                emptyMessage: 'Nessun libro in lettura',
                showProgress: true,
              ),

              const SizedBox(height: 16),

              // ==========================================
              // SEZIONE: Libri da leggere (orizzontale)
              // ==========================================
              _buildSectionHeader(
                '📚 Da leggere',
                appState.booksToRead.length,
                onTap: () => _openBookListPage(BookCategory.toRead),
              ),
              _buildHorizontalBookList(
                appState.booksToRead,
                emptyMessage: 'Nessun libro da leggere',
              ),

              const SizedBox(height: 16),

              // ==========================================
              // SEZIONE: Libri letti (orizzontale)
              // ==========================================
              _buildSectionHeader(
                '✅ Letti',
                appState.booksRead.length,
                onTap: () => _openBookListPage(BookCategory.read),
              ),
              _buildHorizontalBookList(
                appState.booksRead,
                emptyMessage: 'Nessun libro completato',
              ),
            ],
          ),
        );
      },
    );
  }

  // Naviga alla pagina dettaglio di una sezione
  void _openBookListPage(BookCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookListPage(category: category),
      ),
    );
  }

  // ============================================
  // TAB ESPLORA — SearchPage con suggerimenti
  // ============================================
  Widget _buildExploreTab() {
    return const SearchPage();
  }

  // Header per le sezioni — tappabile per aprire la pagina dettaglio
  Widget _buildSectionHeader(String title, int count, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7B1FA2),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B1FA2),
                ),
              ),
            ),
            const Spacer(),
            if (onTap != null)
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF7B1FA2),
              ),
          ],
        ),
      ),
    );
  }

  // Lista orizzontale di copertine libri
  Widget _buildHorizontalBookList(
    List<Book> books, {
    required String emptyMessage,
    bool showProgress = false,
  }) {
    if (books.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: showProgress ? 210 : 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return _buildHorizontalBookCard(book, showProgress: showProgress);
        },
      ),
    );
  }

  // Card singola per la lista orizzontale — tappabile per dettagli
  Widget _buildHorizontalBookCard(Book book, {bool showProgress = false}) {
    return GestureDetector(
      onTap: () => _showBookDetailSheet(book),
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Copertina
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: book.coverUrl != null
                  ? Image.network(
                      book.coverUrl!,
                      height: 150,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 150,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.book, color: Colors.grey, size: 40),
                      ),
                    )
                  : Container(
                      height: 150,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.book, color: Colors.grey, size: 40),
                    ),
            ),
            const SizedBox(height: 4),
            // Titolo
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            // Barra progresso (solo per "In lettura")
            if (showProgress) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: book.progress,
                backgroundColor: Colors.grey[200],
                color: const Color(0xFF7B1FA2),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              Text(
                '${(book.progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Book Time',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showSettingsDialog,
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Tab 0: Profilo
          _buildProfileTab(),
          // Tab 1: Esplora
          _buildExploreTab(),
          // Tab 2: Timer
          const TimerPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profilo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Esplora',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Timer',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }

  // Widget per le singole statistiche
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF7B1FA2), size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7B1FA2),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
