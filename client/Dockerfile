# Sử dụng image Flutter chính thức để build
FROM cirrusci/flutter:stable AS builder

# Tạo user không phải root để tránh lỗi quyền
RUN useradd -m flutteruser
USER flutteruser
WORKDIR /home/flutteruser/app

# Sao chép mã nguồn vào container
COPY --chown=flutteruser:flutteruser . .

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