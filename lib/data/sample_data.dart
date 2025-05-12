import '../models/email.dart';

class SampleData {
  static List<Email> getEmails() {
    return [
      Email(
        sender: 'Netflix',
        subject: 'Netflix: Đề xuất phim mới cho bạn',
        preview: 'Chúng tôi vừa cập nhật những bộ phim mới trên Netflix. Hãy khám phá ngay!',
        time: '10:30 AM',
        isStarred: true,
      ),
      Email(
        sender: 'LinkedIn',
        subject: 'Có 5 thông báo mới',
        preview: 'Bạn có 5 thông báo mới và 3 tin nhắn chưa đọc trên LinkedIn',
        time: '9:15 AM',
      ),
      Email(
        sender: 'Amazon',
        subject: 'Đơn hàng của bạn đã được vận chuyển',
        preview: 'Đơn hàng #12345 của bạn đã được gửi đi và dự kiến sẽ đến trong 2 ngày',
        time: 'Hôm qua',
        hasAttachment: true,
      ),
      Email(
        sender: 'Google',
        subject: 'Xác minh tài khoản của bạn',
        preview: 'Vui lòng xác minh tài khoản Google của bạn bằng cách nhấp vào liên kết',
        time: 'Hôm qua',
        isRead: true,
      ),
      Email(
        sender: 'Spotify',
        subject: 'Danh sách phát được đề xuất hàng tuần',
        preview: 'Danh sách phát được cá nhân hóa của bạn đã sẵn sàng. Khám phá âm nhạc mới!',
        time: '7 tháng 5',
        isRead: true,
      ),
      Email(
        sender: 'Coursera',
        subject: 'Hoàn thành khóa học của bạn',
        preview: 'Bạn đã hoàn thành 80% khóa học Flutter. Hãy tiếp tục!',
        time: '6 tháng 5',
        isStarred: true,
        isRead: true,
      ),
      Email(
        sender: 'Facebook',
        subject: 'Nguyễn Văn A đã bình luận về bài viết của bạn',
        preview: 'Nguyễn Văn A và 5 người khác đã bình luận về bài viết của bạn',
        time: '5 tháng 5',
        isRead: true,
      ),
      Email(
        sender: 'Twitter',
        subject: 'Bạn có thông báo mới trên Twitter',
        preview: 'Xem những gì đang thịnh hành trên Twitter ngay bây giờ',
        time: '4 tháng 5',
      ),
      Email(
        sender: 'Apple',
        subject: 'Biên nhận cho giao dịch của bạn',
        preview: 'Cảm ơn bạn đã mua hàng từ App Store. Đây là biên nhận của bạn.',
        time: '3 tháng 5',
        hasAttachment: true,
      ),
      Email(
        sender: 'Medium',
        subject: 'Tóm tắt bài viết hàng tuần',
        preview: 'Đây là những bài viết nổi bật trên Medium tuần này dựa trên sở thích của bạn',
        time: '2 tháng 5',
        isRead: true,
      ),
    ];
  }
}