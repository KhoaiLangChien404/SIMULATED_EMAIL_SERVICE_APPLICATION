import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/email.dart';
import '../widgets/email_list_item.dart';
import '../widgets/app_drawer.dart';
import 'compose_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  _InboxScreenState createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _storage = const FlutterSecureStorage();
  List<Email> emails = [];
  bool isSearching = false;
  final searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchEmails();
  }

  Future<void> _fetchEmails() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'token');
    final response = await http.get(
      Uri.parse('http://localhost:3000/api/emails'),
      headers: {'Authorization': 'Bearer $token'},
    );
    setState(() => _isLoading = false);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        emails = data.map((e) => Email(
          sender: e['sender'],
          subject: e['subject'],
          preview: e['body'].length > 50 ? e['body'].substring(0, 50) + '...' : e['body'],
          time: e['timestamp'].split(' ')[0], // Simplified for display
          isRead: e['isRead'] ?? false,
          isStarred: e['isStarred'] ?? false,
          hasAttachment: e['hasAttachment'] ?? false,
        )).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm email...',
                  border: InputBorder.none,
                ),
                autofocus: true,
              )
            : const Text('Hộp thư đến'),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) searchController.clear();
              });
            },
          ),
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage('https://placekitten.com/100/100'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: emails.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => EmailListItem(email: emails[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/compose'),
        icon: const Icon(Icons.edit),
        label: const Text('Soạn'),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: const Icon(Icons.mail), onPressed: () {}),
            IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
            IconButton(icon: const Icon(Icons.chat_bubble), onPressed: () {}),
          ],
        ),
      ),
    );
  }
}