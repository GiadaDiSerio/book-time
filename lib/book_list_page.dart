import 'book_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'responsive_wrapper.dart';
import 'rating_dialog.dart';

enum BookCategory { reading, toRead, read }

class BookListPage extends StatefulWidget {
  final BookCategory category;

  const BookListPage({super.key, required this.category});

  @override
  State<BookListPage> createState() => _BookListPageState();
}

class _BookListPageState extends State<BookListPage> {
  String get _title {
    switch (widget.category) {
      case BookCategory.reading:
        return '📖 In lettura';
      case BookCategory.toRead:
        return '📚 Da leggere';
      case BookCategory.read:
        return '✅ Letti';
    }
  }

  List<Book> get _books {
    switch (widget.category) {
      case BookCategory.reading:
        return appState.booksReading;
      case BookCategory.toRead:
        return appState.booksToRead;
      case BookCategory.read:
        return appState.booksRead;
    }
  }

  void _showUpdateProgressDialog(Book book) {
    final controller = TextEditingController(text: '${book.currentPage}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aggiorna "${book.title}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pagine totali: ${book.totalPages}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'A che pagina sei arrivato?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Es: ${book.totalPages}',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ANNULLA'),
          ),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(controller.text) ?? book.currentPage;
              final clampedPage = page.clamp(0, book.totalPages);
              bool completed = appState.updateReadingProgress(book.id, clampedPage);
              Navigator.pop(ctx);
              if (completed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '🎉 Complimenti! Hai finito "${book.title}"!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                showRatingDialog(context, book.title, (rating) {
                  if (rating > 0) appState.rateBook(book.id, rating);
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('SALVA'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, child) {
          final books = _books;
          if (books.isEmpty) {
            return const Center(
              child: Text(
                'Nessun libro in questa sezione',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          return ResponsiveWrapper(
            maxWidth: 700,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: books.length,
              itemBuilder: (context, index) => _buildBookCard(books[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookCard(Book book) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        onTap: () {
          if (widget.category == BookCategory.read) {
            showBookDetailSheet(context, book);
          }
        },
        onLongPress: () => _showBookActionsSheet(book),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Copertina
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: book.coverUrl != null
                  ? Image.network(
                      book.coverUrl!,
                      width: 80,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => _buildPlaceholderCover(ctx),
                    )
                  : _buildPlaceholderCover(context),
            ),
            const SizedBox(width: 16),
            // Dettagli
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  // Progresso per i libri in lettura
                  if (widget.category == BookCategory.reading) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: book.progress,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            color: Theme.of(context).colorScheme.primary,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${book.currentPage}/${book.totalPages}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showUpdateProgressDialog(book),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Aggiorna progresso'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  // Segno di completamento per libri letti
                  if (widget.category == BookCategory.read) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 4),
                        Text(
                          'Completato',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        showRatingDialog(context, book.title, (rating) {
                          appState.rateBook(book.id, rating);
                        });
                      },
                      child: Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < book.rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 24, // Leggermente più grandi
                          );
                        }),
                      ),
                    ),
                  ],
                  // Suggerimento per il long press
                  const SizedBox(height: 8),
                  Text(
                    'Tieni premuto per opzioni',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ============================================
  // Bottom sheet con azioni: Sposta / Elimina
  // ============================================
  void _showBookActionsSheet(Book book) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  book.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(height: 1),

              // --- Opzioni di spostamento (mostra solo le liste diverse dalla corrente) ---

              if (widget.category != BookCategory.toRead)
                ListTile(
                  leading: Icon(Icons.bookmark_border, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Sposta in "Da leggere"'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    appState.moveBookToToRead(book.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('📚 "${book.title}" spostato in "Da leggere"'),
                      ),
                    );
                  },
                ),

              if (widget.category != BookCategory.reading)
                ListTile(
                  leading: const Icon(Icons.menu_book, color: Colors.blue),
                  title: const Text('Sposta in "In lettura"'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showMoveToReadingDialog(book);
                  },
                ),

              if (widget.category != BookCategory.read)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                  title: const Text('Sposta in "Letti"'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showRatingDialog(context, book.title, (rating) {
                      appState.moveBookToRead(book.id, rating: rating);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ "${book.title}" spostato in "Letti"'),
                        ),
                      );
                    });
                  },
                ),

              const Divider(height: 1),

              // --- Elimina ---
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Elimina libro', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(book);
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Dialog per chiedere il numero di pagine quando si sposta in "In lettura"
  void _showMoveToReadingDialog(Book book) {
    final pagesController = TextEditingController(
      text: book.totalPages > 0 ? '${book.totalPages}' : '',
    );
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
                appState.moveBookToReading(book.id, pages);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📖 "${book.title}" spostato in "In lettura"'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('SPOSTA'),
          ),
        ],
      ),
    );
  }

  // Conferma eliminazione con SnackBar e possibilità di annullare
  void _confirmDelete(Book book) {
    // Salva i dati del libro per un eventuale undo
    final savedId = book.id;
    final savedTitle = book.title;
    final savedAuthor = book.author;
    final savedPages = book.totalPages;
    final savedCurrentPage = book.currentPage;
    final savedCoverUrl = book.coverUrl;
    final savedRating = book.rating;
    final savedCategory = widget.category;

    appState.removeBook(book.id);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars(); // Rimuove eventuali snackbar precedenti
    messenger.showSnackBar(
      SnackBar(
        content: Text('🗑️ "$savedTitle" eliminato'),
        behavior: SnackBarBehavior.floating, // Permette di scorrere per eliminarla facilmente
        action: SnackBarAction(
          label: 'ANNULLA',
          textColor: Colors.amber,
          onPressed: () {
            // Ripristina il libro nella lista originale con il suo ID originale
            switch (savedCategory) {
              case BookCategory.toRead:
                appState.addBookToRead(
                  savedTitle,
                  id: savedId,
                  author: savedAuthor,
                  totalPages: savedPages,
                  coverUrl: savedCoverUrl,
                );
                break;
              case BookCategory.reading:
                appState.addBookReading(
                  savedTitle,
                  id: savedId,
                  author: savedAuthor,
                  totalPages: savedPages,
                  coverUrl: savedCoverUrl,
                );
                // Ripristina anche il progresso
                if (savedCurrentPage > 0) {
                  appState.updateReadingProgress(savedId, savedCurrentPage);
                }
                break;
              case BookCategory.read:
                appState.addBookRead(
                  savedTitle,
                  id: savedId,
                  author: savedAuthor,
                  coverUrl: savedCoverUrl,
                  rating: savedRating,
                );
                break;
            }
          },
        ),
      ),
    );

    // Forza la chiusura dopo 3 secondi (ignora le impostazioni di accessibilità di Android)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        messenger.hideCurrentSnackBar();
      }
    });
  }


  Widget _buildPlaceholderCover(BuildContext context, {bool large = false}) {
    return Container(
      width: large ? 120 : 80,
      height: large ? 180 : 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.book, size: 40, color: Colors.grey),
    );
  }
}
