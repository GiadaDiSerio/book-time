import 'package:flutter/material.dart';
import 'app_state.dart';
import 'responsive_wrapper.dart';

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
              appState.updateReadingProgress(book.title, clampedPage);
              Navigator.pop(ctx);
              if (clampedPage >= book.totalPages) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '🎉 Complimenti! Hai finito "${book.title}"!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B1FA2),
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
                      width: 70,
                      height: 105,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => _buildPlaceholderCover(),
                    )
                  : _buildPlaceholderCover(),
            ),
            const SizedBox(width: 16),
            // Dettagli
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: const TextStyle(
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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showUpdateProgressDialog(book),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Aggiorna progresso'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7B1FA2),
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
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      width: 70,
      height: 105,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.book, size: 40, color: Colors.grey),
    );
  }
}
