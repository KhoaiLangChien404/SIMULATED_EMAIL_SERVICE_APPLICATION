import 'package:flutter/material.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  _ComposeScreenState createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final toController = TextEditingController();
  final subjectController = TextEditingController();
  final bodyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Soạn thư'),
        actions: [
          IconButton(
            icon: Icon(Icons.attachment),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: () {
              // Here you would handle sending the email
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: toController,
              decoration: InputDecoration(
                labelText: 'Đến',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: subjectController,
              decoration: InputDecoration(
                labelText: 'Chủ đề',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: bodyController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Soạn email',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    toController.dispose();
    subjectController.dispose();
    bodyController.dispose();
    super.dispose();
  }
}