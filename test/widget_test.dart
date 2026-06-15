// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:book_time/main.dart';
import 'package:book_time/controllers/app_controller.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Inizializza SharedPreferences con valori vuoti per il test
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    final appState = AppController();
    await appState.loadState();
    
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => appState,
        child: const BookTimeApp(),
      ),
    );

    // Verify that our app shows the 'Book Time' title.
    expect(find.text('Book Time'), findsWidgets);
  });
}
