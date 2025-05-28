import 'package:flutter/material.dart';
import '../models/email.dart';
import '../screens/email_detail_screen.dart';

class EmailListItem extends StatelessWidget {
  final Email email;

  const EmailListItem({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmailDetailScreen(email: email),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: email.isRead
            ? Colors.transparent
            : Theme.of(context).brightness == Brightness.light
                ? Colors.blue.shade50
                : Colors.blueGrey.shade800,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          email.sender,
                          style: TextStyle(
                            fontWeight: email.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        email.time,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.grey.shade700
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    email.subject,
                    style: TextStyle(
                      fontWeight: email.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    email.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.shade700
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            if (email.isStarred)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Icon(Icons.star, color: Colors.amber, size: 20),
              ),
            if (email.hasAttachment)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Icon(Icons.attach_file, color: Colors.grey, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}