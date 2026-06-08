import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'app_state.dart';
import 'responsive_wrapper.dart';
import 'book_list_page.dart';
import 'book_detail_sheet.dart';

/// Tab del profilo: mostra il profilo utente, le statistiche di lettura
/// e le tre liste di libri in formato orizzontale.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
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
                onTap: () => _showEditProfileDialog(context),
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
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
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.grey[400] 
                                    : Colors.black87,
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
                        context,
                        'Libri letti',
                        '${appState.totalBooksRead}',
                        Icons.menu_book,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context,
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
                context,
                '📖 In lettura',
                appState.booksReading.length,
                onTap: () => _openBookListPage(context, BookCategory.reading),
              ),
              _buildHorizontalBookList(
                context,
                appState.booksReading,
                emptyMessage: 'Nessun libro in lettura',
                showProgress: true,
              ),

              const SizedBox(height: 16),

              // ==========================================
              // SEZIONE: Libri da leggere (orizzontale)
              // ==========================================
              _buildSectionHeader(
                context,
                '📚 Da leggere',
                appState.booksToRead.length,
                onTap: () => _openBookListPage(context, BookCategory.toRead),
              ),
              _buildHorizontalBookList(
                context,
                appState.booksToRead,
                emptyMessage: 'Nessun libro da leggere',
              ),

              const SizedBox(height: 16),

              // ==========================================
              // SEZIONE: Libri letti (orizzontale)
              // ==========================================
              _buildSectionHeader(
                context,
                '✅ Letti',
                appState.booksRead.length,
                onTap: () => _openBookListPage(context, BookCategory.read),
              ),
              _buildHorizontalBookList(
                context,
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
  void _openBookListPage(BuildContext context, BookCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookListPage(category: category),
      ),
    );
  }

  // ============================================
  // Dialog modifica profilo (nome + foto)
  // ============================================
  void _showEditProfileDialog(BuildContext context) {
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

  // Header per le sezioni — tappabile per aprire la pagina dettaglio
  Widget _buildSectionHeader(BuildContext context, String title, int count, {VoidCallback? onTap}) {
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
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
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
    BuildContext context,
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
          return _buildHorizontalBookCard(context, book, showProgress: showProgress);
        },
      ),
    );
  }

  // Card singola per la lista orizzontale — tappabile per dettagli
  Widget _buildHorizontalBookCard(BuildContext context, Book book, {bool showProgress = false}) {
    return GestureDetector(
      onTap: () => showBookDetailSheet(context, book),
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
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.book, color: Colors.grey, size: 40),
                      ),
                    )
                  : Container(
                      height: 150,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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

  // Widget per le singole statistiche
  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
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
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
