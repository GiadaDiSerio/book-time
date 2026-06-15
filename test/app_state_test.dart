import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:book_time/controllers/app_controller.dart';
import 'package:flutter/material.dart';

void main() {
  late AppController appState;

  setUp(() async {
    // Inizializza SharedPreferences con valori vuoti per isolare i test
    SharedPreferences.setMockInitialValues({});
    appState = AppController();
    await appState.loadState();
    
    // Pulisce lo stato del singleton prima di ogni test
    // Poiché non c'è un metodo clear, rimuoviamo tutti i libri manualmente
    final allBookIds = [
      ...appState.booksToRead.map((b) => b.id),
      ...appState.booksReading.map((b) => b.id),
      ...appState.booksRead.map((b) => b.id),
    ];
    for (var id in allBookIds) {
      appState.removeBook(id);
    }
    appState.setUserName('');
  });

  group('AppController Tests', () {
    test('Aggiunta libro a "Da leggere"', () {
      appState.addBookToRead('Il Signore degli Anelli', author: 'J.R.R. Tolkien');
      
      expect(appState.booksToRead.length, 1);
      expect(appState.booksToRead.first.title, 'Il Signore degli Anelli');
      expect(appState.booksToRead.first.author, 'J.R.R. Tolkien');
    });

    test('Deduplicazione libro (non permette aggiunta duplicati per titolo)', () {
      appState.addBookToRead('1984', author: 'George Orwell');
      appState.addBookReading('1984', totalPages: 300);
      appState.addBookRead('1984');
      
      expect(appState.booksToRead.length, 1);
      expect(appState.booksReading.length, 0);
      expect(appState.booksRead.length, 0);
    });

    test('Aggiunta e aggiornamento progresso libro "In lettura"', () {
      appState.addBookReading('Dune', author: 'Frank Herbert', totalPages: 500);
      
      expect(appState.booksReading.length, 1);
      final book = appState.booksReading.first;
      
      // Aggiorna pagina
      final isCompleted = appState.updateReadingProgress(book.id, 250);
      expect(isCompleted, false);
      expect(appState.booksReading.first.currentPage, 250);
      expect(appState.booksReading.first.progress, 0.5); // 250/500
    });

    test('Completamento libro "In lettura" lo sposta in "Letti"', () {
      appState.addBookReading('Fondazione', author: 'Isaac Asimov', totalPages: 200);
      final book = appState.booksReading.first;
      
      final isCompleted = appState.updateReadingProgress(book.id, 200);
      expect(isCompleted, true);
      
      expect(appState.booksReading.length, 0);
      expect(appState.booksRead.length, 1);
      expect(appState.booksRead.first.title, 'Fondazione');
      expect(appState.booksRead.first.isCompleted, true);
    });

    test('Spostamento libro tra liste', () {
      appState.addBookToRead('Il Nome della Rosa');
      final book = appState.booksToRead.first;
      
      // Sposta in lettura
      appState.moveBookToReading(book.id, 500);
      expect(appState.booksToRead.length, 0);
      expect(appState.booksReading.length, 1);
      expect(appState.booksReading.first.totalPages, 500);
      
      // Sposta in letti
      appState.moveBookToRead(book.id, rating: 5);
      expect(appState.booksReading.length, 0);
      expect(appState.booksRead.length, 1);
      expect(appState.booksRead.first.rating, 5);
      expect(appState.booksRead.first.currentPage, 500); // Viene completato
      
      // Ri-sposta in da leggere
      appState.moveBookToToRead(book.id);
      expect(appState.booksRead.length, 0);
      expect(appState.booksToRead.length, 1);
    });

    test('Eliminazione libro', () {
      appState.addBookRead('Fahrenheit 451');
      expect(appState.booksRead.length, 1);
      
      final id = appState.booksRead.first.id;
      appState.removeBook(id);
      
      expect(appState.booksRead.length, 0);
    });

    test('Valutazione libro (Rating)', () {
      appState.addBookRead('Lo Hobbit');
      final id = appState.booksRead.first.id;
      
      appState.rateBook(id, 4);
      expect(appState.booksRead.first.rating, 4);
    });

    test('Impostazioni e Profilo', () {
      appState.setUserName('Mario');
      expect(appState.userName, 'Mario');
      
      appState.setLanguageCode('eng');
      expect(appState.languageCode, 'eng');
      
      appState.setThemeMode(ThemeMode.dark);
      expect(appState.themeMode, ThemeMode.dark);
    });
  });
}
