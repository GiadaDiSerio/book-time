import 'package:http/http.dart' as http;
import 'dart:convert';

/// Cerca la trama di un libro su Open Library dato titolo e autore.
/// Prima cerca il libro, poi recupera la descrizione dalla chiave trovata.
Future<String> fetchBookPlot(String title, String author) async {
  try {
    final searchUrl = Uri.parse(
      'https://openlibrary.org/search.json?title=${Uri.encodeComponent(title)}&author=${Uri.encodeComponent(author)}&limit=1',
    );
    final searchResponse = await http.get(searchUrl);

    if (searchResponse.statusCode == 200) {
      final searchData = json.decode(searchResponse.body);
      final docs = searchData['docs'] as List? ?? [];
      if (docs.isNotEmpty) {
        final bookKey = docs[0]['key'];
        if (bookKey != null) {
          return await fetchBookPlotByKey(bookKey);
        }
      }
      return 'Nessuna trama disponibile.';
    } else {
      return 'Impossibile caricare la trama.';
    }
  } catch (e) {
    return 'Errore durante il caricamento della trama.';
  }
}

/// Recupera la descrizione di un libro dalla sua chiave Open Library.
/// La chiave ha formato "/works/OL12345W".
Future<String> fetchBookPlotByKey(String? bookKey) async {
  if (bookKey == null) return 'Nessuna trama disponibile.';

  try {
    final url = Uri.parse('https://openlibrary.org$bookKey.json');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['description'] != null) {
        if (data['description'] is String) {
          return data['description'];
        } else if (data['description'] is Map && data['description']['value'] != null) {
          return data['description']['value'];
        }
      }
      return 'Nessuna trama disponibile in italiano/inglese.';
    } else {
      return 'Impossibile caricare la trama.';
    }
  } catch (e) {
    return 'Errore durante il caricamento della trama.';
  }
}
