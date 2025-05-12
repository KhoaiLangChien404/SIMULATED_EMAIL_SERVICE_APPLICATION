class Email {
  final String sender;
  final String subject;
  final String preview;
  final String time;
  final bool isRead;
  final bool isStarred;
  final bool hasAttachment;

  Email({
    required this.sender,
    required this.subject,
    required this.preview,
    required this.time,
    this.isRead = false,
    this.isStarred = false,
    this.hasAttachment = false,
  });
}