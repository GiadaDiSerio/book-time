import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import '../services/storage_service.dart';
import '../models/book.dart';

class AppController extends ChangeNotifier {

  // --- PROFILO UTENTE ---
  String _userName = '';
  String _profileImagePath = '';

  // --- IMPOSTAZIONI ---
  String _languageCode = 'ita';
  ThemeMode _themeMode = ThemeMode.system;

  // --- STATISTICHE ---
  int _totalReadingSeconds = 0;

  // --- LISTE LIBRI ---
  List<Book> _booksToRead = [];
  List<Book> _booksReading = [];
  List<Book> _booksRead = [];


  // --- GETTERS ---
  String get userName => _userName;
  String get profileImagePath => _profileImagePath;
  String get languageCode => _languageCode;
  ThemeMode get themeMode => _themeMode;
  bool get isFirstLaunch => _userName.isEmpty;
  int get totalBooksRead => _booksRead.length;
  int get totalReadingSeconds => _totalReadingSeconds;
  
  List<Book> get booksToRead => List.unmodifiable(_booksToRead);
  List<Book> get booksReading => List.unmodifiable(_booksReading);
  List<Book> get booksRead => List.unmodifiable(_booksRead);
  

  // --- PERSISTENZA DEI DATI ---

  Future<void> loadState() async {
    _userName = await storageService.getString('userName') ?? '';
    _profileImagePath = await storageService.getString('profileImagePath') ?? '';
    
    final savedLang = await storageService.getString('languageCode');
    if (savedLang != null) {
      _languageCode = savedLang;
    } else {
      final systemLoc = ui.PlatformDispatcher.instance.locale.languageCode;
      _languageCode = _mapLanguageToOpenLibrary(systemLoc);
    }

    final savedTheme = await storageService.getString('themeMode');
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    _totalReadingSeconds = await storageService.getInt('totalReadingSeconds') ?? 0;

    final String? booksToReadJson = await storageService.getString('booksToRead');
    if (booksToReadJson != null) {
      final List<dynamic> decoded = jsonDecode(booksToReadJson);
      _booksToRead = decoded.map((item) => Book.fromJson(item)).toList();
    }

    final String? booksReadingJson = await storageService.getString('booksReading');
    if (booksReadingJson != null) {
      final List<dynamic> decoded = jsonDecode(booksReadingJson);
      _booksReading = decoded.map((item) => Book.fromJson(item)).toList();
    }

    final String? booksReadJson = await storageService.getString('booksRead');
    if (booksReadJson != null) {
      final List<dynamic> decoded = jsonDecode(booksReadJson);
      _booksRead = decoded.map((item) => Book.fromJson(item)).toList();
    }

    notifyListeners();
  }

  Future<void> saveState() async {
    await storageService.saveString('userName', _userName);
    await storageService.saveString('profileImagePath', _profileImagePath);
    await storageService.saveString('languageCode', _languageCode);
    
    String themeStr = 'system';
    if (_themeMode == ThemeMode.light) themeStr = 'light';
    if (_themeMode == ThemeMode.dark) themeStr = 'dark';
    await storageService.saveString('themeMode', themeStr);
    await storageService.saveInt('totalReadingSeconds', _totalReadingSeconds);

    await storageService.saveString('booksToRead', jsonEncode(_booksToRead.map((b) => b.toJson()).toList()));
    await storageService.saveString('booksReading', jsonEncode(_booksReading.map((b) => b.toJson()).toList()));
    await storageService.saveString('booksRead', jsonEncode(_booksRead.map((b) => b.toJson()).toList()));
  }

  // --- METODI PER AGGIORNARE LO STATO ---

  void setUserName(String name) {
    _userName = name;
    saveState();
    notifyListeners();
  }
  
  void setProfileImagePath(String path) {
    _profileImagePath = path;
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

  // Controlla se un libro è già presente in una qualsiasi lista (per titolo, usato solo all'aggiunta)
  bool _isBookInAnyList(String title) {
    return _booksToRead.any((b) => b.title == title) ||
           _booksReading.any((b) => b.title == title) ||
           _booksRead.any((b) => b.title == title);
  }

  void addBookToRead(String title, {String? id, String author = 'Autore sconosciuto', int totalPages = 0, String? coverUrl}) {
    // Controlliamo che non sia già presente in nessuna lista
    if (_isBookInAnyList(title)) return;
    _booksToRead.add(Book(id: id, title: title, author: author, totalPages: totalPages, coverUrl: coverUrl));
    saveState();
    notifyListeners();
  }

  void addBookReading(String title, {String? id, String author = 'Autore sconosciuto', required int totalPages, String? coverUrl}) {
    // Controlliamo che non sia già presente in nessuna lista
    if (_isBookInAnyList(title)) return;
    _booksReading.add(Book(id: id, title: title, author: author, totalPages: totalPages, coverUrl: coverUrl));
    saveState();
    notifyListeners();
  }

  void addBookRead(String title, {String? id, String author = 'Autore sconosciuto', String? coverUrl, int rating = 0}) {
    // Controlliamo che non sia già presente in nessuna lista
    if (_isBookInAnyList(title)) return;
    _booksRead.add(Book(id: id, title: title, author: author, totalPages: 0, currentPage: 0, coverUrl: coverUrl, rating: rating));
    saveState();
    notifyListeners();
  }

  void rateBook(String bookId, int rating) {
    final index = _booksRead.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      _booksRead[index].rating = rating;
      saveState();
      notifyListeners();
      return;
    }
    final readingIndex = _booksReading.indexWhere((b) => b.id == bookId);
    if (readingIndex != -1) {
      _booksReading[readingIndex].rating = rating;
      saveState();
      notifyListeners();
      return;
    }
  }

  // Aggiorna il progresso di lettura di un libro "In lettura"
  bool updateReadingProgress(String bookId, int newCurrentPage) {
    final index = _booksReading.indexWhere((b) => b.id == bookId);
    if (index == -1) return false;

    final book = _booksReading[index];
    book.currentPage = newCurrentPage;
    bool completedNow = false;

    // Se ha finito tutte le pagine, spostiamo il libro nei "Letti"!
    if (book.isCompleted) {
      _booksReading.removeAt(index);
      _booksRead.add(book);
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

  // --- ELIMINAZIONE LIBRI ---

  /// Rimuove un libro da qualsiasi lista in cui si trova
  void removeBook(String bookId) {
    _booksToRead.removeWhere((b) => b.id == bookId);
    _booksReading.removeWhere((b) => b.id == bookId);
    _booksRead.removeWhere((b) => b.id == bookId);
    saveState();
    notifyListeners();
  }

  // --- SPOSTAMENTO LIBRI TRA LISTE ---

  /// Helper: trova un libro in qualsiasi lista, lo rimuove e lo restituisce
  Book? _findAndRemoveBook(String bookId) {
    int index;

    index = _booksToRead.indexWhere((b) => b.id == bookId);
    if (index != -1) return _booksToRead.removeAt(index);

    index = _booksReading.indexWhere((b) => b.id == bookId);
    if (index != -1) return _booksReading.removeAt(index);

    index = _booksRead.indexWhere((b) => b.id == bookId);
    if (index != -1) return _booksRead.removeAt(index);

    return null;
  }

  /// Sposta un libro nella lista "Da leggere"
  void moveBookToToRead(String bookId) {
    final book = _findAndRemoveBook(bookId);
    if (book != null) {
      _booksToRead.add(Book(
        id: book.id,
        title: book.title,
        author: book.author,
        totalPages: book.totalPages,
        coverUrl: book.coverUrl,
      ));
      saveState();
      notifyListeners();
    }
  }

  /// Sposta un libro nella lista "In lettura" (richiede il numero di pagine)
  void moveBookToReading(String bookId, int totalPages) {
    final book = _findAndRemoveBook(bookId);
    if (book != null) {
      _booksReading.add(Book(
        id: book.id,
        title: book.title,
        author: book.author,
        totalPages: totalPages,
        coverUrl: book.coverUrl,
      ));
      saveState();
      notifyListeners();
    }
  }

  /// Sposta un libro nella lista "Letti"
  void moveBookToRead(String bookId, {int rating = 0}) {
    final book = _findAndRemoveBook(bookId);
    if (book != null) {
      _booksRead.add(Book(
        id: book.id,
        title: book.title,
        author: book.author,
        totalPages: book.totalPages,
        currentPage: book.totalPages,
        coverUrl: book.coverUrl,
        rating: rating,
      ));
      saveState();
      notifyListeners();
    }
  }
}
