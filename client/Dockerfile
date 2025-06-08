# Sử dụng image Node.js làm base để cài đặt Flutter
FROM cirrusci/flutter:stable AS builder

# Cài đặt các công cụ cần thiết
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa

# Tải và cài đặt Flutter SDK
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Sao chép mã nguồn vào container
WORKDIR /app
COPY . .

# Cài đặt các phụ thuộc và build ứng dụng web
RUN flutter pub get
RUN flutter config --enable-web
RUN flutter build web --release

# Sử dụng Nginx để phục vụ các tệp tĩnh
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]