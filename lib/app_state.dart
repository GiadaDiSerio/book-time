import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

class Book {
  final String title;
  final String author;
  final int totalPages;
  int currentPage; // La pagina a cui sei arrivato
  final String? coverUrl;
  int rating;

  Book({
    required this.title,
    this.author = 'Autore sconosciuto',
    required this.totalPages,
    this.currentPage = 0,
    this.coverUrl,
    this.rating = 0,
  });

  // Percentuale di completamento (da 0.0 a 1.0)
  double get progress => totalPages > 0 ? currentPage / totalPages : 0.0;

  // Controlla se il libro è stato completato
  bool get isCompleted => currentPage >= totalPages;

  // Per salvare i dati in memoria
  Map<String, dynamic> toJson() {
    return {
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
      title: json['title'],
      author: json['author'] ?? 'Autore sconosciuto',
      totalPages: json['totalPages'] ?? 0,
      currentPage: json['currentPage'] ?? 0,
      coverUrl: json['coverUrl'],
      rating: json['rating'] ?? 0,
    );
  }
}

// Classe singleton globale per lo stato
class AppState extends ChangeNotifier {
  // Istanza singleton per potervi accedere ovunque facilmente senza provider (vista la semplicità dell'app)
  static final AppState _instance = AppState._internal();
  
  factory AppState() {
    return _instance;
  }
  
  AppState._internal();

  // --- PROFILO UTENTE ---
  String _userName = '';
  String _profileImageBase64 = '';

  // --- IMPOSTAZIONI ---
  String _languageCode = 'ita';
  ThemeMode _themeMode = ThemeMode.system;

  // --- STATISTICHE ---
  int _totalBooksRead = 0;
  int _totalReadingSeconds = 0;

  // --- LISTE LIBRI ---
  List<Book> _booksToRead = [];
  List<Book> _booksReading = [];
  List<Book> _booksRead = [];


  // --- GETTERS ---
  String get userName => _userName;
  String get profileImageBase64 => _profileImageBase64;
  String get languageCode => _languageCode;
  ThemeMode get themeMode => _themeMode;
  bool get isFirstLaunch => _userName.isEmpty;
  int get totalBooksRead => _totalBooksRead;
  int get totalReadingSeconds => _totalReadingSeconds;
  
  List<Book> get booksToRead => List.unmodifiable(_booksToRead);
  List<Book> get booksReading => List.unmodifiable(_booksReading);
  List<Book> get booksRead => List.unmodifiable(_booksRead);
  

  // --- PERSISTENZA DEI DATI ---

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    
    _userName = prefs.getString('userName') ?? '';
    _profileImageBase64 = prefs.getString('profileImageBase64') ?? '';
    
    final savedLang = prefs.getString('languageCode');
    if (savedLang != null) {
      _languageCode = savedLang;
    } else {
      final systemLoc = ui.PlatformDispatcher.instance.locale.languageCode;
      _languageCode = _mapLanguageToOpenLibrary(systemLoc);
    }

    final savedTheme = prefs.getString('themeMode');
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    _totalBooksRead = prefs.getInt('totalBooksRead') ?? 0;
    _totalReadingSeconds = prefs.getInt('totalReadingSeconds') ?? 0;

    final String? booksToReadJson = prefs.getString('booksToRead');
    if (booksToReadJson != null) {
      final List<dynamic> decoded = jsonDecode(booksToReadJson);
      _booksToRead = decoded.map((item) => Book.fromJson(item)).toList();
    }

    final String? booksReadingJson = prefs.getString('booksReading');
    if (booksReadingJson != null) {
      final List<dynamic> decoded = jsonDecode(booksReadingJson);
      _booksReading = decoded.map((item) => Book.fromJson(item)).toList();
    }

    final String? booksReadJson = prefs.getString('booksRead');
    if (booksReadJson != null) {
      final List<dynamic> decoded = jsonDecode(booksReadJson);
      _booksRead = decoded.map((item) => Book.fromJson(item)).toList();
    }



    notifyListeners();
  }

  Future<void> saveState() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('userName', _userName);
    await prefs.setString('profileImageBase64', _profileImageBase64);
    await prefs.setString('languageCode', _languageCode);
    
    String themeStr = 'system';
    if (_themeMode == ThemeMode.light) themeStr = 'light';
    if (_themeMode == ThemeMode.dark) themeStr = 'dark';
    await prefs.setString('themeMode', themeStr);
    await prefs.setInt('totalBooksRead', _totalBooksRead);
    await prefs.setInt('totalReadingSeconds', _totalReadingSeconds);

    await prefs.setString('booksToRead', jsonEncode(_booksToRead.map((b) => b.toJson()).toList()));
    await prefs.setString('booksReading', jsonEncode(_booksReading.map((b) => b.toJson()).toList()));
    await prefs.setString('booksRead', jsonEncode(_booksRead.map((b) => b.toJson()).toList()));

  }

  // --- METODI PER AGGIORNARE LO STATO ---

  void setUserName(String name) {
    _userName = name;
    saveState();
    notifyListeners();
  }
  
  void setProfileImage(String base64Image) {
    _profileImageBase64 = base64Image;
    saveState();
    notifyListeners();
  }

  void setLanguageCode(String newCode) {
    _languageCode = newCode;
    saveState();
    notifyListeners();
  }

  void setThemeMode(ThemeMode newMode) {
    _themeMode = newMode;
    saveState();
    notifyListeners();
  }

  String _mapLanguageToOpenLibrary(String systemCode) {
    switch (systemCode.toLowerCase()) {
      case 'it': return 'ita';
      case 'en': return 'eng';
      case 'es': return 'spa';
      case 'fr': return 'fre';
      case 'de': return 'ger';
      default: return 'eng'; // Fallback
    }
  }
  
  void addReadingTime(int seconds) {
    _totalReadingSeconds += seconds;
    


    saveState();
    notifyListeners(); // Avvisa l'interfaccia di aggiornarsi
  }

  // Controlla se un libro è già presente in una qualsiasi lista
  bool _isBookInAnyList(String title) {
    return _booksToRead.any((b) => b.title == title) ||
           _booksReading.any((b) => b.title == title) ||
           _booksRead.any((b) => b.title == title);
  }

  void addBookToRead(String title, {String author = 'Autore sconosciuto', int totalPages = 0, String? coverUrl}) {
    // Controlliamo che non sia già presente in nessuna lista
    if (_isBookInAnyList(title)) return;
    _booksToRead.add(Book(title: title, author: author, totalPages: totalPages, coverUrl: coverUrl));
    saveState();
    notifyListeners();
  }

  void addBookReading(String title, {String author = 'Autore sconosciuto', required int totalPages, String? coverUrl}) {
    // Controlliamo che non sia già presente in nessuna lista
    if (_isBookInAnyList(title)) return;
    _booksReading.add(Book(title: title, author: author, totalPages: totalPages, coverUrl: coverUrl));
    saveState();
    notifyListeners();
  }

  void addBookRead(String title, {String author = 'Autore sconosciuto', String? coverUrl, int rating = 0}) {
    // Controlliamo che non sia già presente in nessuna lista
    if (_isBookInAnyList(title)) return;
    _booksRead.add(Book(title: title, author: author, totalPages: 0, currentPage: 0, coverUrl: coverUrl, rating: rating));
    _totalBooksRead++; // Incrementa la statistica!
    saveState();
    notifyListeners();
  }

  void rateBook(String title, int rating) {
    final index = _booksRead.indexWhere((b) => b.title == title);
    if (index != -1) {
      _booksRead[index].rating = rating;
      saveState();
      notifyListeners();
      return;
    }
    final readingIndex = _booksReading.indexWhere((b) => b.title == title);
    if (readingIndex != -1) {
      _booksReading[readingIndex].rating = rating;
      saveState();
      notifyListeners();
      return;
    }
  }

  // Aggiorna il progresso di lettura di un libro "In lettura"
  bool updateReadingProgress(String title, int newCurrentPage) {
    final index = _booksReading.indexWhere((b) => b.title == title);
    if (index == -1) return false;

    final book = _booksReading[index];
    book.currentPage = newCurrentPage;
    bool completedNow = false;

    // Se ha finito tutte le pagine, spostiamo il libro nei "Letti"!
    if (book.isCompleted) {
      _booksReading.removeAt(index);
      _booksRead.add(book);
      _totalBooksRead++;
      completedNow = true;
    }

    saveState();
    notifyListeners();
    return completedNow;
  }
  
  // Metodo per formattare i secondi totali in hh:mm o simile
  String get formattedTotalTime {
    int hours = _totalReadingSeconds ~/ 3600;
    int minutes = (_totalReadingSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

// Creiamo un'istanza accessibile a tutti
final appState = AppState();
