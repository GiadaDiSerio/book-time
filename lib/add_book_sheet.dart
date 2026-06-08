import 'package:flutter/material.dart';
import 'app_state.dart';
import 'book_utils.dart';
import 'rating_dialog.dart';

/// Mostra un bottom sheet per aggiungere un libro alle liste dell'utente.
/// [parentContext] è il contesto del widget chiamante, usato per mostrare
/// i dialoghi successivi dopo la chiusura del bottom sheet.
void showAddBookSheet(
  BuildContext parentContext, {
  required String title,
  required String authors,
  String? imageUrl,
  String? bookKey,
  VoidCallback? onBookAdded,
}) {
  showModalBottomSheet(
    context: parentContext,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      bool isLoadingPlot = true;
      String plot = 'Caricamento trama...';

      return StatefulBuilder(
        builder: (ctx, setStateBottomSheet) {
          // Fetch trama al primo avvio
          if (isLoadingPlot) {
            isLoadingPlot = false;
            fetchBookPlotByKey(bookKey).then((fetchedPlot) {
              setStateBottomSheet(() {
                plot = fetchedPlot;
              });
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
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
                      maxHeight: MediaQuery.of(ctx).size.height * 0.3,
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
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
                  // Opzione: Da leggere
                  ListTile(
                    leading: const Icon(Icons.bookmark_border, color: Color(0xFF7B1FA2)),
                    title: const Text('Aggiungi a "Da leggere"'),
                    onTap: () {
                      final messenger = ScaffoldMessenger.of(ctx);
                      appState.addBookToRead(title, author: authors, coverUrl: imageUrl);
                      Navigator.pop(ctx);
                      messenger.showSnackBar(const SnackBar(content: Text('Aggiunto a "Da leggere"')));
                      onBookAdded?.call();
                    },
                  ),
                  // Opzione: In lettura
                  ListTile(
                    leading: const Icon(Icons.menu_book, color: Colors.blue),
                    title: const Text('Aggiungi a "In lettura"'),
                    onTap: () {
                      final pageMessenger = ScaffoldMessenger.of(ctx);
                      Navigator.pop(ctx); // Chiudi il bottom sheet
                      final pagesController = TextEditingController();
                      showDialog(
                        context: parentContext,
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
                                  onBookAdded?.call();
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
                  // Opzione: Letto
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                    title: const Text('Aggiungi come "Letto"'),
                    onTap: () {
                      final messenger = ScaffoldMessenger.of(ctx);
                      Navigator.pop(ctx); // Chiudi il bottom sheet
                      showRatingDialog(parentContext, title, (rating) {
                        appState.addBookRead(title, author: authors, coverUrl: imageUrl, rating: rating);
                        messenger.showSnackBar(const SnackBar(content: Text('Aggiunto ai "Letti"!')));
                        onBookAdded?.call();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
