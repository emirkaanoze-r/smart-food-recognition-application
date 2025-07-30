import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart'; // ← Bu eksik
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
Future<void> sendFeedbackToGoogleForm(String feedback) async {
  final url = Uri.parse('https://docs.google.com/forms/u/0/d/e/1FAIpQLSe2LhsHzz9aYE89ho4FsQNb9fxlw75swbrlU1PtAYUqFGuVXw/formResponse');
  final response = await http.post(
    url,
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Accept": "application/json",
    },
    body: {
      'entry.1769732033': feedback,
    },
  );
  print("YANIT: ${response.statusCode}, BODY: ${response.body}");
  if (response.statusCode != 200 && response.statusCode != 302) {
    throw Exception("Görüş gönderilemedi!");
  }
}
Widget buildFeedbackList() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('feedback')
        .orderBy('timestamp', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return CircularProgressIndicator();
      }
      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Text("Kullanıcıdan geri bildirim yok.");
      }

      final feedbacks = snapshot.data!.docs;

      return ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: feedbacks.length,
        separatorBuilder: (_, __) => Divider(),
        itemBuilder: (context, index) {
          final data = feedbacks[index].data() as Map<String, dynamic>;
          final message = data['message'] ?? 'Boş mesaj';
          final email = data['email'] ?? 'Bilinmeyen kullanıcı';
          final time = data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).toDate()
              : null;

          final formattedDate = time != null
              ? DateFormat('dd MMMM yyyy – HH:mm', 'tr_TR').format(time)
              : '';

          return ListTile(
            leading: Icon(Icons.feedback_outlined, color: Colors.teal),
            title: Text(message),
            subtitle: Text("$email\n$formattedDate"),
            isThreeLine: true,
          );
        },
      );
    },
  );
}


