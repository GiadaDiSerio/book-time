import 'package:flutter/material.dart';
import 'app_state.dart';
import 'book_utils.dart';

/// Mostra un bottom sheet con i dettagli di un libro: copertina, titolo,
/// autore, progresso (se in lettura), rating (se letto) e trama.
/// Questo widget è condiviso tra la HomePage e la BookListPage.
void showBookDetailSheet(BuildContext context, Book book) {
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
            fetchBookPlot(book.title, book.author).then((fetchedPlot) {
              if (ctx.mounted) {
                setStateSheet(() {
                  plot = fetchedPlot;
                });
              }
            });
          }

          final isRead = appState.booksRead.any((b) => b.title == book.title);

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
                        color: Theme.of(ctx).colorScheme.outlineVariant,
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
                          errorBuilder: (ctx, err, st) => _buildPlaceholderCover(ctx),
                        ),
                      )
                    else
                      _buildPlaceholderCover(ctx),
                    const SizedBox(height: 16),
                    // Titolo
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        book.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Autore
                    Text(
                      book.author,
                      style: TextStyle(
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
                                backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                                color: Theme.of(ctx).colorScheme.primary,
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
                      ),
                    ],
                    // Rating (se letto)
                    if (isRead) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'La tua recensione',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              index < book.rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 40,
                            ),
                            onPressed: () {
                              appState.rateBook(book.title, index + 1);
                              setStateSheet(() {});
                            },
                          );
                        }),
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
                          Text(
                            'Trama',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(ctx).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: SingleChildScrollView(
                              child: Text(
                                plot,
                                style: TextStyle(fontSize: 14),
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

Widget _buildPlaceholderCover(BuildContext context) {
  return Container(
    height: 200,
    width: 130,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.book, size: 60, color: Colors.grey),
  );
}
