import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'compose_email_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:math' as math;

class EmailDetailScreen extends StatefulWidget {
  final String token;
  final int emailId;

  const EmailDetailScreen({required this.token, required this.emailId, super.key});

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  Map<String, dynamic>? _email;
  String _errorMessage = '';
  String? _pdfError;
  bool _isLoading = true;
  final String _baseUrl = 'http://localhost:3000';
  Map<String, String?> _localFilePaths = {};
  Map<String, String?> _originalFileNames = {};
  List<String> _availableLabels = [];

  @override
  void initState() {
    super.initState();
    _fetchEmailAndLabels();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchEmailAndLabels() async {
    try {
      // Fetch email
      final emailResponse = await http.get(
        Uri.parse('$_baseUrl/api/emails/${widget.emailId}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (emailResponse.statusCode == 200) {
        final data = jsonDecode(emailResponse.body);
        setState(() {
          _email = data;
          _isLoading = false;
        });

        if (_email!['attachments'] != null && (_email!['attachments'] as List).isNotEmpty) {
          for (var attachment in _email!['attachments'] as List<dynamic>) {
            await _downloadAttachment(
              attachment['filePath'] as String?,
              attachment['originalFileName'] as String?,
            );
          }
        }

        if (!(_email!['isRead'] as bool)) {
          await _updateAction('read', true);
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch email: ${jsonDecode(emailResponse.body)['error'] ?? emailResponse.body}';
          _isLoading = false;
        });
      }

      // Fetch available labels
      await _fetchAvailableLabels();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: Failed to fetch email or labels. $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAvailableLabels() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/labels'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (mounted) {
          setState(() {
            _availableLabels = data.cast<String>();
            if (_email != null) {
              final currentLabels = List<String>.from(_email!['labels'] as List<dynamic>? ?? []);
              _email!['labels'] = currentLabels.where((label) => _availableLabels.contains(label)).toList();
            }
          });
        }
      } else {
        print('Failed to fetch labels: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('Error fetching labels: $e');
    }
  }

  Future<void> _downloadAttachment(String? filePath, String? originalFileName) async {
    if (filePath == null) return;

    try {
      if (kIsWeb) {
        if (mounted) {
          setState(() {
            _localFilePaths[filePath] = '$_baseUrl$filePath';
            _originalFileNames[filePath] = originalFileName;
          });
        }
      } else {
        final response = await http.get(
          Uri.parse('$_baseUrl$filePath'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final tempDir = await getTemporaryDirectory();
          final fileName = originalFileName ?? filePath.split('/').last;
          final localFile = File('${tempDir.path}/$fileName');
          await localFile.writeAsBytes(bytes);
          setState(() {
            _localFilePaths[filePath] = localFile.path;
            _originalFileNames[filePath] = originalFileName;
          });
        } else {
          print('Failed to download attachment: $filePath, Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error downloading attachment: $e');
    }
  }

  Future<void> _assignLabel(int emailId, String label, bool value) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/email-labels'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'emailId': emailId,
          'label': label,
          'value': value,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> currentLabels = List<dynamic>.from(_email!['labels'] as List<dynamic>? ?? []);
        if (value) {
          if (!currentLabels.contains(label)) {
            currentLabels.add(label);
          }
        } else {
          currentLabels.remove(label);
        }
        setState(() {
          _email!['labels'] = currentLabels;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _errorMessage = 'Server error: Label assignment endpoint not found. Please contact support.';
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to assign label: ${response.body}';
        });
        print('Assign label failed: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error assigning label: $e';
        });
        print('Assign label exception: $e');
      }
    }
  }

  Future<bool> _updateAction(String action, bool value) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/email-actions'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'emailId': widget.emailId,
          'action': action,
          'value': value,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return false;

      if (response.statusCode == 200) {
        setState(() {
          if (_email != null) {
            _email![action == 'read' ? 'isRead' : 'isStarred'] = value;
          }
        });
        return true;
      } else {
        setState(() {
          _errorMessage = 'Failed to update email: ${jsonDecode(response.body)['error'] ?? response.body}';
        });
        print('Failed to update action: ${response.statusCode}, ${response.body}');
        return false;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error updating email: $e';
        });
        print('Update action error: $e');
      }
      return false;
    }
  }

  Future<void> _launchFile(String filePath) async {
    final originalFileName = _originalFileNames[filePath];
    final downloadUrl = '$_baseUrl/api/download/${Uri.encodeComponent(filePath)}';

    try {
      final response = await http.get(
        Uri.parse(downloadUrl),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;

        if (kIsWeb) {
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', originalFileName ?? filePath.split('/').last)
            ..click();
          html.Url.revokeObjectUrl(url);
        } else {
          final tempDir = await getTemporaryDirectory();
          final fileName = originalFileName ?? filePath.split('/').last;
          final localFile = File('${tempDir.path}/$fileName');
          await localFile.writeAsBytes(bytes);
          final uri = Uri.file(localFile.path);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            print('Could not launch $uri');
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to download file: ${jsonDecode(response.body)['error'] ?? response.body}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error downloading file: $e';
        });
      }
    }
  }

  void _showMoreOptions(String value) {
    switch (value) {
      case 'Reply':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ComposeEmailScreen(
              token: widget.token,
              replyTo: _email,
            ),
          ),
        );
        break;
      case 'Forward':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ComposeEmailScreen(
              token: widget.token,
              forwardFrom: _email,
            ),
          ),
        );
        break;
      case 'Metadata':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Metadata'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('From: ${_email!['senderPhone'] as String? ?? 'Unknown'}'),
                Text('To: ${_email!['recipientPhone'] as String? ?? 'Unknown'}'),
                if (_email!['cc'] != null && (_email!['cc'] as String).isNotEmpty)
                  Text('CC: ${_email!['cc']}'),
                if (_email!['bcc'] != null && (_email!['bcc'] as String).isNotEmpty)
                  Text('BCC: ${_email!['bcc']}'),
                Text('Date: ${_email!['timestamp'] as String? ?? 'N/A'}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        break;
      case 'Move to Trash':
        _updateAction('trash', true);
        if (mounted) {
          Navigator.pop(context, {
            'isRead': _email!['isRead'] as bool,
            'isStarred': _email!['isStarred'] as bool,
          });
        }
        break;
    }
  }

  Future<void> _markAsUnread() async {
    if (_email != null && (_email!['isRead'] as bool)) {
      final success = await _updateAction('read', false);
      if (success && mounted) {
        Navigator.pop(context, {
          'isRead': false,
          'isStarred': _email!['isStarred'] as bool,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Email Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Email Details')),
        body: Center(
          child: Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final List<dynamic> currentLabels = (_email!['labels'] as List<dynamic>?) ?? [];

    // Extract plain text from body, removing JSON-like structures if present
    String displayBody = _email!['body'] as String? ?? '';
    try {
      final decoded = jsonDecode(displayBody);
      if (decoded is List && decoded.isNotEmpty && decoded[0].containsKey('insert')) {
        displayBody = decoded[0]['insert'] as String? ?? '';
      }
    } catch (e) {
      // If not JSON, use raw body
      displayBody = _email!['body'] as String? ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _email!['subject'] as String? ?? 'No Subject',
                  style: const TextStyle(fontSize: 18, fontFamily: 'Roboto'),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (mounted) {
              Navigator.pop(context, {
                'isRead': _email!['isRead'] as bool,
                'isStarred': _email!['isStarred'] as bool,
              });
            }
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.label_outline),
            tooltip: 'labels',
            onSelected: (String label) {
              if (!mounted) return;
              _assignLabel(widget.emailId, label, !currentLabels.contains(label));
            },
            itemBuilder: (BuildContext context) => _availableLabels.map<PopupMenuEntry<String>>((String label) {
              return CheckedPopupMenuItem<String>(
                value: label,
                checked: currentLabels.contains(label),
                child: Text(label),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.mail),
            tooltip: 'Mark as unread',
            onPressed: _markAsUnread,
          ),
          IconButton(
            icon: Icon(
              _email!['isStarred'] as bool ? Icons.star : Icons.star_border,
              color: _email!['isStarred'] as bool ? Colors.yellow[700] : Colors.black,
            ),
            tooltip: _email!['isStarred'] as bool ? 'starred' : 'not starred',
            onPressed: () async {
              final previousStarredStatus = _email!['isStarred'] as bool;
              setState(() {
                _email!['isStarred'] = !previousStarredStatus;
              });
              final success = await _updateAction('star', _email!['isStarred'] as bool);
              if (!success && mounted) {
                setState(() {
                  _email!['isStarred'] = previousStarredStatus;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to update starred status')),
                );
              }
            },
          ),
          IconButton(
            icon: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: const Icon(Icons.reply),
            ),
            tooltip: 'reply',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ComposeEmailScreen(
                    token: widget.token,
                    replyTo: _email,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'more',
            onSelected: _showMoreOptions,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'Reply',
                child: Text('Reply'),
              ),
              const PopupMenuItem<String>(
                value: 'Forward',
                child: Text('Forward'),
              ),
              const PopupMenuItem<String>(
                value: 'Metadata',
                child: Text('Metadata'),
              ),
              const PopupMenuItem<String>(
                value: 'Move to Trash',
                child: Text('Move to Trash'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'From: ${_email!['senderPhone'] as String? ?? 'Unknown'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('To: ${_email!['recipientPhone'] as String? ?? 'Unknown'}'),
            if (_email!['cc'] != null && (_email!['cc'] as String).isNotEmpty)
              Text('CC: ${_email!['cc']}'),
            if (_email!['bcc'] != null && (_email!['bcc'] as String).isNotEmpty)
              Text('BCC: ${_email!['bcc']}'),
            Text('Date: ${_email!['timestamp'] as String? ?? 'N/A'}'),
            const SizedBox(height: 16),
            const Text(
              'Labels:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8.0,
              children: currentLabels.map<Widget>((label) {
                return Chip(
                  label: Text(label),
                  onDeleted: () {
                    _assignLabel(widget.emailId, label, false);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Body:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(displayBody),
            if (_email!['attachments'] != null && (_email!['attachments'] as List).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: (_email!['attachments'] as List<dynamic>).map<Widget>((dynamic attachment) {
                  final filePath = attachment['filePath'] as String?;
                  final fileType = attachment['fileType'] as String?;
                  final originalFileName = attachment['originalFileName'] as String?;
                  final localFilePath = _localFilePaths[filePath ?? ''];
                  final displayName = (originalFileName != null && originalFileName.isNotEmpty)
                      ? originalFileName
                      : (filePath?.split('/').last ?? 'Unknown File');

                  if (fileType == null || filePath == null) {
                    return const Text('Invalid attachment');
                  }

                  if (fileType.startsWith('image/')) {
                    return Image.network('$_baseUrl$filePath');
                  } else if (fileType == 'application/pdf') {
                    if (kIsWeb && (localFilePath ?? '').startsWith(_baseUrl)) {
                      return GestureDetector(
                        onTap: () => _launchFile(filePath),
                        child: Text(
                          'View PDF: $displayName',
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      );
                    } else if (localFilePath != null) {
                      return SizedBox(
                        height: 200,
                        child: PDFView(
                          filePath: localFilePath,
                          onError: (error) {
                            if (mounted) {
                              setState(() {
                                _pdfError = 'Error loading PDF: $error';
                              });
                            }
                          },
                        ),
                      );
                    } else {
                      return GestureDetector(
                        onTap: () => _launchFile(filePath),
                        child: Text(
                          'View PDF: $displayName',
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      );
                    }
                  } else {
                    return GestureDetector(
                      onTap: () => _launchFile(filePath),
                      child: Text(
                        'Attachment: $displayName',
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    );
                  }
                }).toList(),
              ),
            if (_pdfError != null)
              Text(
                _pdfError!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ComposeEmailScreen(
                        token: widget.token,
                        replyTo: _email,
                      ),
                    ),
                  ),
                  child: const Text('Reply'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ComposeEmailScreen(
                        token: widget.token,
                        forwardFrom: _email,
                      ),
                    ),
                  ),
                  child: const Text('Forward'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}