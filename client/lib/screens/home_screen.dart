import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';
import 'compose_email_screen.dart';
import 'email_detail_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String token;
  const HomeScreen({required this.token, super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _emails = [];
  List<Map<String, dynamic>> _drafts = [];
  String _userName = 'User';
  String? _profilePicUrl;
  String _error = '';
  String _currentFolder = 'inbox';
  bool _isDetailedView = false;
  Map<int, bool> _hoverStates = {};
  final String _baseUrl = 'http://localhost:3000';

  @override
  void initState() {
    super.initState();
    _loadViewMode();
    _fetchProfile();
    _fetchEmails();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDetailedView = prefs.getBool('isDetailedView') ?? false;
      });
    }
  }

  Future<void> _saveViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDetailedView', _isDetailedView);
  }

  Future<void> _fetchEmails() async {
    if (mounted) setState(() => {_emails = [], _drafts = [], _error = ''});
    if (_currentFolder == 'draft') {
      _fetchDrafts();
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/emails?folder=$_currentFolder'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> fetchedEmails = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _emails = fetchedEmails.map((email) => Map<String, dynamic>.from(email)).toList();
            _drafts = [];
            _error = '';
            _hoverStates = {for (var email in _emails) email['id'] as int: false};
          });
        }
      } else {
        if (mounted) setState(() => _error = 'Failed to fetch emails: ${response.body}');
        print('Fetch emails failed with status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error fetching emails: $e');
      print('Fetch emails exception: $e');
    }
  }

  Future<void> _fetchDrafts() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/drafts'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> fetchedDrafts = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _drafts = fetchedDrafts.map((draft) => Map<String, dynamic>.from(draft)).toList();
            _emails = [];
            _error = '';
            _hoverStates = {for (var draft in _drafts) draft['id'] as int: false};
          });
        }
      } else {
        if (mounted) setState(() => _error = 'Failed to fetch drafts: ${response.body}');
        print('Fetch drafts failed with status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error fetching drafts: $e');
      print('Fetch drafts exception: $e');
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/profile'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _userName = data['name'] ?? 'User';
            _profilePicUrl = data['profilePic'];
          });
        }
      } else {
        if (mounted) setState(() => _error = 'Failed to fetch profile: ${response.body}');
        print('Fetch profile failed with status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error fetching profile: $e');
      print('Fetch profile exception: $e');
    }
  }

  Future<void> _updateAction(int itemId, String action, bool value) async {
    try {
      if (_currentFolder == 'draft' && action == 'trash') {
        final response = await http.delete(
          Uri.parse('$_baseUrl/api/delete-draft/$itemId'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          _fetchDrafts();
        } else {
          if (mounted) setState(() => _error = 'Failed to delete draft: ${response.body}');
          print('Delete draft failed: ${response.statusCode}, ${response.body}');
        }
        return;
      }

      final url = _currentFolder == 'draft'
          ? '$_baseUrl/api/update-draft-action'
          : '$_baseUrl/api/email-actions';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'draftId': itemId,
          'emailId': itemId,
          'action': action,
          'value': value,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (_currentFolder == 'draft') {
          _fetchDrafts();
        } else {
          _fetchEmails();
        }
      } else {
        if (mounted) setState(() => _error = 'Failed to update action: ${response.body}');
        print('Update action failed: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error updating action: $e');
      print('Update action exception: $e');
    }
  }

  Future<void> _goToProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileScreen(token: widget.token)),
    );
    if (result != null && result is Map<String, dynamic> && mounted) {
      setState(() {
        _userName = result['name'] ?? _userName;
        _profilePicUrl = result['profilePic'] ?? _profilePicUrl;
      });
    }
  }

  void _updateEmailReadStatus(int emailId, bool isRead) {
    if (mounted) {
      setState(() {
        final emailIndex = _emails.indexWhere((email) => email['id'] == emailId);
        if (emailIndex != -1) {
          _emails[emailIndex]['isRead'] = isRead;
        }
      });
    }
  }

  void _switchFolder(String folder) {
    if (mounted) {
      setState(() {
        _currentFolder = folder;
        _emails = [];
        _drafts = [];
        _error = '';
      });
      if (_currentFolder == 'draft') {
        _fetchDrafts();
      } else {
        _fetchEmails();
      }
    }
  }

  void _toggleViewMode() {
    if (mounted) {
      setState(() {
        _isDetailedView = !_isDetailedView;
      });
      _saveViewMode();
    }
  }

  String _getEmailPreview(String body) {
    if (body.length > 50) {
      return '${body.substring(0, 50)}...';
    }
    return body;
  }

  Future<void> _navigateToCompose() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ComposeEmailScreen(token: widget.token)),
    );
    if (mounted) {
      setState(() {
        _currentFolder = 'inbox'; // Reset to inbox
        _emails = [];
        _drafts = [];
        _error = '';
      });
      _fetchEmails(); // Refresh inbox emails
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Welcome, $_userName'),
          actions: [
            IconButton(
              icon: Icon(_isDetailedView ? Icons.view_list : Icons.view_agenda),
              tooltip: _isDetailedView ? 'Switch to Basic View' : 'Switch to Detailed View',
              onPressed: _toggleViewMode,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: _goToProfile,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: _profilePicUrl != null ? NetworkImage('$_baseUrl$_profilePicUrl') : null,
                  child: _profilePicUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue),
                child: Text('Email Folders', style: TextStyle(color: Colors.white, fontSize: 24)),
              ),
              ListTile(
                leading: const Icon(Icons.inbox),
                title: const Text('Inbox'),
                selected: _currentFolder == 'inbox',
                onTap: () {
                  _switchFolder('inbox');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Starred'),
                selected: _currentFolder == 'starred',
                onTap: () {
                  _switchFolder('starred');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.send),
                title: const Text('Sent'),
                selected: _currentFolder == 'sent',
                onTap: () {
                  _switchFolder('sent');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.drafts),
                title: const Text('Draft'),
                selected: _currentFolder == 'draft',
                onTap: () {
                  _switchFolder('draft');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Trash'),
                selected: _currentFolder == 'trash',
                onTap: () {
                  _switchFolder('trash');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
        body: (_emails.isEmpty && _drafts.isEmpty && _error.isEmpty)
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                : ListView.builder(
                    itemCount: _currentFolder == 'draft' ? _drafts.length : _emails.length,
                    itemBuilder: (context, index) {
                      final item = _currentFolder == 'draft' ? _drafts[index] : _emails[index];
                      final isRead = _currentFolder != 'draft' ? item['isRead'] as bool : (item['isRead'] ?? false);
                      final isStarred = _currentFolder != 'draft' ? item['isStarred'] as bool : false;
                      final hasAttachments = _currentFolder != 'draft' && item['attachments'] != null && (item['attachments'] as List).isNotEmpty;
                      final hasDraftAttachment = _currentFolder == 'draft' && item['attachment'] != null && item['attachment'].isNotEmpty;
                      final itemId = item['id'] as int;
                      final isHovering = _hoverStates[itemId] ?? false;

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => mounted ? setState(() => _hoverStates[itemId] = true) : null,
                        onExit: (_) => mounted ? setState(() => _hoverStates[itemId] = false) : null,
                        child: GestureDetector(
                          onTap: () async {
                            if (_currentFolder == 'draft') {
                              // Update UI manually when opening draft
                              if (!isRead && mounted) {
                                setState(() {
                                  _drafts[index]['isRead'] = true; // Update UI immediately
                                });
                              }
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ComposeEmailScreen(
                                    token: widget.token,
                                    draft: item,
                                  ),
                                ),
                              );
                              if (mounted) {
                                setState(() {
                                  _drafts = []; // Refresh drafts list
                                  _error = '';
                                });
                                _fetchDrafts(); // Refresh drafts when returning
                              }
                            } else {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EmailDetailScreen(
                                    emailId: item['id'],
                                    token: widget.token,
                                  ),
                                ),
                              );
                              if (result != null && result is Map<String, dynamic>) {
                                final updatedIsRead = result['isRead'] as bool?;
                                final updatedIsStarred = result['isStarred'] as bool?;
                                if (updatedIsRead != null) _updateEmailReadStatus(item['id'], updatedIsRead);
                                if (updatedIsStarred != null && mounted) {
                                  setState(() {
                                    final emailIndex = _emails.indexWhere((e) => e['id'] == item['id']);
                                    if (emailIndex != -1) _emails[emailIndex]['isStarred'] = updatedIsStarred;
                                  });
                                }
                              }
                            }
                          },
                          child: Container(
                            color: _currentFolder == 'draft' ? Colors.grey[100] : (isRead ? Colors.grey[200] : Colors.grey[50]),
                            child: ListTile(
                              leading: Tooltip(
                                message: isStarred ? 'starred' : 'not starred',
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: IconButton(
                                    icon: Icon(
                                      isStarred ? Icons.star : Icons.star_border,
                                      color: isStarred ? Colors.yellow[700] : null,
                                      size: 20,
                                    ),
                                    onPressed: _currentFolder != 'draft'
                                        ? () {
                                            final newStarStatus = !isStarred;
                                            if (mounted) setState(() => item['isStarred'] = newStarStatus);
                                            _updateAction(itemId, 'star', newStarStatus);
                                          }
                                        : null,
                                    splashRadius: 20,
                                    iconSize: 20,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    style: IconButton.styleFrom(
                                      side: BorderSide(
                                        color: isHovering ? Colors.grey[700]! : Colors.grey[400]!,
                                        width: 1,
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                item['subject'] ?? 'No Subject',
                                style: TextStyle(
                                  fontWeight: _currentFolder == 'draft' ? FontWeight.normal : (isRead ? FontWeight.normal : FontWeight.bold),
                                ),
                              ),
                              subtitle: _isDetailedView
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _currentFolder == 'draft'
                                              ? 'To: ${item['recipientPhone'] ?? 'No Recipient'}'
                                              : 'From: ${item['senderPhone']}',
                                          style: TextStyle(
                                            fontWeight: _currentFolder == 'draft' ? FontWeight.normal : (isRead ? FontWeight.normal : FontWeight.bold),
                                          ),
                                        ),
                                        Text(
                                          _getEmailPreview(item['body'] ?? ''),
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                        if (hasAttachments || hasDraftAttachment)
                                          Row(
                                            children: [
                                              const Icon(Icons.attach_file, size: 16, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text('Attachment', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                            ],
                                          ),
                                      ],
                                    )
                                  : Text(
                                      _currentFolder == 'draft'
                                          ? 'To: ${item['recipientPhone'] ?? 'No Recipient'}'
                                          : 'From: ${item['senderPhone']}',
                                      style: TextStyle(
                                        fontWeight: _currentFolder == 'draft' ? FontWeight.normal : (isRead ? FontWeight.normal : FontWeight.bold),
                                      ),
                                    ),
                              trailing: isHovering
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Tooltip(
                                          message: isRead ? 'mark as unread' : 'mark as read',
                                          child: IconButton(
                                            icon: Icon(
                                              isRead ? Icons.mail : Icons.mail_outline,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              final newReadStatus = !isRead;
                                              if (mounted) {
                                                setState(() {
                                                  if (_currentFolder == 'draft') {
                                                    _drafts[index]['isRead'] = newReadStatus;
                                                  } else {
                                                    _emails[index]['isRead'] = newReadStatus;
                                                  }
                                                });
                                              }
                                              _updateAction(itemId, 'read', newReadStatus);
                                            },
                                            splashRadius: 20,
                                            iconSize: 20,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            style: IconButton.styleFrom(
                                              side: BorderSide(
                                                color: Colors.grey[700]!,
                                                width: 1,
                                                style: BorderStyle.solid,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Tooltip(
                                          message: 'delete',
                                          child: IconButton(
                                            icon: const Icon(Icons.delete, size: 20),
                                            onPressed: () {
                                              _updateAction(itemId, 'trash', true);
                                            },
                                            splashRadius: 20,
                                            iconSize: 20,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            style: IconButton.styleFrom(
                                              side: BorderSide(
                                                color: Colors.grey[700]!,
                                                width: 1,
                                                style: BorderStyle.solid,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: _navigateToCompose,
          child: const Icon(Icons.edit),
        ),
      ),
    );
  }
}