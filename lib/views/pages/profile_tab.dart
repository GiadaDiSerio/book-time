import '../../models/book.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../controllers/app_controller.dart';
import '../widgets/responsive_wrapper.dart';
import '../pages/book_list_page.dart';
import '../dialogs/book_detail_sheet.dart';

/// Tab del profilo: mostra il profilo utente, le statistiche di lettura
/// e le tre liste di libri in formato orizzontale.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = context.watch<AppController>();
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
                      _buildSafeAvatar(context, appController, 30, 35),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appController.userName.isNotEmpty
                                  ? appController.userName
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
                        '${appController.totalBooksRead}',
                        Icons.menu_book,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Tempo letto',
                        appController.formattedTotalTime,
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
                'In lettura',
                appController.booksReading.length,
                onTap: () => _openBookListPage(context, BookCategory.reading),
              ),
              _buildHorizontalBookList(
                context,
                appController.booksReading,
                emptyMessage: 'Nessun libro in lettura',
                showProgress: true,
              ),

              const SizedBox(height: 16),

              // ==========================================
              // SEZIONE: Libri da leggere (orizzontale)
              // ==========================================
              _buildSectionHeader(
                context,
                'Da leggere',
                appController.booksToRead.length,
                onTap: () => _openBookListPage(context, BookCategory.toRead),
              ),
              _buildHorizontalBookList(
                context,
                appController.booksToRead,
                emptyMessage: 'Nessun libro da leggere',
              ),

              const SizedBox(height: 16),

              // ==========================================
              // SEZIONE: Libri letti (orizzontale)
              // ==========================================
              _buildSectionHeader(
                context,
                'Letti',
                appController.booksRead.length,
                onTap: () => _openBookListPage(context, BookCategory.read),
              ),
              _buildHorizontalBookList(
                context,
                appController.booksRead,
                emptyMessage: 'Nessun libro completato',
              ),
            ],
          ),
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

  Widget _buildSafeAvatar(BuildContext context, AppController appController, double radius, double iconSize) {
    final hasImage = appController.profileImagePath.isNotEmpty;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary,
      ),
      child: ClipOval(
        child: hasImage
            ? Image.file(
                File(appController.profileImagePath),
                fit: BoxFit.cover,
                errorBuilder: (ctx, error, stackTrace) {
                  // Ripristina l'immagine di default se il file è corrotto o eliminato
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      context.read<AppController>().setProfileImagePath('');
                    }
                  });
                  return Icon(Icons.person, size: iconSize, color: Colors.white);
                },
              )
            : Icon(Icons.person, size: iconSize, color: Colors.white),
      ),
    );
  }


  // ============================================
  // Dialog modifica profilo (nome + foto)
  // ============================================
  void _showEditProfileDialog(BuildContext context) {
    final appController = context.read<AppController>();
    final nameController = TextEditingController(text: appController.userName);
    final ImagePicker picker = ImagePicker();
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            final appController = dialogCtx.watch<AppController>();
            return AlertDialog(
              title: const Text('Modifica Profilo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _showProfileImageOptions(dialogCtx, picker, setStateDialog),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          _buildSafeAvatar(dialogCtx, appController, 40, 40),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.add_a_photo, size: 18, color: Theme.of(dialogCtx).colorScheme.primary),
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
                      dialogCtx.read<AppController>().setUserName(name);
                      Navigator.pop(dialogContext);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(dialogCtx).colorScheme.primary,
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

  void _showProfileImageOptions(BuildContext context, ImagePicker picker, StateSetter setStateDialog) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Scegli dalla galleria'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 300,
                      maxHeight: 300,
                      imageQuality: 70,
                    );
                    if (image != null) {
                      final appDir = await getApplicationDocumentsDirectory();
                      final fileName = 'profile_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
                      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');
                      
                      if (context.mounted) {
                        context.read<AppController>().setProfileImagePath(savedImage.path);
                      }
                      setStateDialog(() {});
                    }
                  } catch (e) {
                    debugPrint("Errore selezione immagine: $e");
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Impossibile caricare l'immagine. Riprova.")),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Rimuovi foto', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<AppController>().setProfileImagePath('');
                  setStateDialog(() {});
                },
              ),
            ],
          ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
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
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
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
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: showProgress ? 210 : 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: books.length > 5 ? 5 : books.length,
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            // Barra progresso (solo per "In lettura")
            if (showProgress) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: book.progress,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                color: Theme.of(context).colorScheme.primary,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              Text(
                '${(book.progress * 100).toInt()}%',
                style: TextStyle(fontSize: 10, color: Colors.grey),
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
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
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
