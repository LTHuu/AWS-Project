# Sử dụng Nginx bản nhẹ nhất (alpine) làm web server
FROM nginx:alpine

# Xóa các file mặc định của Nginx
RUN rm -rf /usr/share/nginx/html/*

# Copy toàn bộ code HTML/CSS của bạn vào thư mục của Nginx
COPY . /usr/share/nginx/html

# Mở cổng 80 để truy cập web
EXPOSE 80

# Chạy Nginx
CMD ["nginx", "-g", "daemon off;"]