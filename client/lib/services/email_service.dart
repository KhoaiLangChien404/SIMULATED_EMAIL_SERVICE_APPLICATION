import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'notification_service.dart';

class EmailService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _emailController = StreamController.broadcast();

  Stream<Map<String, dynamic>> get emailStream => _emailController.stream;

  Future<void> connect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:3000?token=$token'),
      );
      _channel!.stream.listen(
        (data) {
          final message = jsonDecode(data);
          if (message['type'] == 'new_email') {
            final email = message['email'];
            _emailController.add(email);
            // Hiển thị thông báo
            NotificationService.showNotification(
              id: email['id'],
              sender: email['senderPhone'],
              subject: email['subject'],
              timeReceived: email['timestamp'],
            );
            // Cập nhật badge (đếm email chưa đọc)
            _updateUnreadCount();
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
        onDone: () {
          print('WebSocket closed');
        },
      );
    } catch (e) {
      print('WebSocket connection error: $e');
    }
  }

  Future<void> _updateUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/emails?folder=inbox'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final emails = jsonDecode(response.body) as List;
        final unreadCount = emails.where((email) => !email['isRead']).length;
        NotificationService.updateBadge(unreadCount);
      }
    } catch (e) {
      print('Error updating unread count: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
  }

  void dispose() {
    disconnect();
    _emailController.close();
  }
}