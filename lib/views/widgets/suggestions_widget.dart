import 'package:flutter/material.dart';
import '../dialogs/add_book_sheet.dart';

class SuggestionsWidget extends StatefulWidget {
  final String title;
  final List<dynamic> suggestions;
  final bool isLoading;

  const SuggestionsWidget({
    super.key,
    required this.title,
    required this.suggestions,
    this.isLoading = false,
  });

  @override
  State<SuggestionsWidget> createState() => _SuggestionsWidgetState();
}

class _SuggestionsWidgetState extends State<SuggestionsWidget> {
  List<dynamic> _localSuggestions = [];

  @override
  void initState() {
    super.initState();
    _localSuggestions = List.from(widget.suggestions);
  }

  @override
  void didUpdateWidget(covariant SuggestionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestions != widget.suggestions) {
      _localSuggestions = List.from(widget.suggestions);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_localSuggestions.isEmpty) {
      return const SizedBox.shrink(); // Non mostrare nulla se non ci sono suggerimenti
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: _localSuggestions.length,
            itemBuilder: (context, index) {
              final book = _localSuggestions[index];
              final coverId = book['cover_i'];
              final imageUrl = 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';
              final title = book['title'] ?? 'Sconosciuto';
              final authors = (book['author_name'] as List?)?.join(', ') ?? 'Autore sconosciuto';
              final bookKey = book['key'];

              return GestureDetector(
                onTap: () => showAddBookSheet(
                  context,
                  title: title,
                  authors: authors,
                  imageUrl: imageUrl,
                  bookKey: bookKey,
                  onBookAdded: () {
                    setState(() {
                      _localSuggestions.remove(book);
                    });
                  },
                ),
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              height: 190,
                              width: 130,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 190,
                                width: 130,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.book, color: Colors.grey),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary, 
                                  width: 1.5
                                ),
                              ),
                              child: Icon(
                                Icons.add,
                                color: Theme.of(context).colorScheme.primary,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(),
      ],
    );
  }
}
