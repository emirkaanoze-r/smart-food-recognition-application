import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'ai_recipe_detail_page.dart';
import 'user_profile_page.dart';


class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;

          // Drawer header
          Widget header = DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              image: DecorationImage(
                image: AssetImage('assets/.png'),
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.fastfood, color: Colors.indigo, size: 38),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bilge Besin",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 21,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Sağlıklı Beslen, Bilgilen!",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.indigo.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          Future<Widget> buildAdminTile() async {
            final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
            final userData = doc.data();
            if (userData != null && userData["role"] == "admin") {
              return ListTile(
                leading: Icon(Icons.admin_panel_settings, color: Colors.redAccent),
                title: Text("Admin Panel"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminPanelPage()),
                  );
                },
              );
            }
            return SizedBox.shrink();
          }

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              header,
              if (user != null) ...[
                ListTile(
                  leading: Icon(Icons.person_outline, color: Colors.indigo),
                  title: Text("Profilim"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UserProfilePage()),
                    );
                  },
                ),
                FutureBuilder<Widget>(
                  future: buildAdminTile(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                      return snapshot.data!;
                    }
                    return SizedBox.shrink();
                  },
                ),
              ] else ...[
                ListTile(
                  leading: Icon(Icons.login, color: Colors.indigo),
                  title: Text("Giriş Yap / Kayıt Ol"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AuthPage()),
                    );
                  },
                ),
              ],
              Divider(),
              ListTile(
                leading: Icon(Icons.home, color: Colors.indigo),
                title: Text("Ana Menü"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => TFLiteFlutterPage()),
                        (route) => false,
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.auto_awesome, color: Colors.orange),
                title: Text('Yapay Zeka Tarif'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AiRecipePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.history, color: Colors.indigo),
                title: Text('Geçmiş'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HistoryPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline, color: Colors.deepPurple),
                title: Text('Hakkımızda'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AboutPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.mail_outline, color: Colors.teal),
                title: Text('İletişim'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ContactPage()),
                  );
                },
              ),
              if (user != null)
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.redAccent),
                  title: Text("Çıkış Yap"),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pop(context);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}