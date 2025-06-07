import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'profile_screen.dart';
import 'compose_email_screen.dart';
import 'email_detail_screen.dart';
import 'login_screen.dart';
import 'manage_labels_screen.dart';
import 'theme_provider.dart';
import 'dart:async';

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
  Set<String> _selectedLabels = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final String _baseUrl = const String.fromEnvironment('BASE_URL', defaultValue: 'http://localhost:3000');
  List<String> _labels = [];
  bool _autoAnswerEnabled = false;
  String _autoAnswerMessage = '';
  int _defaultFontSize = 12;
  String _defaultFontFamily = 'Arial';
  bool _fromMe = false;
  DateTimeRange? _dateRange;
  bool _hasAttachments = false;
  bool _showAdvancedSearch = false;
  Map<int, bool> _emailReadStatus = {};
  int _unreadInboxCount = 0;
  Timer? _pollingTimer;
  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  bool _notificationsEnabled = true; // Added from new code

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference(); // Load notification setting on init
    if (!kIsWeb) {
      _notificationsPlugin = FlutterLocalNotificationsPlugin();
      _initializeNotifications();
    }
    _loadViewMode();
    _fetchProfile();
    _fetchEmails();
    _fetchLabels();
    _startPolling();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        print('Search query updated: $_searchQuery');
      });
      if (_currentFolder == 'draft') {
        _fetchDrafts();
      } else {
        _fetchEmails();
      }
    });
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    });
  }

  Future<void> _initializeNotifications() async {
    if (kIsWeb || _notificationsPlugin == null) return;
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _notificationsPlugin!.initialize(initializationSettings);
  }

  Future<void> _showNotification(Map<String, dynamic> email) async {
    if (!_notificationsEnabled) return; // Skip if notifications are disabled
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'New Email from ${email['senderPhone'] ?? 'Unknown'}: ${email['subject'] ?? 'No Subject'}',
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmailDetailScreen(
                    emailId: email['id'],
                    token: widget.token,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else if (_notificationsPlugin != null) {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'new_email_channel',
        'New Email Notifications',
        channelDescription: 'Notifications for new emails',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);
      await _notificationsPlugin!.show(
        email['id'] as int,
        'New Email from ${email['senderPhone'] ?? 'Unknown'}',
        email['subject'] ?? 'No Subject',
        platformChannelSpecifics,
        payload: jsonEncode({
          'sender': email['senderPhone'] ?? 'Unknown',
          'subject': email['subject'] ?? 'No Subject',
          'timestamp': email['timestamp'] ?? DateTime.now().toIso8601String(),
        }),
      );
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_currentFolder == 'inbox') {
        _checkForNewEmails();
      }
    });
  }

  Future<void> _checkForNewEmails() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/emails?folder=inbox');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      print('Polling emails response status: ${response.statusCode}');
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> fetchedEmails = jsonDecode(response.body);
        final newEmails = fetchedEmails.map((e) => Map<String, dynamic>.from(e)).toList();
        int newUnreadCount = 0;
        for (var email in newEmails) {
          final emailId = email['id'] as int;
          if (!_emails.any((e) => e['id'] == emailId)) {
            if (!(email['isRead'] == 1 || email['isRead'] == true)) {
              newUnreadCount++;
              await _showNotification(email);
            }
          }
        }
        if (newUnreadCount > 0) {
          setState(() {
            _unreadInboxCount += newUnreadCount;
            _emails = newEmails;
            _hoverStates = {for (var email in _emails) email['id'] as int: false};
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error polling emails: $e');
      print('Error polling emails: $e');
    }
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
    if (mounted) setState(() => _emails = []);
    if (_currentFolder == 'draft') {
      _fetchDrafts();
      return;
    }
    try {
      String queryParams = '';
      if (_searchQuery.isNotEmpty) queryParams += '&search=${Uri.encodeQueryComponent(_searchQuery)}';
      if (_fromMe) queryParams += '&fromMe=true';
      if (_dateRange != null) {
        queryParams += '&startDate=${Uri.encodeQueryComponent(_dateRange!.start.toIso8601String())}&endDate=${Uri.encodeQueryComponent(_dateRange!.end.toIso8601String())}';
      }
      if (_hasAttachments) queryParams += '&hasAttachments=true';
      if (_selectedLabels.isNotEmpty) {
        queryParams += '&labels=${Uri.encodeQueryComponent(_selectedLabels.join(','))}';
      }

      final uri = Uri.parse('$_baseUrl/api/emails?folder=$_currentFolder$queryParams');
      print('Fetching emails with URL: $uri');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      print('Emails response status: ${response.statusCode}');
      print('Emails response body: ${response.body}');
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> fetchedEmails = jsonDecode(response.body);
        setState(() {
          _emails = fetchedEmails.map((email) => Map<String, dynamic>.from(email)).toList();
          _emails = _emails.map((email) {
            final emailId = email['id'] as int;
            email['isRead'] = _emailReadStatus.containsKey(emailId)
                ? _emailReadStatus[emailId]!
                : (email['isRead'] == 1 || email['isRead'] == true);
            email['isStarred'] = email['isStarred'] == 1 || email['isStarred'] == true;
            email['isTrashed'] = email['isTrashed'] == 1 || email['isTrashed'] == true;
            return email;
          }).toList();
          _drafts = [];
          _error = _emails.isEmpty ? 'No emails found' : '';
          _hoverStates = {for (var email in _emails) email['id'] as int: false};
          if (_currentFolder == 'inbox') {
            _unreadInboxCount = _emails.where((e) => !(e['isRead'] as bool)).length;
          }
        });
      } else {
        if (mounted) setState(() => _error = 'Failed to fetch emails: ${jsonDecode(response.body)['error'] ?? response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error fetching emails: $e');
    }
  }

  Future<void> _fetchDrafts() async {
    try {
      String queryParams = '';
      if (_searchQuery.isNotEmpty) queryParams += '?search=${Uri.encodeQueryComponent(_searchQuery)}';
      if (_dateRange != null) {
        queryParams += '${queryParams.isEmpty ? '?' : '&'}startDate=${Uri.encodeQueryComponent(_dateRange!.start.toIso8601String())}&endDate=${Uri.encodeQueryComponent(_dateRange!.end.toIso8601String())}';
      }
      if (_hasAttachments) queryParams += '${queryParams.isEmpty ? '?' : '&'}hasAttachments=true';
      if (_selectedLabels.isNotEmpty) {
        queryParams += '${queryParams.isEmpty ? '?' : '&'}labels=${Uri.encodeQueryComponent(_selectedLabels.join(','))}';
      }

      final uri = Uri.parse('$_baseUrl/api/drafts$queryParams');
      print('Fetching drafts with URL: $uri');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      print('Drafts response status: ${response.statusCode}');
      print('Drafts response body: ${response.body}');
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> fetchedDrafts = jsonDecode(response.body);
        setState(() {
          _drafts = fetchedDrafts.map((draft) => Map<String, dynamic>.from(draft)).toList();
          _emails = [];
          _error = _drafts.isEmpty ? 'No drafts found' : '';
          _hoverStates = {for (var draft in _drafts) draft['id'] as int: false};
        });
      } else {
        if (mounted) setState(() => _error = 'Failed to fetch drafts: ${jsonDecode(response.body)['error'] ?? response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error fetching drafts: $e');
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/profile'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      print('Profile response status: ${response.statusCode}');
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _userName = data['name'] ?? 'User';
          _profilePicUrl = data['profilePic'];
          _autoAnswerEnabled = data['autoAnswerEnabled'] == 1 || data['autoAnswerEnabled'] == true;
          _autoAnswerMessage = data['autoAnswerMessage'] ?? '';
          _defaultFontSize = data['defaultFontSize'] ?? 12;
          _defaultFontFamily = data['defaultFontFamily'] ?? 'Arial';
        });
      } else {
        if (mounted) setState(() => _error = 'Failed to fetch profile: ${jsonDecode(response.body)['error'] ?? response.body}');
        print('Fetch profile failed with status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error fetching profile: $e');
      print('Fetch profile exception: $e');
    }
  }

  Future<void> _fetchLabels() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/labels'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _labels = data.cast<String>();
          _selectedLabels.removeWhere((label) => !_labels.contains(label));
        });
      } else {
        if (mounted) setState(() => _error = 'Failed to fetch labels: ${jsonDecode(response.body)['error'] ?? response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error fetching labels: $e');
    }
  }

  Future<void> _updateAction(int itemId, String action, bool value) async {
    try {
      if (_currentFolder == 'draft' && action == 'trash') {
        final response = await http.delete(
          Uri.parse('$_baseUrl/api/delete-draft/$itemId'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200 && mounted) {
          _fetchDrafts();
        } else {
          if (mounted) setState(() => _error = 'Failed to delete draft: ${jsonDecode(response.body)['error'] ?? response.body}');
          print('Delete draft failed: ${response.statusCode}, body: ${response.body}');
        }
        return;
      }

      final url = _currentFolder == 'draft' ? '$_baseUrl/api/update-draft-action' : '$_baseUrl/api/email-actions';
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

      if (response.statusCode == 200 && mounted) {
        if (_currentFolder == 'draft') {
          _fetchDrafts();
        } else {
          _fetchEmails();
          if (action == 'read' && !value) {
            setState(() => _unreadInboxCount++);
          } else if (action == 'read' && value) {
            setState(() => _unreadInboxCount = _unreadInboxCount > 0 ? _unreadInboxCount - 1 : 0);
          }
        }
      } else {
        if (mounted) setState(() => _error = 'Failed to update action: ${jsonDecode(response.body)['error'] ?? response.body}');
        print('Update action failed: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error updating action: $e');
      print('Update action exception: $e');
    }
  }

  Future<void> _updateEmailReadStatus(int emailId, bool isRead) async {
    if (mounted) {
      setState(() {
        _emailReadStatus[emailId] = isRead;
        final emailIndex = _emails.indexWhere((email) => email['id'] == emailId);
        if (emailIndex != -1) {
          _emails[emailIndex]['isRead'] = isRead;
          if (_currentFolder == 'inbox') {
            if (isRead) {
              _unreadInboxCount = _unreadInboxCount > 0 ? _unreadInboxCount - 1 : 0;
            } else {
              _unreadInboxCount++;
            }
          }
        }
      });
    }
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/email-actions'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'emailId': emailId,
          'action': 'read',
          'value': isRead,
        }),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        print('Failed to sync read status with server: ${response.body}');
      }
    } catch (e) {
      print('Error syncing read status: $e');
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
        _autoAnswerEnabled = result['autoAnswerEnabled'] ?? _autoAnswerEnabled;
        _autoAnswerMessage = result['autoAnswerMessage'] ?? _autoAnswerMessage;
        _defaultFontSize = result['defaultFontSize'] ?? 12;
        _defaultFontFamily = result['defaultFontFamily'] ?? 'Arial';
        _notificationsEnabled = result['notificationsEnabled'] ?? true; // Update from profile
        _saveNotificationPreference(); // Save updated preference
      });
    }
  }

  Future<void> _saveNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
  }

  void _switchFolder(String folder) {
    if (mounted) {
      setState(() {
        _currentFolder = folder;
        _selectedLabels.clear();
        _searchQuery = '';
        _searchController.clear();
        _emails = [];
        _drafts = [];
        _error = '';
        _fromMe = false;
        _dateRange = null;
        _hasAttachments = false;
      });
      if (_currentFolder == 'draft') {
        _fetchDrafts();
      } else {
        _fetchEmails();
      }
    }
  }

  void _toggleLabel(String label) {
    if (mounted) {
      setState(() {
        if (_selectedLabels.contains(label)) {
          _selectedLabels.remove(label);
        } else {
          _selectedLabels.add(label);
        }
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
    try {
      final decoded = jsonDecode(body);
      if (decoded is List && decoded.isNotEmpty && decoded[0].containsKey('insert')) {
        return (decoded[0]['insert'] as String).length > 50
            ? '${(decoded[0]['insert'] as String).substring(0, 50)}...'
            : decoded[0]['insert'] as String;
      }
    } catch (e) {
      return body.length > 50 ? '${body.substring(0, 50)}...' : body;
    }
    return body.length > 50 ? '${body.substring(0, 50)}...' : body;
  }

  Future<void> _navigateToCompose() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComposeEmailScreen(
          token: widget.token,
          defaultFontSize: _defaultFontSize,
          defaultFontFamily: _defaultFontFamily,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _currentFolder = 'inbox';
        _emails = [];
        _drafts = [];
        _error = '';
        _searchQuery = '';
        _searchController.clear();
        _fromMe = false;
        _dateRange = null;
        _hasAttachments = false;
      });
      _fetchEmails();
    }
  }

  void _showAdvancedSearchPanel() {
    setState(() {
      _showAdvancedSearch = !_showAdvancedSearch;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _dateRange = picked;
      });
      if (_currentFolder == 'draft') {
        _fetchDrafts();
      } else {
        _fetchEmails();
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _fromMe = false;
      _dateRange = null;
      _hasAttachments = false;
      _searchQuery = '';
      _searchController.clear();
      _selectedLabels.clear();
    });
    if (_currentFolder == 'draft') {
      _fetchDrafts();
    } else {
      _fetchEmails();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    if (_currentFolder == 'draft') {
                      _fetchDrafts();
                    } else {
                      _fetchEmails();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Search emails...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              if (_currentFolder == 'draft') {
                                _fetchDrafts();
                              } else {
                                _fetchEmails();
                              }
                            },
                          )
                        : null,
                  ),
                  style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                ),
              ),
              IconButton(
                icon: Icon(Icons.filter_alt, color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                onPressed: _showAdvancedSearchPanel,
                tooltip: 'Advanced Search',
              ),
            ],
          ),
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
              DrawerHeader(
                decoration: BoxDecoration(color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.blue),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email Folders',
                      style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.white, fontSize: 24),
                    ),
                    const Spacer(),
                    Text(
                      'Auto Answer: ${_autoAnswerEnabled ? 'On' : 'Off'}',
                      style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.white, fontSize: 16),
                    ),
                    Text(
                      'Current Time: ${TimeOfDay.now().format(context)} ${DateTime.now().toLocal().timeZoneName}, ${DateTime.now().toLocal().toString().split(' ')[0]}',
                      style: TextStyle(color: themeProvider.isDarkMode ? Colors.white70 : Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.inbox),
                title: Row(
                  children: [
                    const Text('Inbox'),
                    if (_unreadInboxCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Chip(
                          label: Text(
                            '$_unreadInboxCount',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        ),
                      ),
                  ],
                ),
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
              ExpansionTile(
                leading: const Icon(Icons.label),
                title: const Text('Labels'),
                trailing: Icon(
                  _selectedLabels.isEmpty ? Icons.arrow_forward_ios : Icons.arrow_drop_down,
                  size: 20,
                ),
                children: [
                  for (var label in _labels)
                    CheckboxListTile(
                      title: Text(label),
                      value: _selectedLabels.contains(label),
                      onChanged: (_) => _toggleLabel(label),
                    ),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.manage_search),
                title: const Text('Manage labels'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageLabelsScreen(token: widget.token),
                    ),
                  ).then((_) {
                    _fetchLabels();
                    if (_currentFolder == 'draft') {
                      _fetchDrafts();
                    } else {
                      _fetchEmails();
                    }
                  });
                },
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_showAdvancedSearch)
              Container(
                padding: const EdgeInsets.all(8.0),
                color: themeProvider.isDarkMode ? Colors.grey[900] : Colors.grey[200],
                child: Column(
                  children: [
                    if (_currentFolder != 'draft')
                      CheckboxListTile(
                        title: Text(
                          'From me',
                          style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                        ),
                        value: _fromMe,
                        onChanged: (value) {
                          setState(() {
                            _fromMe = value ?? false;
                          });
                          _fetchEmails();
                        },
                      ),
                    ListTile(
                      title: const Text('Date range'),
                      subtitle: _dateRange != null
                          ? Text(
                              '${_dateRange!.start.toString().split(' ')[0]} - ${_dateRange!.end.toString().split(' ')[0]}',
                            )
                          : const Text('Select date range'),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _selectDateRange,
                      ),
                    ),
                    CheckboxListTile(
                      title: Text(
                        'Has attachments',
                        style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                      ),
                      value: _hasAttachments,
                      onChanged: (value) {
                        setState(() {
                          _hasAttachments = value ?? false;
                        });
                        if (_currentFolder == 'draft') {
                          _fetchDrafts();
                        } else {
                          _fetchEmails();
                        }
                      },
                    ),
                    ElevatedButton(
                      onPressed: _resetFilters,
                      child: const Text('Reset Filters'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _error.isNotEmpty
                  ? Center(
                      child: Text(
                        _error,
                        style: TextStyle(color: themeProvider.isDarkMode ? Colors.red[400] : Colors.red),
                      ),
                    )
                  : (_searchQuery.isNotEmpty &&
                          ((_emails.isEmpty && _currentFolder != 'draft') || (_drafts.isEmpty && _currentFolder == 'draft')))
                      ? const Center(child: Text('Not found'))
                      : (_emails.isEmpty && _drafts.isEmpty)
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: _currentFolder == 'draft' ? _drafts.length : _emails.length,
                              itemBuilder: (context, index) {
                                final item = _currentFolder == 'draft' ? _drafts[index] : _emails[index];
                                final isRead = _currentFolder != 'draft' ? item['isRead'] as bool : false;
                                final isStarred = _currentFolder != 'draft' ? item['isStarred'] as bool : false;
                                final hasAttachments =
                                    _currentFolder != 'draft' && item['attachments'] != null && (item['attachments'] as List).isNotEmpty;
                                final hasDraftAttachment =
                                    _currentFolder == 'draft' && item['attachment'] != null && item['attachment'].isNotEmpty;
                                final itemId = item['id'] as int;
                                final isHovering = _hoverStates[itemId] ?? false;

                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) => mounted ? setState(() => _hoverStates[itemId] = true) : null,
                                  onExit: (_) => mounted ? setState(() => _hoverStates[itemId] = false) : null,
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (_currentFolder == 'draft') {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ComposeEmailScreen(
                                              token: widget.token,
                                              draft: item,
                                              defaultFontSize: _defaultFontSize,
                                              defaultFontFamily: _defaultFontFamily,
                                            ),
                                          ),
                                        );
                                        if (mounted) {
                                          setState(() {
                                            _drafts = [];
                                            _error = '';
                                          });
                                          _fetchDrafts();
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
                                        if (result != null && result is Map<String, dynamic> && mounted) {
                                          final updatedIsRead = result['isRead'] as bool?;
                                          final updatedIsStarred = result['isStarred'] as bool?;
                                          if (updatedIsRead != null) {
                                            _updateEmailReadStatus(item['id'], updatedIsRead);
                                          }
                                          if (updatedIsStarred != null) {
                                            setState(() {
                                              final emailIndex = _emails.indexWhere((e) => e['id'] == item['id']);
                                              if (emailIndex != -1) _emails[emailIndex]['isStarred'] = updatedIsStarred;
                                            });
                                          }
                                        }
                                      }
                                    },
                                    child: Container(
                                      color: _currentFolder == 'draft'
                                          ? Colors.grey[100]
                                          : (isRead ? Colors.grey[200] : Colors.white),
                                      child: ListTile(
                                        leading: Tooltip(
                                          message: isStarred ? 'starred' : 'not starred',
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: IconButton(
                                              icon: Icon(
                                                isStarred ? Icons.star : Icons.star_border,
                                                color: isStarred ? Colors.yellow[600] : Colors.grey[400],
                                                size: 24,
                                              ),
                                              onPressed: _currentFolder != 'draft'
                                                  ? () {
                                                      final newStarStatus = !isStarred;
                                                      if (mounted) setState(() => item['isStarred'] = newStarStatus);
                                                      _updateAction(itemId, 'star', newStarStatus);
                                                    }
                                                  : null,
                                              splashRadius: 20,
                                              iconSize: 24,
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
                                            fontWeight: _currentFolder == 'draft'
                                                ? FontWeight.normal
                                                : (isRead ? FontWeight.normal : FontWeight.bold),
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
                                                      fontWeight: _currentFolder == 'draft'
                                                          ? FontWeight.normal
                                                          : (isRead ? FontWeight.normal : FontWeight.bold),
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
                                                        Text(
                                                          'Attachment',
                                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              )
                                            : Text(
                                                _currentFolder == 'draft'
                                                    ? 'To: ${item['recipientPhone'] ?? 'No Recipient'}'
                                                    : 'From: ${item['senderPhone']}',
                                                style: TextStyle(
                                                  fontWeight: _currentFolder == 'draft'
                                                      ? FontWeight.normal
                                                      : (isRead ? FontWeight.normal : FontWeight.bold),
                                                ),
                                              ),
                                        trailing: isHovering
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Tooltip(
                                                    message: isRead ? 'Mark as unread' : 'Mark as read',
                                                    child: IconButton(
                                                      icon: Icon(
                                                        isRead ? Icons.mail : Icons.mail_outline,
                                                        size: 24,
                                                      ),
                                                      onPressed: _currentFolder != 'draft'
                                                          ? () {
                                                              final newReadStatus = !isRead;
                                                              _updateEmailReadStatus(itemId, newReadStatus);
                                                            }
                                                          : null,
                                                      splashRadius: 20,
                                                      iconSize: 24,
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
                                                  Tooltip(
                                                    message: 'Delete',
                                                    child: IconButton(
                                                      icon: const Icon(Icons.delete, size: 24),
                                                      onPressed: () {
                                                        _updateAction(itemId, 'trash', true);
                                                      },
                                                      splashRadius: 20,
                                                      iconSize: 24,
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
                                                ],
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _navigateToCompose,
          child: const Icon(Icons.edit),
        ),
      ),
    );
  }
}