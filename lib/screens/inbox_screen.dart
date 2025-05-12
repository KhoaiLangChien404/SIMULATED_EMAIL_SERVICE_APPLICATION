import 'package:flutter/material.dart';
import '../data/sample_data.dart';
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
  late List<Email> emails;
  bool isSearching = false;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    emails = SampleData.getEmails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm email...',
                  border: InputBorder.none,
                ),
                autofocus: true,
              )
            : Text('Hộp thư đến'),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  searchController.clear();
                }
              });
            },
          ),
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage('https://placekitten.com/100/100'),
          ),
          SizedBox(width: 16),
        ],
      ),
      drawer: AppDrawer(),
      body: ListView.separated(
        itemCount: emails.length,
        separatorBuilder: (context, index) => Divider(height: 1),
        itemBuilder: (context, index) {
          return EmailListItem(email: emails[index]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ComposeScreen()),
          );
        },
        icon: Icon(Icons.edit),
        label: Text('Soạn'),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.mail),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.videocam),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.chat_bubble),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}