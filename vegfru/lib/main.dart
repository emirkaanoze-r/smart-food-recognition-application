import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'spoonacular_api.dart';
import 'ai_recipe_detail_page.dart';
import 'feedback_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'user_profile_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'app_drawer.dart';
import 'forgot_password_page.dart';
Future<void> setupFirebaseMessaging() async {
  // Android 13 ve üstü için bildirim izni iste
  await FirebaseMessaging.instance.requestPermission();

  // Topic'e abone ol (send.js ile aynı topic!)
  await FirebaseMessaging.instance.subscribeToTopic('all');

  // (İsteğe bağlı) Token'i alıp konsola yazdır
  String? token = await FirebaseMessaging.instance.getToken();
  print('Firebase Messaging Token: $token');

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Bildirim geldi: ${message.notification?.title} - ${message.notification?.body}');
  });
}

void printFcmToken() async {
  String? token = await FirebaseMessaging.instance.getToken();
  print("CIHAZ TOKEN: $token");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await EasyLocalization.ensureInitialized();
  await FirebaseMessaging.instance.subscribeToTopic('all');
  await setupFirebaseMessaging();
  printFcmToken(); // BURAYA EKLE
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      path: 'assets/lang',
      fallbackLocale: const Locale('tr', 'TR'),
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: tr('app_name'), // Dil dosyasından çeker!
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.indigo.shade50,
        fontFamily: 'Arial',
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const SplashScreen(),
    );
  }
}

// AiRecipePage.dart veya main.dart içi
class AiRecipePage extends StatefulWidget {
  @override
  State<AiRecipePage> createState() => _AiRecipePageState();
}

class _AiRecipePageState extends State<AiRecipePage> {
  final TextEditingController _malzemeCtrl = TextEditingController();
  List<Map<String, dynamic>>? _tarifler;
  bool _loading = false;
  String? _hata;

  Future<void> _olusturTarif() async {
    setState(() {
      _loading = true;
      _tarifler = null;
      _hata = null;
    });
    final malzemeText = _malzemeCtrl.text.trim();
    if (malzemeText.isEmpty) {
      setState(() {
        _loading = false;
        _hata = "Lütfen en az bir malzeme giriniz.";
      });
      return;
    }
    // 1. GİRİLEN MALZEMELERİ LİSTELE
    final malzemeler = malzemeText
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // 2. TÜRKÇE'DEN İNGİLİZCE'YE ÇEVİR
    final cevrilmis = cevirVeTemizle(malzemeler);

    try {
      final tarifler = await spoonacularIleTarifOlustur(malzemeler);
      setState(() {
        _loading = false;
        _tarifler = tarifler;
        _hata = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _tarifler = null;
        _hata = "Tarif bulunamadı veya hata oluştu: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Yapay Zeka ile Tarif'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Evde ne varsa yaz, akıllı tarif sihirbazı senin için lezzetli öneriler bulsun!",
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _malzemeCtrl,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: "Örnek: apple, tomato, garlic",
              ),
              minLines: 1,
              maxLines: 3,
            ),

            const SizedBox(height: 14),
            ElevatedButton.icon(
              icon: Icon(Icons.auto_awesome),
              label: Text("Yapay Zeka Tarif Oluştur"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _loading ? null : _olusturTarif,
            ),
            const SizedBox(height: 22),
            if (_loading)
              Center(child: CircularProgressIndicator()),
            if (_hata != null)
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  _hata!,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            if (_tarifler != null)
              Expanded(
                child: ListView.builder(
                  itemCount: _tarifler!.length,
                  itemBuilder: (context, i) {
                    final t = _tarifler![i];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: t["image"] != null
                            ? Image.network(t["image"], width: 50, height: 50, fit: BoxFit.cover)
                            : null,
                        title: Text(t["title"] ?? ""),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AiRecipeDetailPage(
                                id: t["id"],
                                title: t["title"] ?? "",
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const IntroPage()),
      );
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood, size: 100, color: Colors.indigo),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              "Yapay zeka modeli yükleniyor...",
              style: TextStyle(fontSize: 18, color: Colors.indigo),
            )
          ],
        ),
      ),
    );
  }
}

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fastfood, size: 100, color: Colors.indigo),
              const SizedBox(height: 30),
              Text(
                'Bilge Besin',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Fotoğrafla tanı, besin değerini ve merak ettiğin tüm bilgileri tek dokunuşla öğren!',
                style: TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {

                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TFLiteFlutterPage()),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Başla'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
final Map<String, String> turkce2ingilizce = {
  "elma": "apple",
  "yumurta": "egg",
  "peynir": "cheese",
  "domates": "tomato",
  "patates": "potato",
  "süt": "milk",
  "un": "flour",
  "şeker": "sugar",
  "tuz": "salt",
  "biber": "pepper",
};

List<String> cevirVeTemizle(List<String> girilen) {
  return girilen.map((malzeme) {
    var temiz = malzeme.trim().toLowerCase();
    return turkce2ingilizce[temiz] ?? temiz;
  }).toList();
}

// Besine özel sağlık uyarıları:
final Map<String, String> saglikUyarilari = {
  "apple": "Elma; lif ve C vitamini açısından zengindir, sindirimi destekler. Şeker hastaları porsiyona dikkat etmeli.",
  "banana": "Muz; potasyum ve B6 vitamini içerir, enerji verir. Fazla tüketim kalori artışına neden olabilir.",
  "grape": "Üzüm; antioksidan ve C vitamini kaynağıdır, kalp sağlığını destekler. Şeker oranı yüksektir, diyabet hastaları dikkatli tüketmeli.",
  "lemon": "Limon; C vitamini deposu ve bağışıklık sistemini güçlendirir. Asidik yapısı mide hassasiyeti olanlarda rahatsızlık verebilir.",
  "olive": "Zeytin; E vitamini ve sağlıklı yağlar açısından zengindir. Tuzlu çeşitlerinde tansiyon hastaları miktara dikkat etmeli.",
  "pomegranate": "Nar; güçlü antioksidan içerir, bağışıklığı artırır. Kan sulandırıcı ilaç kullananlar doktora danışmalı.",
  "broccoli": "Brokoli; lif, C ve K vitamini açısından zengindir, bağışıklığı destekler. Tiroid rahatsızlığı olanlar aşırıya kaçmamalı.",
  "carrot": "Havuç; A vitamini kaynağıdır, göz sağlığına faydalıdır. Fazla tüketimde ciltte hafif sararma görülebilir.",
  "corn": "Mısır; enerji ve lif kaynağıdır, sindirimi kolaylaştırır. Kan şekerini hızlı yükseltebilir, diyabetliler dikkatli olmalı.",
  "cucumber": "Salatalık; su oranı yüksektir, böbrekleri destekler. Fazla tüketimde idrar söktürücü etki yapabilir.",
  "eggplant": "Patlıcan; düşük kalorilidir, lif ve antioksidan içerir. Çiğ tüketilmemeli, pişirilerek yenmelidir.",
  "basil": "Fesleğen; K vitamini ve antioksidan kaynağıdır, bağışıklığı destekler. Kan sulandırıcı ilaç kullananlar tüketirken dikkat etmeli.",
  "garlic": "Sarımsak; doğal antibiyotik, kolesterol ve tansiyonu düzenleyebilir. Fazla tüketimde mide hassasiyeti yapabilir.",
  "potato": "Patates; potasyum ve C vitamini içerir. Kızartma yerine haşlama veya fırında tüketmek daha sağlıklıdır.",
  "tomato": "Domates; likopen ve C vitamini açısından zengindir, kalp sağlığını korur. Reflü hastaları fazla tüketmemeli.",
};


class TFLiteFlutterPage extends StatefulWidget {

  const TFLiteFlutterPage({super.key});
  @override
  State<TFLiteFlutterPage> createState() => _TFLiteFlutterPageState();
}

class _TFLiteFlutterPageState extends State<TFLiteFlutterPage> {


  final picker = ImagePicker();
  File? _image;
  String _resultLabel = '';
  String _confidence = '';
  bool _loading = false;
  late Interpreter _interpreter;
  List<String> _labels = [];
  List<Map<String, String>> _nutrients = [];
  final String _usdaApiKey = 'rqDYEhzS0KBMp8kVpI2KMzfygc4RUkAjhhhwmRqV';

  // Tarif için:
  List<Map<String, String>> _tarifler = [];
  String? _tarifHata;

  // Kullanıcı yorumları:
  List<QueryDocumentSnapshot> _yorumDocs = [];
  final TextEditingController _yorumController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadModelAndLabels();
    loadFoodInfo();
  }
  Map<String, dynamic> foodInfo = {};

  Future<void> loadFoodInfo() async {
    String data = await rootBundle.loadString('assets/food_info.json');
    foodInfo = jsonDecode(data);
    // Eğer ilk yükelemede UI'ı güncellemek istersen:
    if (mounted) setState(() {});
  }
  Future<void> _loadModelAndLabels() async {
    _interpreter = await Interpreter.fromAsset('assets/model.tflite');
    final labelData = await rootBundle.loadString('assets/labels.txt');
    _labels = labelData.split('\n').map((e) => e.trim()).toList();
  }

  Future<void> _pickImage(ImageSource src) async {
    final picked = await picker.pickImage(source: src);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _loading = true;
      _resultLabel = '';
      _confidence = '';
      _nutrients = [];
      _tarifler = [];
      _tarifHata = null;
      _yorumDocs = [];
      _yorumController.clear();
    });

    final imageBytes = await picked.readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      setState(() {
        _resultLabel = 'Geçersiz görsel!';
        _loading = false;
      });
      return;
    }

    final resized = img.copyResize(image, width: 224, height: 224);
    final input = imageToFloat32(resized);
    var output = List.filled(15, 0.0).reshape([1, 15]);

    _interpreter.run(input, output);
    final results = (output[0] as List).cast<double>();
    final maxVal = results.reduce((a, b) => a > b ? a : b);
    final topIdx = results.indexOf(maxVal);
    final label = _labels[topIdx];
    final conf = (results[topIdx] * 100).toStringAsFixed(2);

    await fetchNutritionInfo(label);
    await fetchRecipes(label);

    setState(() {
      _resultLabel = label;
      _confidence = conf;
      _loading = false;
    });

    await _addToHistory(label, conf, _nutrients, _image!);
    await _loadCommentsFirestore();
  }

  List<List<List<List<double>>>> imageToFloat32(img.Image image) {
    return List.generate(1, (_) => List.generate(224, (y) =>
        List.generate(224, (x) {
          final pixel = image.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
    ));
  }

  Future<void> fetchNutritionInfo(String foodName) async {
    _nutrients = [];
    final url = Uri.parse(
      'https://api.nal.usda.gov/fdc/v1/foods/search?query=$foodName&pageSize=1&api_key=$_usdaApiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final foods = data['foods'];
        if (foods != null && foods.isNotEmpty) {
          final nutrients = foods[0]['foodNutrients'];
          setState(() {
            _nutrients = nutrients.map<Map<String, String>>((n) {
              return {
                'name': n['nutrientName'].toString(),
                'value': n['value'].toString(),
                'unit': n['unitName'].toString()
              };
            }).toList();
          });
        }
      }
    } catch (e) {
      setState(() {
        _nutrients = [
          {'name': 'Hata', 'value': 'Besin bilgisi bulunamadı!', 'unit': ''}
        ];
      });
    }
  }

  Future<void> fetchRecipes(String foodName) async {
    setState(() {
      _tarifler = [];
      _tarifHata = null;
    });
    try {
      final url = Uri.parse("https://www.themealdb.com/api/json/v1/1/filter.php?i=${Uri.encodeComponent(foodName)}");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final meals = data["meals"];
        if (meals != null) {
          setState(() {
            _tarifler = List<Map<String, String>>.from(meals.map((meal) => {
              "ad": meal["strMeal"] ?? "",
              "gorsel": meal["strMealThumb"] ?? "",
              "id": meal["idMeal"] ?? "",
            })).take(4).toList();
          });
        } else {
          setState(() {
            _tarifHata = "Bu besine özel tarif bulunamadı.";
          });
        }
      } else {
        setState(() {
          _tarifHata = "Tarif verisine ulaşılamadı. (${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _tarifHata = "Tarif çekilirken hata oluştu.";
      });
    }
  }
  Widget yorumlarWidget() {
    if (_yorumDocs.isEmpty) {
      return Text("Henüz yorum yok.", style: TextStyle(color: Colors.grey));
    }
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      children: _yorumDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final isOwnComment = user != null && data['uid'] == user.uid;
        return Card(
          elevation: 0,
          margin: EdgeInsets.symmetric(vertical: 2),
          color: isOwnComment ? Colors.indigo.withOpacity(0.1) : Colors.grey[100],
          child: ListTile(
            title: Text(data['text'] ?? ''),
            subtitle: Row(
              children: [
                if (data['userEmail'] != null)
                  Text(data['userEmail'], style: TextStyle(fontSize: 12)),
                if (data['timestamp'] != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      (data['timestamp'] as Timestamp?)?.toDate().toString().substring(0, 16) ?? "",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
            ),
            trailing: isOwnComment
                ? IconButton(
              icon: Icon(Icons.delete, color: Colors.redAccent, size: 22),
              onPressed: () async {
                await _deleteCommentFirestore(doc.id);
              },
            )
                : null,
          ),
        );
      }).toList(),
    );
  }

  // --- Kullanıcı yorumu işlemleri ---
  Future<void> _loadCommentsFirestore() async {
    if (_resultLabel.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('comments')
        .doc(_resultLabel.toLowerCase())
        .collection('all')
        .orderBy('timestamp', descending: true)
        .get();
    setState(() {
      _yorumDocs = snap.docs;
    });
  }

  Future<void> _addCommentFirestore(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => AuthPage()));
      if (FirebaseAuth.instance.currentUser == null) return;
    }
    if (_resultLabel.isEmpty || text.trim().isEmpty) return;
    final doc = FirebaseFirestore.instance
        .collection('comments')
        .doc(_resultLabel.toLowerCase())
        .collection('all')
        .doc();
    await doc.set({
      'text': text.trim(),
      'userEmail': user!.email,
      'uid': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _yorumController.clear();
    await _loadCommentsFirestore(); // Yorumları anlık güncelle
  }


  Future<void> _deleteCommentFirestore(String docId) async {
    await FirebaseFirestore.instance
        .collection('comments')
        .doc(_resultLabel.toLowerCase())
        .collection('all')
        .doc(docId)
        .delete();
    await _loadCommentsFirestore(); // Yorumları anlık güncelle
  }


  Future<void> _addToHistory(String label, String confidence, List<Map<String, String>> nutrients, File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final key = 'historyV2_${user.uid}';
    String imageBase64 = base64Encode(await imageFile.readAsBytes());
    String date = DateTime.now().toString().split(' ')[0];

    Map<String, dynamic> item = {
      'label': label,
      'confidence': confidence,
      'nutrients': nutrients.take(6).toList(),
      'timestamp': DateTime.now().toIso8601String(),
      'image': imageBase64,
    };

    Map<String, dynamic> allHistory = {};
    String? oldStr = prefs.getString(key);
    if (oldStr != null) {
      allHistory = Map<String, dynamic>.from(json.decode(oldStr));
    }
    List<Map<String, dynamic>> dayList = allHistory[date]?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    dayList.insert(0, item);
    allHistory[date] = dayList;

    await prefs.setString(key, json.encode(allHistory));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilge Besin'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      drawer: AppDrawer(),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Fotoğraf Çek'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeriden Seç'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_image != null)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(_image!, height: 220),
                  ),
                ),
              const SizedBox(height: 18),
              if (_resultLabel.isNotEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Tahmin Sonucu',
                          style: TextStyle(
                            fontSize: 19,
                            color: Colors.indigo.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _resultLabel,
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Güven: $_confidence%',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_nutrients.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        children: [
                          Text(
                            'Besin Bilgileri',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "100 gram için; besin bilgileri",
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const Divider(),
                          ..._nutrients.take(8).map((n) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
                            title: Text(n['name']!),
                            trailing: Text(
                                "${n['value'] ?? '—'} ${n['unit'] ?? ''}",
                                style: const TextStyle(fontWeight: FontWeight.bold)
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              // ---------- Sağlık uyarısı göster ----------
              if (_resultLabel.isNotEmpty && saglikUyarilari[_resultLabel.toLowerCase()] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Card(
                    color: Colors.red[50],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              saglikUyarilari[_resultLabel.toLowerCase()]!,
                              style: TextStyle(fontSize: 15, color: Colors.red[900], fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // ----------- Yetiştiği bölgeler kartı -----------
              if (_resultLabel.isNotEmpty && foodInfo.containsKey(_resultLabel.toLowerCase()))
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Card(
                    color: Colors.lightGreen[50],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Başlıca Yetiştiği Bölgeler:",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900])),
                          SizedBox(height: 4),
                          ...List<String>.from(foodInfo[_resultLabel.toLowerCase()]["regions"])
                              .map((region) => Text("• $region")).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              // ----------- Kullanıcı yorumları ------------
              if (_resultLabel.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 18.0, left: 6, right: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Kullanıcı Yorumları", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 17)),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _yorumController,
                              decoration: InputDecoration(
                                hintText: "Yorumunu yaz...",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              minLines: 1,
                              maxLines: 3,
                            ),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              await _addCommentFirestore(_yorumController.text);
                            },
                            child: Text("Ekle"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),

                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      yorumlarWidget(),
                    ],
                  ),
                ),
              ],
              // ------- YEMEK TARİFİ KARTI -----------

              if (_resultLabel.isEmpty && _image == null)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Text(

                    'Bir besinin fotoğrafını çekin veya galeriden seçin.\n\n'
                        'Yapay zekâ ile anında tanıyın!\n\n'
                        'Besin değeri, yetiştirildiği yerler ve o besinle ilgili ilginç bilgiler parmaklarınızın ucunda.\n\n'
                        'Sofranızdaki gıdanın hikâyesini, özelliklerini ve kültürel yönlerini şimdi keşfedin!\n\n'
                        'Yapay zeka yanılabilir. Işık kosullarına dikkat edin!',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.w500,
                      height: 1.4, // Satır arası boşluk biraz daha ferah gösterir
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

            ],
          ),
        ),
      ),
    );
  }
}


class AdminPanelPage extends StatefulWidget {
  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  List<DocumentSnapshot> _users = [];
  Map<String, dynamic>? _selectedUserHistory;
  String? _selectedUserId;

  // Bildirim gönderme alanı
  final TextEditingController _notifTitleCtrl = TextEditingController();
  final TextEditingController _notifBodyCtrl = TextEditingController();
  bool _notifLoading = false;
  String? _notifResult;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      _users = snap.docs;
    });
  }

  Future<void> _fetchUserHistory(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    String? historyStr = prefs.getString('historyV2_$uid');
    setState(() {
      _selectedUserHistory = historyStr != null ? json.decode(historyStr) : {};
      _selectedUserId = uid;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchFeedbacks(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('feedback')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((e) => e.data() as Map<String, dynamic>).toList();
  }

  // --- Backend'e Bildirim Gönderme Fonksiyonu
  Future<void> _sendPushNotification() async {
    final String title = _notifTitleCtrl.text.trim();
    final String body = _notifBodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _notifResult = "Başlık ve mesaj boş olamaz!");
      return;
    }
    setState(() {
      _notifLoading = true;
      _notifResult = null;
    });

    final url = Uri.parse('https://firebase-notification-backend-g51s.onrender.com/send-notification');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"title": title, "body": body}),
      );
      if (response.statusCode == 200) {
        setState(() => _notifResult = "Bildirim gönderildi!");
      } else {
        setState(() => _notifResult = "Sunucu hatası: ${response.statusCode}\n${response.body}");
      }
    } catch (e) {
      setState(() => _notifResult = "Hata: $e");
    }
    setState(() => _notifLoading = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.all(14),
        children: [
          // ==== Bildirim Gönderme Alanı ====
          Card(
            elevation: 3,
            margin: EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Herkese Push Bildirim Gönder", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.redAccent)),
                  SizedBox(height: 10),
                  TextField(
                    controller: _notifTitleCtrl,
                    decoration: InputDecoration(
                      labelText: "Başlık",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _notifBodyCtrl,
                    decoration: InputDecoration(
                      labelText: "Mesaj",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.send),
                      label: Text(_notifLoading ? "Gönderiliyor..." : "Gönder"),
                      onPressed: _notifLoading ? null : _sendPushNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_notifResult != null)
                    Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        _notifResult!,
                        style: TextStyle(
                          color: _notifResult!.contains("Hata") || _notifResult!.contains("Sunucu")
                              ? Colors.red
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ==== Buradan sonrası senin mevcut kullanıcı vs. kodun ====
          _selectedUserId == null
              ? ListTile(
            title: Text("Tüm Kayıtlı Kullanıcılar", style: TextStyle(fontWeight: FontWeight.bold)),
          )
              : SizedBox(),
          ..._selectedUserId == null
              ? _users.map((userDoc) {
            final user = userDoc.data() as Map<String, dynamic>;
            return ListTile(
              leading: Icon(Icons.person, color: Colors.indigo),
              title: Text(user["email"] ?? "Belirsiz"),
              subtitle: Text("${user["name"] ?? ""} ${user["surname"] ?? ""}"),
              onTap: () async {
                await _fetchUserHistory(userDoc.id);
              },
            );
          }).toList()
              : [],
          if (_selectedUserId != null)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchFeedbacks(_selectedUserId!),
              builder: (context, snap) {
                final feedbacks = snap.data ?? [];
                return ListView(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.all(12),
                  children: [
                    ListTile(
                      leading: Icon(Icons.arrow_back),
                      title: Text("Kullanıcılara Dön"),
                      onTap: () => setState(() => _selectedUserId = null),
                    ),
                    SizedBox(height: 12),
                    Text("Tahmin Geçmişi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    Divider(),
                    if ((_selectedUserHistory ?? {}).isEmpty)
                      Text("Geçmiş kaydı yok.", style: TextStyle(color: Colors.grey)),
                    ...((_selectedUserHistory ?? {}).entries ?? []).expand((entry) {
                      final date = entry.key;
                      final items = entry.value as List<dynamic>;
                      return [
                        Text(date, style: TextStyle(fontWeight: FontWeight.bold)),
                        ...items.map((item) => ListTile(
                          title: Text(item['label'] ?? ''),
                          subtitle: Text("Güven: ${item['confidence']}%, Zaman: ${item['timestamp']}"),
                        )),
                      ];
                    }),
                    SizedBox(height: 24),
                    Text("Geri Bildirimler", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: buildFeedbackList(),
                    ),

                    Divider(),
                    ...feedbacks.isEmpty
                        ? [Text("Kullanıcıdan geribildirim yok.", style: TextStyle(color: Colors.grey))]
                        : feedbacks.map((f) => ListTile(
                      title: Text(f["text"] ?? ""),
                      subtitle: Text(f["createdAt"] != null
                          ? (f["createdAt"] as Timestamp).toDate().toString()
                          : ""),
                    )),
                  ],
                );
              },
            ),
        ],
      ),
    );


  }
}

// ====== TARİF DETAYI ======
class RecipeDetailPage extends StatefulWidget {
  final String id;
  final String title;
  RecipeDetailPage({required this.id, required this.title});
  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  Map<String, dynamic>? recipe;
  bool loading = true;
  String? hata;

  @override
  void initState() {
    super.initState();
    fetchRecipe();

  }

  Future<void> fetchRecipe() async {
    try {
      final url = Uri.parse("https://www.themealdb.com/api/json/v1/1/lookup.php?i=${widget.id}");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["meals"] != null) {
          setState(() {
            recipe = data["meals"][0];
            loading = false;
          });
        } else {
          setState(() {
            hata = "Tarif detayına ulaşılamadı.";
            loading = false;
          });
        }
      } else {
        setState(() {
          hata = "Sunucu hatası (${response.statusCode})";
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
        actions: [
          // ===== DİL DEĞİŞTİRME BUTONU =====
/*          IconButton(
            icon: Icon(Icons.language),
            tooltip: tr('language'),
            tooltip: tr('language'),
            onPressed: () {
              if (context.locale == const Locale('tr', 'TR')) {
                context.setLocale(const Locale('en', 'US'));
              } else {
                context.setLocale(const Locale('tr', 'TR'));
              }
            },
          ),*/
        ],
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
            // ... devamı
        children: [
              if (recipe?["strMealThumb"] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(recipe!["strMealThumb"], height: 200, width: double.infinity, fit: BoxFit.cover),
                ),
              SizedBox(height: 18),
              Text(recipe?["strMeal"] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.deepOrange)),
              SizedBox(height: 6),
              Text(recipe?["strArea"] != null ? "Mutfak: ${recipe?["strArea"]}" : "", style: TextStyle(color: Colors.indigo)),
              Text(recipe?["strCategory"] != null ? "Kategori: ${recipe?["strCategory"]}" : "", style: TextStyle(color: Colors.indigo)),
              Divider(),
              Text("Malzemeler:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              ...List.generate(20, (i) {
                String? malzeme = recipe?["strIngredient${i+1}"];
                String? miktar = recipe?["strMeasure${i+1}"];
                if (malzeme != null && malzeme.isNotEmpty && malzeme.trim() != "") {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text("• $malzeme ${miktar ?? ''}"),
                  );
                }
                return Container();
              }),
              Divider(),
              Text("Hazırlanışı:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              SizedBox(height: 6),
              Text(recipe?["strInstructions"] ?? '', style: TextStyle(fontSize: 15)),
              SizedBox(height: 18),
              if (recipe?["strYoutube"] != null && recipe!["strYoutube"].toString().isNotEmpty)
                TextButton.icon(
                  icon: Icon(Icons.video_library, color: Colors.red),
                  label: Text("YouTube’da İzle"),
                  onPressed: () async {
                    final url = recipe!["strYoutube"];
                    await launchUrl(Uri.parse(url));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== GEÇMİŞ SAYFASI ===============
class HistoryPage extends StatefulWidget {
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Map<String, dynamic> foodInfo = {}; // <--- BURAYA EKLE
  Map<String, List<Map<String, dynamic>>> _groupedHistory = {};
  String? _selectedDate;
  int? _selectedQueryIndex;

  User? get currentUser => FirebaseAuth.instance.currentUser;
  String get _historyKey => 'historyV2_${currentUser?.uid ?? "anonim"}';

  @override
  void initState() {
    super.initState();
    _loadGroupedHistory();
    _loadFoodInfo(); // 2. EKLE
  }
  Future<void> _loadFoodInfo() async { // 2. EKLE
    String data = await rootBundle.loadString('assets/food_info.json');
    setState(() {
      foodInfo = jsonDecode(data);
    });
  }
  Future<void> _loadGroupedHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String? oldStr = prefs.getString(_historyKey);
    Map<String, dynamic> allHistory = {};
    if (oldStr != null) {
      allHistory = Map<String, dynamic>.from(json.decode(oldStr));
    }
    setState(() {
      _groupedHistory = allHistory.map((k, v) => MapEntry(
          k, List<Map<String, dynamic>>.from(v)));
    });
  }

  Future<void> _deleteAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    setState(() {
      _groupedHistory = {};
      _selectedDate = null;
      _selectedQueryIndex = null;
    });
  }

  Future<void> _deleteDay(String day) async {
    final prefs = await SharedPreferences.getInstance();
    String? oldStr = prefs.getString(_historyKey);
    if (oldStr == null) return;
    Map<String, dynamic> allHistory = Map<String, dynamic>.from(json.decode(oldStr));
    allHistory.remove(day);
    await prefs.setString(_historyKey, json.encode(allHistory));
    setState(() {
      _selectedDate = null;
      _selectedQueryIndex = null;
    });
    await _loadGroupedHistory();
  }

  Future<void> _deleteQuery(String day, int idx) async {
    final prefs = await SharedPreferences.getInstance();
    String? oldStr = prefs.getString(_historyKey);
    if (oldStr == null) return;
    Map<String, dynamic> allHistory = Map<String, dynamic>.from(json.decode(oldStr));
    List<Map<String, dynamic>> dayList =
    List<Map<String, dynamic>>.from(allHistory[day]);
    dayList.removeAt(idx);
    if (dayList.isEmpty) {
      allHistory.remove(day);
      setState(() {
        _selectedDate = null;
        _selectedQueryIndex = null;
      });
    } else {
      allHistory[day] = dayList;
    }
    await prefs.setString(_historyKey, json.encode(allHistory));
    await _loadGroupedHistory();
  }

// ...build fonksiyonu aynı, sadece yukarıdaki fonksiyonları değiştirmen yeterli...


  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      // Kullanıcı giriş yapmamışsa geçmiş erişilemez!
      return Scaffold(
        appBar: AppBar(
          title: Text('Geçmiş'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            "Geçmişi görmek için giriş yapmalısınız!",
            style: TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    List<String> dates = _groupedHistory.keys.toList()..sort((a, b) => b.compareTo(a));
    return Scaffold(
      appBar: AppBar(
        title: Text('Geçmiş'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedDate == null && dates.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_forever),
              tooltip: "Tüm geçmişi sil",
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text("Tüm geçmişi silmek istediğinize emin misiniz?"),
                    content: Text("Bu işlem geri alınamaz."),
                    actions: [
                      TextButton(child: Text("İptal"), onPressed: () => Navigator.pop(ctx, false)),
                      ElevatedButton(child: Text("Sil"), onPressed: () => Navigator.pop(ctx, true)),
                    ],
                  ),
                );
                if (confirm == true) await _deleteAllHistory();
              },
            ),
          if (_selectedDate != null && _groupedHistory[_selectedDate] != null)
            IconButton(
              icon: Icon(Icons.delete),
              tooltip: "Bu günü sil",
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text("${_selectedDate} silinsin mi?"),
                    content: Text("O günün tüm kayıtları silinir. Emin misiniz?"),
                    actions: [
                      TextButton(child: Text("İptal"), onPressed: () => Navigator.pop(ctx, false)),
                      ElevatedButton(child: Text("Sil"), onPressed: () => Navigator.pop(ctx, true)),
                    ],
                  ),
                );
                if (confirm == true) await _deleteDay(_selectedDate!);
              },
            ),
        ],
      ),
      body: _selectedDate == null
          ? dates.isEmpty
          ? Center(child: Text("Henüz kayıtlı geçmiş yok.", style: TextStyle(fontSize: 16)))
          : ListView.builder(
        itemCount: dates.length,
        itemBuilder: (context, i) => ListTile(
          title: Text(dates[i]),
          trailing: Icon(Icons.chevron_right),
          onTap: () => setState(() => _selectedDate = dates[i]),
        ),
      )
          : _selectedQueryIndex == null
          ? Column(
        children: [
          ListTile(
            leading: Icon(Icons.arrow_back),
            title: Text('Geri'),
            onTap: () => setState(() => _selectedDate = null),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _groupedHistory[_selectedDate]!.length,
              itemBuilder: (context, idx) {
                final q = _groupedHistory[_selectedDate]![idx];
                return ListTile(
                  leading: q['image'] != null
                      ? Image.memory(base64Decode(q['image']),
                      width: 48, height: 48, fit: BoxFit.cover)
                      : null,
                  title: Text('${q['label']} (${q['confidence']}%)'),
                  subtitle: Text(DateTime.parse(q['timestamp'])
                      .toLocal()
                      .toString()
                      .substring(11, 16)),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    tooltip: "Bu tahmini sil",
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text("Tahmin silinsin mi?"),
                          content: Text("Seçili tahmin silinir. Emin misiniz?"),
                          actions: [
                            TextButton(child: Text("İptal"), onPressed: () => Navigator.pop(ctx, false)),
                            ElevatedButton(child: Text("Sil"), onPressed: () => Navigator.pop(ctx, true)),
                          ],
                        ),
                      );
                      if (confirm == true) await _deleteQuery(_selectedDate!, idx);
                    },
                  ),
                  onTap: () => setState(() => _selectedQueryIndex = idx),
                );
              },
            ),
          ),
        ],
      )
          : Column(
        children: [
          ListTile(
            leading: Icon(Icons.arrow_back),
            title: Text('Geri'),
            onTap: () => setState(() => _selectedQueryIndex = null),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Builder(
                builder: (context) {
                  final q = _groupedHistory[_selectedDate]![_selectedQueryIndex!];
                  final label = q['label'] ?? "";
                  final lowerLabel = label.toString().toLowerCase();
                  // Sağlık uyarısı ve yetiştiği bölgeler için tanımlar
                  final healthInfo = saglikUyarilari[lowerLabel];
                  final regionInfo = foodInfo[lowerLabel]?['regions'] as List<dynamic>?;
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (q['image'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                base64Decode(q['image']),
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            label,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.deepPurple,
                            ),
                          ),
                          Text(
                            'Güven: ${q['confidence']}%',
                            style: TextStyle(
                                color: Colors.indigo, fontWeight: FontWeight.w600),
                          ),
                          const Divider(height: 22),
                          Text("Besin Değerleri",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                  fontSize: 16)),
                          ...List<Map<String, dynamic>>.from(q['nutrients'] ?? []).map(
                                (nut) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.check_circle, size: 18, color: Colors.green),
                              title: Text("${nut['name']}"),
                              trailing: Text("${nut['value']} ${nut['unit']}"),
                            ),
                          ),
                          // Sağlık Uyarısı
                          if (healthInfo != null) ...[
                            const SizedBox(height: 10),
                            Card(
                              color: Colors.red[50],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.warning, color: Colors.red, size: 22),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        healthInfo,
                                        style: TextStyle(
                                          color: Colors.red[800],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // Yetiştiği Bölgeler
                          if (regionInfo != null && regionInfo.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Card(
                              color: Colors.lightGreen[50],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Başlıca Yetiştiği Bölgeler:",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[900],
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    ...regionInfo.map((r) =>
                                        Text("• $r", style: TextStyle(fontSize: 15))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      )

    );
  }
}

// ========== HAKKIMIZDA ==========
class AboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hakkımızda'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.all(22),
        children: [
          Center(
            child: CircleAvatar(
              radius: 54,
              backgroundImage: AssetImage('assets/team_avatar.png'),
            ),
          ),
          SizedBox(height: 16),
          Center(child: Text(
            "Geleceğin Sofraları, Bugünün Teknolojisiyle!",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
            textAlign: TextAlign.center,
          )),
          SizedBox(height: 18),
          Text(
            "Bilge Besin ekibi olarak, geleneksel mutfağımızı yapay zekâ ile buluşturuyor, herkes için sağlıklı ve bilinçli bir beslenme deneyimi sunuyoruz. Amacımız, teknolojiyle besinlerin sadece tadını değil, bilgisini de sofralarınıza taşımak.",
            style: TextStyle(fontSize: 16),
          ),

          SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.all(12),
            child: Text(
              "Hayalimiz, bilinçli beslenen ve hayatına lezzet katan bir nesil.",
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 15, color: Colors.indigo),
            ),
          ),
          SizedBox(height: 18),
          Text(
            "Ekibimiz:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple),
          ),
          SizedBox(height: 4),
          ListTile(
            leading: Icon(Icons.person, color: Colors.indigo),
            title: Text("Emir Kaan ÖZER"),
            subtitle: Text("Yazılım & Yapay Zeka"),
          ),
          ListTile(
            leading: Icon(Icons.person, color: Colors.indigo.shade300),
            title: Text("Emir Kaan ÖZER"),
            subtitle: Text("Tasarım ve Hikaye"),
          ),
          SizedBox(height: 14),
          Text(
            "Eğlenceli Bilgi:\n"
                "İlk prototipimizde bir elmayı patates olarak tanıdık! Neyse ki şimdi doğruluk oranımız %90+ 😊🍏🥔",
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          SizedBox(height: 40),
          Center(
            child: Text(
              "Keyifli kullanımlar!\n\n— Bilge Besin Ekibi",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade400),
            ),
          ),
        ],
      ),
    );
  }
}
// ========== İLETİŞİM ==========
class ContactPage extends StatelessWidget {
  void _showFeedbackDialog(BuildContext context) {
    final TextEditingController _feedbackCtrl = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Görüşünü Bildir"),
        content: TextField(
          controller: _feedbackCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: "Buraya görüş ve önerinizi yazabilirsiniz.",
          ),
        ),
        actions: [
          TextButton(
            child: Text("İptal"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: Text("Gönder"),
            onPressed: () async {
              final feedback = _feedbackCtrl.text.trim();
              if (feedback.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Lütfen görüşünüzü yazın!")),
                );
                return;
              }
              try {
                await FirebaseFirestore.instance.collection('feedback').add({
                  'text': feedback,
                  'createdAt': FieldValue.serverTimestamp(),
                  'userEmail': user?.email ?? 'Anonim',
                  'userId': user?.uid ?? '',
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Görüşün iletildi, teşekkürler!")),
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Bir hata oluştu!")),
                );
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _buyMeCoffee(BuildContext context) async {
    final url = Uri.parse("https://www.sma.org.tr/bagis");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bağış sayfasına yönlendirilemedi.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('İletişim'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(Icons.email, color: Colors.teal),
              title: Text("emiro1666@gmail.com"),
              subtitle: Text("Görüş, öneri ve hata bildirimi için bize ulaşın!"),
            ),
            ListTile(
              leading: Icon(Icons.person, color: Colors.indigo),
              title: Text(user?.email ?? "Giriş yapmadınız"),
              subtitle: Text(
                  user != null
                      ? "Görüşlerinizi bize iletebilirsiniz."
                      : "Giriş yaparak daha hızlı bildirim!"
              ),
            ),
            SizedBox(height: 18),
            ElevatedButton.icon(
              icon: Icon(Icons.feedback, color: Colors.white),
              label: Text("Görüşünü Bildir"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showFeedbackDialog(context),
            ),
            SizedBox(height: 28),
            Divider(),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                children: [
                  Icon(Icons.volunteer_activism, color: Colors.redAccent, size: 34),
                  SizedBox(height: 8),
                  Text(
                    "Uygulamamız gönüllü olarak geliştirilmiştir, hiçbir ticari geliri yoktur. "
                        "Dilerseniz aşağıdan SMA hastalarına bağış yaparak bir hayatı değiştirebilirsiniz.",
                    style: TextStyle(color: Colors.brown, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: () => _buyMeCoffee(context),
                    icon: Icon(Icons.favorite, color: Colors.white),
                    label: Text("SMA Hastalarına Destek Ol"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ================== GİRİŞ & KAYIT ==================
class AuthPage extends StatefulWidget {
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool showLogin = true;
  void toggle() => setState(() => showLogin = !showLogin);

  @override
  Widget build(BuildContext context) {
    return showLogin
        ? LoginPage(onToggle: toggle)
        : RegisterPage(onToggle: toggle);
  }
}

class LoginPage extends StatefulWidget {
  final VoidCallback onToggle;
  const LoginPage({required this.onToggle, Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  String? error;
  bool loading = false;
  bool showPassword = false;

// Fonksiyon:
  Future<void> signInWithGoogle() async {
    setState(() { loading = true; error = null; });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() { loading = false; });
        return; // Kullanıcı iptal etti
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // Firestore'a kayıt et (ilk kez giriş yapıyorsa)
      final firestore = FirebaseFirestore.instance;
      final userDoc = firestore.collection('users').doc(userCredential.user!.uid);
      final exists = await userDoc.get();
      if (!exists.exists) {
        await userDoc.set({
          'email': userCredential.user?.email ?? "",
          'name': userCredential.user?.displayName ?? "",
          'phone': userCredential.user?.phoneNumber ?? "",
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'user',
        });
      }

      // TÜM ESKİ SAYFALARI SİL, ANA SAYFAYA DÖN
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => TFLiteFlutterPage()),
            (route) => false,
      );
    } catch (e) {
      setState(() {
        error = "Google ile kayıt başarısız: ${e.toString()}";
      });
    }
    setState(() { loading = false; });
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );
      // TÜM ESKİ SAYFALARI SİL, ANA SAYFAYA DÖN
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => TFLiteFlutterPage()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = "Hatalı e-posta ya da şifre.";
      });
    } catch (_) {
      setState(() {
        error = "Bilinmeyen bir hata oluştu.";
      });
    }
    setState(() {
      loading = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade100,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.indigo, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    );

    return Scaffold(
      backgroundColor: Color(0xFFE6E6FA), // Modern lila arka plan
      body: Center(
        child: SingleChildScrollView(
          child: AnimatedContainer(
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.12),
                  blurRadius: 24,
                  spreadRadius: 1,
                )
              ],
            ),
            width: MediaQuery.of(context).size.width > 400 ? 400 : double.infinity,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: Colors.indigo),
                  SizedBox(height: 18),

                  Text(
                    "Giriş Yap",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: Colors.indigo[700],
                    ),
                  ),
                  SizedBox(height: 28),

                  // E-Posta
                  TextFormField(
                    controller: emailCtrl,
                    decoration: inputDecoration.copyWith(
                      prefixIcon: Icon(Icons.email_outlined),
                      labelText: "E-Posta",
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                    value == null || value.isEmpty ? "E-posta girin" : null,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 16),
                  // Şifre
                  TextFormField(
                    controller: passCtrl,
                    decoration: inputDecoration.copyWith(
                      prefixIcon: Icon(Icons.lock_outline),
                      labelText: "Şifre",
                      suffixIcon: IconButton(
                        icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            showPassword = !showPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: !showPassword,
                    validator: (value) =>
                    value == null || value.length < 6 ? "En az 6 karakter" : null,
                    textInputAction: TextInputAction.done,
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 18.0),
                      child: Text(
                        error!,
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ),
                  SizedBox(height: 28),
                  // Giriş Butonu (renk: koyu mavi, yazı: beyaz)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[700], // Koyu mavi-mor
                        foregroundColor: Colors.white, // Yazı rengi beyaz
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 18),
                        textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        elevation: 3,
                      ),
                      child: loading
                          ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                          : Text("Giriş Yap"),
                    ),
                  ),
                  // ...LoginPage sınıfının build metodu içinde, TextButton'dan hemen önce şunu ekle:
                  SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Image.asset('assets/gmail_logo.png', height: 22), // Gmail logosunu assets klasörüne koymayı unutma!
                      label: Text("Google ile Giriş Yap"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 2,
                      ),
                      onPressed: loading ? null : signInWithGoogle,
                    ),
                  ),
// Şifremi unuttum bağlantısı
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ForgotPasswordPage()),
                        );
                      },
                      child: Text(
                        "Şifreni mi unuttun?",
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),
                  TextButton(
                    onPressed: loading ? null : widget.onToggle,
                    child: Text(
                      "Hesabın yok mu? Kayıt Ol",
                      style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  final VoidCallback onToggle;
  const RegisterPage({required this.onToggle, Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final surnameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  String? error;
  bool loading = false;
  bool showPassword = false;

  Future<void> signInWithGoogle() async {
    setState(() { loading = true; error = null; });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() { loading = false; });
        return; // Kullanıcı iptal etti
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // Eğer yeni kullanıcı ise Firestore'a ekle
      final firestore = FirebaseFirestore.instance;
      final userDoc = firestore.collection('users').doc(userCredential.user!.uid);
      final exists = await userDoc.get();
      if (!exists.exists) {
        await userDoc.set({
          'email': userCredential.user?.email ?? "",
          'name': userCredential.user?.displayName ?? "",
          'phone': userCredential.user?.phoneNumber ?? "",
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'user',
        });
      }

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TFLiteFlutterPage()));
    } catch (e) {
      setState(() {
        error = "Google ile kayıt başarısız: ${e.toString()}";
      });
    }
    setState(() { loading = false; });
  }

  Future<void> register() async {
    setState(() {
      loading = true;
      error = null;
    });

    final firestore = FirebaseFirestore.instance;

    try {
      // 1. Telefon numarası daha önce kayıtlı mı?
      final phoneQuery = await firestore
          .collection('users')
          .where('phone', isEqualTo: phoneCtrl.text.trim())
          .get();

      if (phoneQuery.docs.isNotEmpty) {
        setState(() {
          error = "Bu telefon numarası zaten kayıtlı.";
          loading = false;
        });
        return;
      }

      // 2. E-posta ile kayıt olma
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );

      await firestore.collection('users').doc(credential.user!.uid).set({
        'email': emailCtrl.text.trim(),
        'name': nameCtrl.text.trim(),
        'surname': surnameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'user',
      });

      // Kayıttan sonra tüm eski sayfaları temizle, ana ekrana git!
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => TFLiteFlutterPage()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String msg = "Kayıt başarısız: ";
      if (e.code == "email-already-in-use") {
        msg = "Bu e-posta zaten kayıtlı!";
      }
      setState(() {
        error = msg;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = "Kayıt başarısız: ${e.toString()}";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade100,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    );

    return Scaffold(
      backgroundColor: Color(0xFFE6E6FA), // Lila tarzı modern arka plan
      body: Center(
        child: SingleChildScrollView(
          child: AnimatedContainer(
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.12),
                  blurRadius: 24,
                  spreadRadius: 1,
                )
              ],
            ),
            width: MediaQuery.of(context).size.width > 400 ? 400 : double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_add_alt_1, size: 48, color: Colors.deepPurple),
                SizedBox(height: 18),
                Text(
                  "Hesap Oluştur",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    color: Colors.deepPurple,
                  ),
                ),
                SizedBox(height: 28),
                // İsim
                TextField(
                  controller: nameCtrl,
                  decoration: inputDecoration.copyWith(
                    prefixIcon: Icon(Icons.person_outline),
                    labelText: "İsim",
                  ),
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 16),
                // Soyisim
                TextField(
                  controller: surnameCtrl,
                  decoration: inputDecoration.copyWith(
                    prefixIcon: Icon(Icons.badge_outlined),
                    labelText: "Soyisim",
                  ),
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 16),
                // Telefon
                TextField(
                  controller: phoneCtrl,
                  decoration: inputDecoration.copyWith(
                    prefixIcon: Icon(Icons.phone_outlined),
                    labelText: "Telefon",
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 16),
                // E-posta
                TextField(
                  controller: emailCtrl,
                  decoration: inputDecoration.copyWith(
                    prefixIcon: Icon(Icons.email_outlined),
                    labelText: "E-Posta",
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 16),
                // Şifre
                TextField(
                  controller: passCtrl,
                  decoration: inputDecoration.copyWith(
                    prefixIcon: Icon(Icons.lock_outline),
                    labelText: "Şifre",
                    suffixIcon: IconButton(
                      icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          showPassword = !showPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: !showPassword,
                  textInputAction: TextInputAction.done,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18.0),
                    child: Text(
                      error!,
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                SizedBox(height: 28),
                // Kayıt Butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      padding: EdgeInsets.symmetric(vertical: 18),
                      textStyle: TextStyle(fontSize: 18),
                      elevation: 3,
                    ),
                    child: loading
                        ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                        : Text("Kayıt Ol"),
                  ),
                ),
                // --------- GOOGLE İLE KAYIT BUTONU ---------
                SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Image.asset('assets/gmail_logo.png', height: 22), // Google logosu
                    label: Text("Google ile Kayıt Ol"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 2,
                    ),
                    onPressed: loading ? null : signInWithGoogle,
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: loading ? null : widget.onToggle,
                  child: Text(
                    "Zaten hesabın var mı? Giriş Yap",
                    style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    fetchRecipe();
  }

  Future<void> fetchRecipe() async {
    try {
      final url = Uri.parse("https://www.themealdb.com/api/json/v1/1/lookup.php?i=${widget.id}");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["meals"] != null) {
          setState(() {
            recipe = data["meals"][0];
            loading = false;
          });
        } else {
          setState(() {
            hata = "Tarif detayına ulaşılamadı.";
            loading = false;
          });
        }
      } else {
        setState(() {
          hata = "Sunucu hatası (${response.statusCode})";
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
              if (recipe?["strMealThumb"] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(recipe!["strMealThumb"], height: 200, width: double.infinity, fit: BoxFit.cover),
                ),
              SizedBox(height: 18),
              Text(recipe?["strMeal"] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.deepOrange)),
              SizedBox(height: 6),
              Text(recipe?["strArea"] != null ? "Mutfak: ${recipe?["strArea"]}" : "", style: TextStyle(color: Colors.indigo)),
              Text(recipe?["strCategory"] != null ? "Kategori: ${recipe?["strCategory"]}" : "", style: TextStyle(color: Colors.indigo)),
              Divider(),
              Text("Malzemeler:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              ...List.generate(20, (i) {
                String? malzeme = recipe?["strIngredient${i+1}"];
                String? miktar = recipe?["strMeasure${i+1}"];
                if (malzeme != null && malzeme.isNotEmpty && malzeme.trim() != "") {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text("• $malzeme ${miktar ?? ''}"),
                  );
                }
                return Container();
              }),
              Divider(),
              Text("Hazırlanışı:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              SizedBox(height: 6),
              Text(recipe?["strInstructions"] ?? '', style: TextStyle(fontSize: 15)),
              SizedBox(height: 18),
              if (recipe?["strYoutube"] != null && recipe!["strYoutube"].toString().isNotEmpty)
                TextButton.icon(
                  icon: Icon(Icons.video_library, color: Colors.red),
                  label: Text("YouTube’da İzle"),
                  onPressed: () async {
                    final url = recipe!["strYoutube"];
                    await launchUrl(Uri.parse(url));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
void _showFeedbackDialog(BuildContext context) {
  final TextEditingController _feedbackCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text("Görüşünü Bildir"),
      content: TextField(
        controller: _feedbackCtrl,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: "Buraya görüş ve önerinizi yazabilirsiniz.",
        ),
      ),
      actions: [
        TextButton(
          child: Text("İptal"),
          onPressed: () => Navigator.pop(ctx),
        ),
        ElevatedButton(
          child: Text("Gönder"),
          onPressed: () async {
            final feedback = _feedbackCtrl.text.trim();
            if (feedback.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Lütfen görüşünüzü yazın!")),
              );
              return;
            }
            try {
              await sendFeedbackToGoogleForm(feedback);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Görüşün iletildi, teşekkürler!")),
              );
            } catch (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Bir hata oluştu!")),
              );
            }
            Navigator.pop(ctx);
          },
        ),
      ],
    ),
  );
}
