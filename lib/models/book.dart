import 'package:uuid/uuid.dart';

class Book {
  final String id; // Identificatore univoco del libro
  final String title;
  final String author;
  final int totalPages;
  int currentPage; // La pagina a cui sei arrivato
  final String? coverUrl;
  int rating;

  Book({
    String? id,
    required this.title,
    this.author = 'Autore sconosciuto',
    required this.totalPages,
    this.currentPage = 0,
    this.coverUrl,
    this.rating = 0,
  }) : id = id ?? const Uuid().v4();

  // Percentuale di completamento (da 0.0 a 1.0)
  double get progress => totalPages > 0 ? currentPage / totalPages : 0.0;

  // Controlla se il libro è stato completato
  bool get isCompleted => currentPage >= totalPages;

  // Per salvare i dati in memoria
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'totalPages': totalPages,
      'currentPage': currentPage,
      'coverUrl': coverUrl,
      'rating': rating,
    };
  }

  // Per caricare i dati dalla memoria
  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'], // Se manca (dati vecchi), ne genera uno nuovo automaticamente
      title: json['title'],
      author: json['author'] ?? 'Autore sconosciuto',
      totalPages: json['totalPages'] ?? 0,
      currentPage: json['currentPage'] ?? 0,
      coverUrl: json['coverUrl'],
      rating: json['rating'] ?? 0,
    );
  }
}
