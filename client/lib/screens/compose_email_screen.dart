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
  final int defaultFontSize; // Thêm tham số font size
  final String defaultFontFamily; // Thêm tham số font family

  const ComposeEmailScreen({
    required this.token,
    this.replyTo,
    this.forwardFrom,
    this.draft,
    this.defaultFontSize = 12, // Giá trị mặc định
    this.defaultFontFamily = 'Arial', // Giá trị mặc định
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
  final String _baseUrl = const String.fromEnvironment('BASE_URL', defaultValue: 'https://simulated-email-service-application-1.onrender.com');
  Timer? _autosaveTimer;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _showCcBcc = false;

  @override
  void initState() {
    super.initState();
    // Áp dụng font size và font family mặc định khi khởi tạo
    _applyDefaultFontStyle();

    if (widget.replyTo != null) {
      _toController.text = widget.replyTo!['senderPhone'] ?? '';
      _subjectController.text = 'Re: ${widget.replyTo!['subject']?.replaceAll('Re: ', '') ?? ''}';
      _bodyController.document.insert(0, ''); // Initialize with empty Delta
    } else if (widget.forwardFrom != null) {
      _toController.text = '';
      _subjectController.text = 'Fwd: ${widget.forwardFrom!['subject']?.replaceAll('Fwd: ', '') ?? ''}';
      final forwardContent = '\n\n-- Forwarded Message --\nFrom: ${widget.forwardFrom!['senderPhone'] ?? ''}\nDate: ${widget.forwardFrom!['timestamp'] ?? ''}\nSubject: ${widget.forwardFrom!['subject'] ?? ''}\n\n${widget.forwardFrom!['body'] ?? ''}';
      _bodyController.document.insert(0, forwardContent); // Insert forwarded content as plain text
    } else if (widget.draft != null) {
      _toController.text = widget.draft!['recipientPhone'] ?? '';
      _ccController.text = widget.draft!['cc'] ?? '';
      _bccController.text = widget.draft!['bcc'] ?? '';
      _subjectController.text = widget.draft!['subject'] ?? '';
      String body = widget.draft!['body'] ?? '';
      try {
        // Try parsing as JSON (for Quill Delta)
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic> || decoded is List<dynamic>) {
          _bodyController.document = quill.Document.fromJson(decoded);
        } else {
          // If not valid JSON, treat as plain text
          _bodyController.document = quill.Document()..insert(0, body);
        }
      } catch (e) {
        // If JSON parsing fails, treat as plain text
        _bodyController.document = quill.Document()..insert(0, body);
      }
      if (widget.draft!['attachment'] != null) {
        _attachments.add(PlatformFile(
          name: widget.draft!['attachment'].split('/').last,
          size: 0,
          path: null,
          bytes: null,
        ));
      }
      _draftId = widget.draft!['id']; // Save draftId for updates
    }
    _autosaveTimer = Timer.periodic(const Duration(seconds: 30), (_) => _autosaveDraft());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  // Hàm áp dụng font style mặc định
  void _applyDefaultFontStyle() {
    final delta = _bodyController.document.toDelta();
    if (delta.isEmpty) {
      // Khi tài liệu trống, chèn một đoạn văn bản rỗng và áp dụng định dạng
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
      // Áp dụng định dạng cho toàn bộ tài liệu
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
        setState(() => _attachments.addAll(result.files));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error picking file: $e');
    }
  }

  Future<void> _sendEmail() async {
    if (_toController.text.isEmpty || _subjectController.text.isEmpty || _bodyController.document.toPlainText().isEmpty) {
      if (mounted) setState(() => _error = 'To, subject, and body are required');
      return;
    }
    final recipientExists = await _checkRecipient(_toController.text);
    if (!recipientExists) {
      if (mounted) setState(() => _error = 'Recipient phone number not found');
      return;
    }
    if (mounted) setState(() => {_isLoading = true, _error = ''});
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
        Navigator.pop(context);
      } else {
        final errorMsg = jsonDecode(response.body)['error'] ?? response.body;
        if (mounted) setState(() => {_error = 'Send failed: $errorMsg', _isLoading = false});
        print('Send email failed with status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => {_error = 'Error: Failed to send. ${e.toString()}', _isLoading = false});
      print('Send email exception: $e');
    }
  }

  Future<void> _deleteDraft(int draftId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/delete-draft/$draftId'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        print('Draft $draftId deleted after sending email');
      } else {
        print('Failed to delete draft $draftId: ${response.body}');
      }
    } catch (e) {
      print('Delete draft exception: $e');
    }
  }

  Future<bool> _checkRecipient(String phone) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/profile?phone=$phone'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Recipient check error: $e');
      return false;
    }
  }

  Future<void> _autosaveDraft() async {
    if (_toController.text.isEmpty && _subjectController.text.isEmpty && _bodyController.document.toPlainText().isEmpty && _attachments.isEmpty) {
      return; // Don't autosave if all fields are empty
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
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _draftId = data['draftId']);
        print('Draft autosaved with ID: $_draftId');
      } else {
        print('Autosave failed with status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      print('Autosave draft exception: $e');
    }
  }

  Future<void> _saveDraft() async {
    if (_toController.text.isEmpty && _subjectController.text.isEmpty && _bodyController.document.toPlainText().isEmpty && _attachments.isEmpty) {
      Navigator.pop(context); // Don't save draft if all fields are empty
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
        Navigator.pop(context);
      } else {
        if (mounted) setState(() => _error = 'Failed to save draft: ${response.body}');
        print('Save draft failed with status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: Failed to save draft. ${e.toString()}');
      print('Save draft exception: $e');
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
    // Kiểm tra giá trị mặc định để tránh lỗi runtime
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
          IconButton(icon: const Icon(Icons.send), tooltip: 'Send Email', onPressed: _sendEmail),
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