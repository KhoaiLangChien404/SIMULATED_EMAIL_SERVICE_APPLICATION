# Sử dụng image Flutter từ Cirrus CI
FROM cirrusci/flutter:stable AS builder

# Tắt analytics
RUN dart --disable-analytics

# Cài đặt Dart SDK 3.7.2 thủ công và thay thế SDK cũ
RUN wget -qO dart-sdk.zip https://storage.googleapis.com/dart-archive/channels/stable/release/3.7.2/sdk/dartsdk-linux-x64-release.zip && \
    unzip -q dart-sdk.zip -d /usr/local/ && \
    rm dart-sdk.zip && \
    mv /usr/local/dart-sdk /usr/local/dart-sdk-3.7.2 && \
    rm -rf /sdks/flutter/bin/cache/dart-sdk && \
    ln -sf /usr/local/dart-sdk-3.7.2 /sdks/flutter/bin/cache/dart-sdk && \
    ln -sf /usr/local/dart-sdk-3.7.2/bin/dart /usr/local/bin/dart && \
    ln -sf /usr/local/dart-sdk-3.7.2/bin/pub /usr/local/bin/pub

# Tối ưu hóa flutter precache (chỉ tải web)
RUN flutter config --no-analytics && \
    flutter precache --web && \
    flutter --version

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
RUN flutter build web --release --no-tree-shake-icons

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