// spoonacular_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';
Future<List<Map<String, dynamic>>> spoonacularIleTarifOlustur(List<String> malzemeler) async {
  final apiKey = '3353128315794d05b2063bb8b3728ea0';
  final query = malzemeler.join(',');
  final url = Uri.parse(
    'https://api.spoonacular.com/recipes/findByIngredients?ingredients=$query&number=5&apiKey=$apiKey',
  );

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map<Map<String, dynamic>>((e) => {
      "title": e["title"] ?? "",
      "image": e["image"] ?? "",
      "id": e["id"].toString(),
    }).toList();
  } else {
    throw Exception('Tarif çekilemedi: ${response.statusCode}');
  }
}
