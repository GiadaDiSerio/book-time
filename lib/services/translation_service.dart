import 'package:translator/translator.dart';

class TranslationService {
  final GoogleTranslator _translator = GoogleTranslator();

  /// Traduce la trama in italiano usando il pacchetto web gratuito 'translator'
  Future<String> translatePlot(String fallbackPlot) async {
    if (fallbackPlot.isEmpty || 
        fallbackPlot == 'Nessuna trama disponibile.' || 
        fallbackPlot == 'Nessuna trama disponibile in italiano/inglese.') {
      return fallbackPlot;
    }

    try {
      final translation = await _translator.translate(fallbackPlot, from: 'en', to: 'it');
      return translation.text;
    } catch (e) {
      print('Errore di traduzione web: $e');
      return fallbackPlot; // Restituisce l'originale se fallisce
    }
  }
}

final translationService = TranslationService();
