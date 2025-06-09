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
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
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
    if (!_notificationsEnabled) return;
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
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> fetchedEmails = jsonDecode(response.body);
        setState(() {
          _emails = fetchedEmails.map((email) => Map<String, dynamic>.from(email)).toList();
          _emails = _emails.map((email) {
            final emailId = email['id'] as int;
            email['isRead'] = _emailReadStatus.containsKey(emailId)
                ? _emailReadStatus[emailId]!
                : (email['isRead'] == true || email['isRead'] == 1);
            email['isStarred'] = email['isStarred'] == true || email['isStarred'] == 1;
            email['isTrashed'] = email['isTrashed'] == true || email['isTrashed'] == 1;
            email['isAutoReply'] = email['isAutoReply'] == true || email['isAutoReply'] == 1;
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
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
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
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _userName = data['name'] ?? 'User';
          _profilePicUrl = data['profilePic'];
          _autoAnswerEnabled = data['autoAnswerEnabled'] == true || data['autoAnswerEnabled'] == 1;
          _autoAnswerMessage = data['autoAnswerMessage'] ?? '';
          _defaultFontSize = data['defaultFontSize'] ?? 12;
          _defaultFontFamily = data['defaultFontFamily'] ?? 'Arial';
        });
      } else {
        if (mounted) setState(() => _error = 'Failed to fetch profile: ${jsonDecode(response.body)['error'] ?? response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error fetching profile: $e');
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
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error updating action: $e');
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
        _notificationsEnabled = result['notificationsEnabled'] ?? true;
        _saveNotificationPreference();
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComposeEmailScreen(
          token: widget.token,
          defaultFontSize: _defaultFontSize,
          defaultFontFamily: _defaultFontFamily,
        ),
      ),
    );
    if (result != null && mounted) {
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
          elevation: 0,
          backgroundColor: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
          title: Container(
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm email...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade600),
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
                    : IconButton(
                        icon: Icon(Icons.filter_list, color: Colors.grey.shade600),
                        onPressed: _showAdvancedSearchPanel,
                      ),
              ),
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                fontFamily: _defaultFontFamily,
                fontSize: _defaultFontSize.toDouble(),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isDetailedView ? Icons.view_list : Icons.view_agenda,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
              ),
              tooltip: _isDetailedView ? 'Chuyển sang chế độ xem cơ bản' : 'Chuyển sang chế độ xem chi tiết',
              onPressed: _toggleViewMode,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: _goToProfile,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _profilePicUrl != null ? NetworkImage('$_baseUrl$_profilePicUrl') : null,
                  child: _profilePicUrl == null ? const Icon(Icons.person, color: Colors.grey, size: 10) : null,
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: themeProvider.isDarkMode
                        ? [Colors.grey.shade800, Colors.grey.shade900]
                        : [Colors.blue.shade600, Colors.blue.shade800],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _profilePicUrl != null ? NetworkImage('$_baseUrl$_profilePicUrl') : null,
                      child: _profilePicUrl == null ? const Icon(Icons.person, size: 30, color: Colors.grey) : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _userName,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Trả lời tự động: ${_autoAnswerEnabled ? 'Bật' : 'Tắt'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const Spacer(),
                    Text(
                      'Thời gian: ${TimeOfDay.now().format(context)} ${DateTime.now().toLocal().timeZoneName}, ${DateTime.now().toLocal().toString().split(' ')[0]}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.inbox),
                      title: Row(
                        children: [
                          const Text('Hộp thư đến'),
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
                      selectedTileColor: Colors.blue.shade100,
                      onTap: () {
                        _switchFolder('inbox');
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.star),
                      title: const Text('Đã gắn sao'),
                      selected: _currentFolder == 'starred',
                      selectedTileColor: Colors.blue.shade100,
                      onTap: () {
                        _switchFolder('starred');
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.send),
                      title: const Text('Đã gửi'),
                      selected: _currentFolder == 'sent',
                      selectedTileColor: Colors.blue.shade100,
                      onTap: () {
                        _switchFolder('sent');
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.drafts),
                      title: const Text('Bản thảo'),
                      selected: _currentFolder == 'draft',
                      selectedTileColor: Colors.blue.shade100,
                      onTap: () {
                        _switchFolder('draft');
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete),
                      title: const Text('Thùng rác'),
                      selected: _currentFolder == 'trash',
                      selectedTileColor: Colors.blue.shade100,
                      onTap: () {
                        _switchFolder('trash');
                        Navigator.pop(context);
                      },
                    ),
                    ExpansionTile(
                      leading: const Icon(Icons.label),
                      title: const Text('Nhãn'),
                      trailing: Icon(
                        _selectedLabels.isEmpty ? Icons.arrow_forward_ios : Icons.arrow_drop_down,
                        size: 16,
                      ),
                      children: [
                        for (var label in _labels)
                          CheckboxListTile(
                            title: Text(label),
                            value: _selectedLabels.contains(label),
                            onChanged: (_) => _toggleLabel(label),
                            activeColor: Colors.blue.shade700,
                          ),
                      ],
                    ),
                    ListTile(
                      leading: const Icon(Icons.manage_search),
                      title: const Text('Quản lý nhãn'),
                      onTap: () {
                        Navigator.pop(context);
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
            ],
          ),
        ),
        body: Column(
          children: [
            if (_showAdvancedSearch)
              Card(
                elevation: 4,
                margin: const EdgeInsets.all(8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tìm kiếm nâng cao',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (_currentFolder != 'draft')
                        CheckboxListTile(
                          title: Text(
                            'Từ tôi',
                            style: TextStyle(
                              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                              fontFamily: _defaultFontFamily,
                            ),
                          ),
                          value: _fromMe,
                          onChanged: (value) {
                            setState(() {
                              _fromMe = value ?? false;
                            });
                            _fetchEmails();
                          },
                          activeColor: Colors.blue.shade700,
                        ),
                      ListTile(
                        title: Text(
                          'Khoảng thời gian',
                          style: TextStyle(
                            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                            fontFamily: _defaultFontFamily,
                          ),
                        ),
                        subtitle: _dateRange != null
                            ? Text(
                                '${_dateRange!.start.toString().split(' ')[0]} - ${_dateRange!.end.toString().split(' ')[0]}',
                                style: TextStyle(
                                  color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                                  fontFamily: _defaultFontFamily,
                                ),
                              )
                            : Text(
                                'Chọn khoảng thời gian',
                                style: TextStyle(
                                  color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                                  fontFamily: _defaultFontFamily,
                                ),
                              ),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _selectDateRange,
                        ),
                      ),
                      CheckboxListTile(
                        title: Text(
                          'Có tệp đính kèm',
                          style: TextStyle(
                            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                            fontFamily: _defaultFontFamily,
                          ),
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
                        activeColor: Colors.blue.shade700,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade700),
                        ),
                        child: TextButton(
                          onPressed: _resetFilters,
                          child: Text(
                            'Đặt lại bộ lọc',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontFamily: _defaultFontFamily,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: _error.isNotEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error,
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontFamily: _defaultFontFamily,
                            fontSize: _defaultFontSize.toDouble(),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : (_searchQuery.isNotEmpty &&
                          ((_emails.isEmpty && _currentFolder != 'draft') || (_drafts.isEmpty && _currentFolder == 'draft')))
                      ? Center(
                          child: Text(
                            'Không tìm thấy kết quả',
                            style: TextStyle(
                              color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                              fontFamily: _defaultFontFamily,
                              fontSize: _defaultFontSize.toDouble(),
                            ),
                          ),
                        )
                      : (_emails.isEmpty && _drafts.isEmpty)
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: _currentFolder == 'draft' ? _drafts.length : _emails.length,
                              itemBuilder: (context, index) {
                                final item = _currentFolder == 'draft' ? _drafts[index] : _emails[index];
                                final isRead = _currentFolder != 'draft' ? item['isRead'] as bool : false;
                                final isStarred = _currentFolder != 'draft' ? item['isStarred'] as bool : false;
                                final hasAttachments = _currentFolder != 'draft' &&
                                    item['attachments'] != null &&
                                    (item['attachments'] as List).isNotEmpty;
                                final hasDraftAttachment =
                                    _currentFolder == 'draft' && item['attachment'] != null && item['attachment'].isNotEmpty;
                                final itemId = item['id'] as int;
                                final isHovering = _hoverStates[itemId] ?? false;
                                final isAutoReply = _currentFolder != 'draft' ? item['isAutoReply'] as bool : false;
                                final senderPhone = isAutoReply ? item['recipientPhone'] : item['senderPhone'];

                                return MouseRegion(
                                  onEnter: (_) => setState(() => _hoverStates[itemId] = true),
                                  onExit: (_) => setState(() => _hoverStates[itemId] = false),
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (_currentFolder != 'draft' && !isRead) {
                                        await _updateEmailReadStatus(itemId, true);
                                      }
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => _currentFolder == 'draft'
                                              ? ComposeEmailScreen(
                                                  token: widget.token,
                                                  draftId: itemId.toString(),
                                                  defaultFontSize: _defaultFontSize,
                                                  defaultFontFamily: _defaultFontFamily,
                                                )
                                              : EmailDetailScreen(
                                                  emailId: itemId,
                                                  token: widget.token,
                                                ),
                                        ),
                                      );
                                      if (result != null && mounted) {
                                        if (_currentFolder == 'draft') {
                                          _fetchDrafts();
                                        } else {
                                          _fetchEmails();
                                        }
                                      }
                                    },
                                    child: Card(
                                      elevation: isHovering ? 8 : 2,
                                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      color: isRead
                                          ? (themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white)
                                          : (themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade50),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          children: [
                                            if (_currentFolder != 'draft')
                                              IconButton(
                                                icon: Icon(
                                                  isStarred ? Icons.star : Icons.star_border,
                                                  color: isStarred ? Colors.yellow.shade700 : Colors.grey.shade600,
                                                  size: 20,
                                                ),
                                                onPressed: () => _updateAction(itemId, 'star', !isStarred),
                                                tooltip: isStarred ? 'Bỏ gắn sao' : 'Gắn sao',
                                              ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          senderPhone ?? 'Unknown',
                                                          style: TextStyle(
                                                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                                            color: themeProvider.isDarkMode
                                                                ? Colors.white
                                                                : Colors.black87,
                                                            fontSize: _defaultFontSize.toDouble(),
                                                            fontFamily: _defaultFontFamily,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Text(
                                                        item['timestamp'] != null
                                                            ? DateTime.parse(item['timestamp'])
                                                                .toLocal()
                                                                .toString()
                                                                .split(' ')[0]
                                                            : '',
                                                        style: TextStyle(
                                                          color: themeProvider.isDarkMode
                                                              ? Colors.white70
                                                              : Colors.grey.shade600,
                                                          fontSize: (_defaultFontSize - 2).toDouble(),
                                                          fontFamily: _defaultFontFamily,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    item['subject'] ?? '(Không có chủ đề)',
                                                    style: TextStyle(
                                                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                                      color: themeProvider.isDarkMode
                                                          ? Colors.white
                                                          : Colors.black87,
                                                      fontSize: _defaultFontSize.toDouble(),
                                                      fontFamily: _defaultFontFamily,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (_isDetailedView)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 4.0),
                                                      child: Text(
                                                        _getEmailPreview(item['body'] ?? ''),
                                                        style: TextStyle(
                                                          color: themeProvider.isDarkMode
                                                              ? Colors.white70
                                                              : Colors.grey.shade600,
                                                          fontSize: (_defaultFontSize - 2).toDouble(),
                                                          fontFamily: _defaultFontFamily,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  if (hasAttachments || hasDraftAttachment)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 4.0),
                                                      child: Icon(
                                                        Icons.attach_file,
                                                        size: 16,
                                                        color: themeProvider.isDarkMode
                                                            ? Colors.white70
                                                            : Colors.grey.shade600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (isHovering && _currentFolder != 'draft')
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      isRead ? Icons.mark_email_unread : Icons.mark_email_read,
                                                      color: Colors.grey.shade600,
                                                      size: 20,
                                                    ),
                                                    onPressed: () => _updateAction(itemId, 'read', !isRead),
                                                    tooltip: isRead ? 'Đánh dấu chưa đọc' : 'Đánh dấu đã đọc',
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.delete,
                                                      color: Colors.grey.shade600,
                                                      size: 20,
                                                    ),
                                                    onPressed: () => _updateAction(itemId, 'trash', true),
                                                    tooltip: 'Xóa',
                                                  ),
                                                ],
                                              ),
                                            if (isHovering && _currentFolder == 'draft')
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete,
                                                  color: Colors.grey.shade600,
                                                  size: 20,
                                                ),
                                                onPressed: () => _updateAction(itemId, 'trash', true),
                                                tooltip: 'Xóa bản nháp',
                                              ),
                                          ],
                                        ),
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
          backgroundColor: Colors.blue.shade700,
          elevation: 6,
          tooltip: 'Soạn email',
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ),
    );
  }
}

extension ListMapExtension on List {
  List<Map<String, dynamic>> toMapList() => map((e) => Map<String, dynamic>.from(e)).toList();
}