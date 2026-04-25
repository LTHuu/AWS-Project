# Sử dụng Node.js 22 như bạn đã chọn trên App Runner
FROM node:22-alpine

# Tạo thư mục app
WORKDIR /usr/src/app

# Chỉ copy file package trước để tối ưu hóa cache khi build
COPY package*.json ./
RUN npm install

# Copy toàn bộ code (nhớ dùng .gitignore để loại bỏ node_modules)
COPY . .

# Mở port 3000
EXPOSE 3000

# Lệnh khởi chạy
CMD ["node", "server.js"]