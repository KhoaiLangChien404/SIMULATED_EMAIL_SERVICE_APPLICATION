import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

class ComposeEmailScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? replyTo;
  final Map<String, dynamic>? forwardFrom;
  final Map<String, dynamic>? draft;
  final int defaultFontSize;
  final String defaultFontFamily;

  const ComposeEmailScreen({
    required this.token,
    this.replyTo,
    this.forwardFrom,
    this.draft,
    this.defaultFontSize = 12,
    this.defaultFontFamily = 'Arial',
    super.key,
  });

  @override
  _ComposeEmailScreenState createState() => _ComposeEmailScreenState();
}

class _ComposeEmailScreenState extends State<ComposeEmailScreen> {
  final _toController = TextEditingController();
  final _ccController = TextEditingController();
  final _bccController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = quill.QuillController.basic();
  List<PlatformFile> _attachments = [];
  String _error = '';
  bool _isLoading = false;
  int? _draftId;
  final String _baseUrl = const String.fromEnvironment('BASE_URL', defaultValue: 'https://simulated-email-service-application-1-9jhr.onrender.com');
  Timer? _autosaveTimer;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _showCcBcc = false;

  @override
  void initState() {
    super.initState();
    _applyDefaultFontStyle();

    if (widget.replyTo != null) {
      _toController.text = widget.replyTo!['senderPhone'] ?? '';
      _subjectController.text = 'Re: ${widget.replyTo!['subject']?.replaceAll('Re: ', '') ?? ''}';
      _bodyController.document.insert(0, '');
    } else if (widget.forwardFrom != null) {
      _toController.text = '';
      _subjectController.text = 'Fwd: ${widget.forwardFrom!['subject']?.replaceAll('Fwd: ', '') ?? ''}';
      final forwardContent = '\n\n-- Forwarded Message --\nFrom: ${widget.forwardFrom!['senderPhone'] ?? ''}\nDate: ${widget.forwardFrom!['timestamp'] ?? ''}\nSubject: ${widget.forwardFrom!['subject'] ?? ''}\n\n${widget.forwardFrom!['body'] ?? ''}';
      _bodyController.document.insert(0, forwardContent);
    } else if (widget.draft != null) {
      _toController.text = widget.draft!['recipientPhone'] ?? '';
      _ccController.text = widget.draft!['cc'] ?? '';
      _bccController.text = widget.draft!['bcc'] ?? '';
      _subjectController.text = widget.draft!['subject'] ?? '';
      String body = widget.draft!['body'] ?? '';
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic> || decoded is List<dynamic>) {
          _bodyController.document = quill.Document.fromJson(decoded);
        } else {
          _bodyController.document = quill.Document()..insert(0, body);
        }
      } catch (e) {
        _bodyController.document = quill.Document()..insert(0, body);
        print('Body parsing error: $e');
      }
      if (widget.draft!['attachment'] != null) {
        _attachments.add(PlatformFile(
          name: widget.draft!['attachment'].split('/').last,
          size: 0,
          path: null,
          bytes: null,
        ));
      }
      _draftId = widget.draft!['id'];
    }
    _autosaveTimer = Timer.periodic(const Duration(seconds: 30), (_) => _autosaveDraft());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _applyDefaultFontStyle() {
    final delta = _bodyController.document.toDelta();
    if (delta.isEmpty) {
      _bodyController.document.insert(0, '');
      _bodyController.formatText(
        0,
        1,
        quill.Attribute(
          quill.Attribute.size.key,
          quill.AttributeScope.inline,
          '${widget.defaultFontSize}pt',
        ),
      );
      _bodyController.formatText(
        0,
        1,
        quill.Attribute(
          quill.Attribute.font.key,
          quill.AttributeScope.inline,
          widget.defaultFontFamily,
        ),
      );
    } else {
      _bodyController.formatText(
        0,
        _bodyController.document.length,
        quill.Attribute(
          quill.Attribute.size.key,
          quill.AttributeScope.inline,
          '${widget.defaultFontSize}pt',
        ),
      );
      _bodyController.formatText(
        0,
        _bodyController.document.length,
        quill.Attribute(
          quill.Attribute.font.key,
          quill.AttributeScope.inline,
          widget.defaultFontFamily,
        ),
      );
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.any);
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() {
          _attachments.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error picking file: $e';
        });
        print('Attachment picking error: $e');
      }
    }
  }

  Future<void> _sendEmail() async {
    if (_toController.text.isEmpty || _subjectController.text.isEmpty || _bodyController.document.toPlainText().isEmpty) {
      if (mounted) setState(() => _error = 'To, subject, and body are required');
      print('Required fields missing');
      return;
    }
    final recipientExists = await _checkRecipient(_toController.text);
    if (!recipientExists) {
      if (mounted) setState(() => _error = 'Recipient phone number not found');
      print('Recipient not found: ${_toController.text}');
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      print('Sending email...');
    }
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/send-email'));
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.fields['recipientPhone'] = _toController.text;
      request.fields['cc'] = _ccController.text;
      request.fields['bcc'] = _bccController.text;
      request.fields['subject'] = _subjectController.text;
      request.fields['body'] = jsonEncode(_bodyController.document.toDelta().toJson());
      for (var attachment in _attachments) {
        if (kIsWeb && attachment.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes('attachments', attachment.bytes!, filename: attachment.name));
        } else if (attachment.path != null) {
          request.files.add(await http.MultipartFile.fromPath('attachments', attachment.path!));
        }
      }
      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200 && mounted) {
        setState(() => _isLoading = false);
        if (_draftId != null) {
          await _deleteDraft(_draftId!);
        }
        print('Email sent successfully');
        Navigator.pop(context);
      } else {
        final errorMsg = jsonDecode(response.body)['error'] ?? response.body;
        if (mounted) setState(() => _error = 'Failed to send email: $errorMsg');
        print('Send email failed: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error sending email: $e');
      print('Error sending email: $e');
    }
  }

  Future<void> _deleteDraft(int draftId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/delete-draft/$draftId'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        print('Draft $draftId deleted successfully');
      } else {
        print('Failed to delete draft $draftId: ${jsonDecode(response.body)['error'] ?? response.body}');
      }
    } catch (e) {
      print('Error deleting draft: $e');
    }
  }

  Future<bool> _checkRecipient(String phone) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/profile?phone=$phone'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('Error checking recipient: $e');
      return false;
    }
  }

  Future<void> _autosaveDraft() async {
    if (_toController.text.isEmpty && _subjectController.text.isEmpty && _bodyController.document.toPlainText().isEmpty && _attachments.isEmpty) {
      return;
      print('Nothing to autosave');
    }
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/save-draft'));
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.fields['recipientPhone'] = _toController.text;
      request.fields['cc'] = _ccController.text;
      request.fields['bcc'] = _bccController.text;
      request.fields['subject'] = _subjectController.text;
      request.fields['body'] = jsonEncode(_bodyController.document.toDelta().toJson());
      if (_attachments.isNotEmpty) {
        final attachment = _attachments.first;
        if (kIsWeb && attachment.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes('attachment', attachment.bytes!, filename: attachment.name));
        } else if (attachment.path != null) {
          request.files.add(await http.MultipartFile.fromPath('attachment', attachment.path!));
        }
      }
      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() => _draftId = data['draftId']);
        print('Draft autosaved with ID: $_draftId');
      } else {
        print('Autosave failed: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      print('Error autosaving draft: $e');
    }
  }

  Future<void> _saveDraft() async {
    if (_toController.text.isEmpty && _subjectController.text.isEmpty && _bodyController.document.toPlainText().isEmpty && _attachments.isEmpty) {
      Navigator.pop(context);
      print('Empty draft, navigating back');
      return;
    }
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/save-draft'));
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.fields['recipientPhone'] = _toController.text;
      request.fields['cc'] = _ccController.text;
      request.fields['bcc'] = _bccController.text;
      request.fields['subject'] = _subjectController.text;
      request.fields['body'] = jsonEncode(_bodyController.document.toDelta().toJson());
      if (_attachments.isNotEmpty) {
        final attachment = _attachments.first;
        if (kIsWeb && attachment.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes('attachment', attachment.bytes!, filename: attachment.name));
        } else if (attachment.path != null) {
          request.files.add(await http.MultipartFile.fromPath('attachment', attachment.path!));
        }
      }
      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200 && mounted) {
        print('Draft saved successfully');
        Navigator.pop(context);
      } else {
        if (mounted) setState(() => _error = 'Failed to save draft: ${jsonDecode(response.body)['error'] ?? response.body}');
        print('Save draft failed: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error saving draft: $e');
      print('Error saving draft: $e');
    }
  }

  @override
  void dispose() {
    _toController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _autosaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveFontSize = widget.defaultFontSize > 0 ? widget.defaultFontSize.toDouble() : 12.0;
    final effectiveFontFamily = widget.defaultFontFamily.isNotEmpty ? widget.defaultFontFamily : 'Arial';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.replyTo != null
              ? 'Reply'
              : widget.forwardFrom != null
                  ? 'Forward'
                  : 'Compose',
        ),
        actions: [
          IconButton(icon: const Icon(Icons.save), tooltip: 'Save Draft', onPressed: _saveDraft),
          IconButton(icon: const Icon(Icons.send), tooltip: 'Send', onPressed: _sendEmail),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(controller: _toController, decoration: const InputDecoration(labelText: 'To')),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => mounted ? setState(() => _showCcBcc = !_showCcBcc) : null,
                          child: Text(_showCcBcc ? 'Hide CC/BCC' : 'Show CC/BCC'),
                        ),
                      ],
                    ),
                    if (_showCcBcc) ...[
                      TextField(controller: _ccController, decoration: const InputDecoration(labelText: 'CC')),
                      TextField(controller: _bccController, decoration: const InputDecoration(labelText: 'BCC')),
                    ],
                    TextField(controller: _subjectController, decoration: const InputDecoration(labelText: 'Subject')),
                    SizedBox(
                      height: 200,
                      child: quill.QuillEditor(
                        focusNode: _focusNode,
                        scrollController: _scrollController,
                        configurations: quill.QuillEditorConfigurations(
                          controller: _bodyController,
                          autoFocus: true,
                          expands: true,
                          padding: const EdgeInsets.all(10),
                          placeholder: 'Compose your email...',
                          scrollable: true,
                          customStyles: quill.DefaultStyles(
                            paragraph: quill.DefaultTextBlockStyle(
                              TextStyle(
                                fontSize: effectiveFontSize,
                                fontFamily: effectiveFontFamily,
                              ),
                              const quill.VerticalSpacing(0, 0),
                              const quill.VerticalSpacing(0, 0),
                              null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton(onPressed: _pickAttachment, child: const Text('Add Attachment')),
                        if (_attachments.isNotEmpty)
                          Expanded(
                            child: Text(
                              'Attachments: ${_attachments.map((a) => a.name).join(', ')}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),
    );
  }
}