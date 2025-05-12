import 'package:flutter/material.dart';
import '../models/email.dart';

class EmailDetailScreen extends StatelessWidget {
  final Email email;

  const EmailDetailScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết'),
        actions: [
          IconButton(
            icon: Icon(Icons.archive),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.mail),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email.subject,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Text(email.sender[0], style: TextStyle(color: Colors.white)),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email.sender,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'đến tôi',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Text(email.time),
                IconButton(
                  icon: Icon(email.isStarred ? Icons.star : Icons.star_border),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(Icons.reply),
                  onPressed: () {},
                ),
              ],
            ),
            SizedBox(height: 24),
            // Đây là nội dung email, trong thực tế sẽ dài hơn và có định dạng phong phú hơn
            Text(
              'Xin chào,\n\n${email.preview}\n\nĐây là nội dung đầy đủ của email. Trong ứng dụng thực tế, nội dung này sẽ dài hơn và có thể bao gồm định dạng phong phú như HTML, hình ảnh và các tệp đính kèm.\n\nTrân trọng,\n${email.sender}',
              style: TextStyle(fontSize: 16),
            ),
            if (email.hasAttachment) ...[
              SizedBox(height: 24),
              Text(
                'Tệp đính kèm',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_file),
                    SizedBox(width: 8),
                    Text('attachment.pdf (2.5 MB)'),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.download),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.reply),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.reply_all),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.forward),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}