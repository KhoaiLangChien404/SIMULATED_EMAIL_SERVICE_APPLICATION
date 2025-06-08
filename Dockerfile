# Sử dụng image Flutter chính thức hỗ trợ Dart 3.7.2
FROM flutter:latest AS builder

# Tạo user không phải root và sửa quyền thư mục Flutter SDK
RUN useradd -m flutteruser \
    && chown -R flutteruser:flutteruser /sdks/flutter \
    && chmod -R u+rw /sdks/flutter

# Chuyển sang user flutteruser
USER flutteruser
WORKDIR /home/flutteruser/app

# Thêm thư mục Flutter vào danh sách an toàn của Git
RUN git config --global --add safe.directory /sdks/flutter

# Kiểm tra nội dung thư mục hiện tại (debug)
RUN ls -la

# Sao chép mã nguồn từ thư mục client vào container
COPY --chown=flutteruser:flutteruser client/ .

# Cài đặt dependencies và build ứng dụng web
RUN flutter pub get
RUN flutter config --enable-web
RUN flutter build web --release

# Sử dụng Nginx để phục vụ các file tĩnh
FROM nginx:alpine

# Sao chép các file web đã build vào Nginx
COPY --from=builder /home/flutteruser/app/build/web /usr/share/nginx/html

# Sao chép cấu hình Nginx
COPY --from=builder /home/flutteruser/app/nginx.conf /etc/nginx/conf.d/default.conf

# Mở port 80
EXPOSE 80

# Khởi động Nginx
CMD ["nginx", "-g", "daemon off;"]