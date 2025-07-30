import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
class AiRecipeDetailPage extends StatefulWidget {
  final String id;
  final String title;
  AiRecipeDetailPage({required this.id, required this.title});

  @override
  State<AiRecipeDetailPage> createState() => _AiRecipeDetailPageState();
}

class _AiRecipeDetailPageState extends State<AiRecipeDetailPage> {
  Map<String, dynamic>? recipe;
  bool loading = true;
  String? hata;

  final String apiKey = '89525dbf4ebd4a4cbcb3578a7fd3425f'; // BURAYA KENDİ KEY'İNİ YAZ

  @override
  void initState() {
    super.initState();
    fetchRecipe();
  }

  Future<void> fetchRecipe() async {
    try {
      final url = Uri.parse("https://api.spoonacular.com/recipes/${widget.id}/information?apiKey=$apiKey");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          recipe = json.decode(response.body);
          loading = false;
        });
      } else {
        setState(() {
          hata = "Tarif detayına ulaşılamadı. (${response.statusCode})";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        hata = "Tarif çekilirken hata oluştu.";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : hata != null
          ? Center(child: Text(hata!))
          : Padding(
        padding: EdgeInsets.all(18),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recipe?["image"] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(recipe!["image"], height: 200, width: double.infinity, fit: BoxFit.cover),
                ),
              SizedBox(height: 18),
              Text(recipe?["title"] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.deepOrange)),
              SizedBox(height: 6),
              Text(recipe?["readyInMinutes"] != null ? "Hazırlık: ${recipe?["readyInMinutes"]} dk" : "", style: TextStyle(color: Colors.indigo)),
              Divider(),
              Text("Malzemeler:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              ...(recipe?["extendedIngredients"] as List<dynamic>? ?? []).map((ing) =>
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text("• ${ing["original"]}"),
                  ),
              ),
              Divider(),
              Text("Hazırlanışı:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              SizedBox(height: 6),
              recipe?["instructions"] != null && (recipe?["instructions"] as String).trim().isNotEmpty
                  ? Text(recipe!["instructions"], style: TextStyle(fontSize: 15))
                  : Text("Açıklama bulunamadı.", style: TextStyle(color: Colors.grey)),
              SizedBox(height: 18),
              if (recipe?["sourceUrl"] != null)
                TextButton.icon(
                  icon: Icon(Icons.link, color: Colors.blue),
                  label: Text("Kaynağı Gör"),
                  onPressed: () async {
                    final url = recipe!["sourceUrl"];
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
