import 'package:flutter/material.dart';
import '../models/email.dart';

class EmailDetailScreen extends StatelessWidget {
  final Email email;

  const EmailDetailScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(email.subject),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${email.sender}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Subject: ${email.subject}'),
            const SizedBox(height: 8),
            Text('Time: ${email.time}'),
            const SizedBox(height: 16),
            Text(email.preview),
            const SizedBox(height: 16),
            if (email.hasAttachment)
              const Text('Attachment: [File]', style: TextStyle(color: Colors.blue)),
            Row(
              children: [
                Icon(
                  email.isStarred ? Icons.star : Icons.star_border,
                  color: email.isStarred ? Colors.amber : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(email.isRead ? 'Read' : 'Unread'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}