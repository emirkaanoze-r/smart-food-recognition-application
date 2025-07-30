import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailCtrl = TextEditingController();
  String? mesaj;
  bool loading = false;

  Future<void> resetPassword() async {
    setState(() {
      loading = true;
      mesaj = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailCtrl.text.trim(),
      );
      setState(() {
        mesaj = "📧 Şifre sıfırlama e-postası gönderildi!";
      });
    } catch (e) {
      setState(() {
        mesaj = "Hata oluştu: ${e.toString()}";
      });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Şifre Sıfırla"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: "Kayıtlı E-Posta Adresi",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : resetPassword,
              child: loading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Şifre Sıfırlama Maili Gönder"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
            if (mesaj != null) ...[
              SizedBox(height: 20),
              Text(
                mesaj!,
                style: TextStyle(
                  color: mesaj!.contains("Hata") ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
