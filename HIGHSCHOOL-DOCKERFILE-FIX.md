# Highschool Dockerfile 수정 가이드

## 🔴 문제

GitHub Actions에서 Docker 이미지 빌드 시 다음 오류 발생:

```
rm: 'public/data' is a directory
ERROR: failed to build
```

**원인**: `rm -f public/data` 명령어는 파일만 삭제 가능하고, 디렉토리는 삭제할 수 없습니다.

---

## ✅ 해결 방법

### 옵션 1: rm -rf 사용 (권장)

Dockerfile의 해당 부분을 다음과 같이 수정:

**Before:**
```dockerfile
RUN npm run prepare:data && \
    mkdir -p public && \
    rm -f public/data && \
    ln -sf ../Data public/data
```

**After:**
```dockerfile
RUN npm run prepare:data && \
    mkdir -p public && \
    rm -rf public/data && \
    ln -sf ../Data public/data
```

### 옵션 2: 조건부 삭제

더 안전한 방법:

```dockerfile
RUN npm run prepare:data && \
    mkdir -p public && \
    (rm -rf public/data 2>/dev/null || true) && \
    ln -sf ../Data public/data
```

### 옵션 3: 심볼릭 링크 강제 생성

가장 간단한 방법:

```dockerfile
RUN npm run prepare:data && \
    mkdir -p public && \
    ln -sfn ../Data public/data
```

`-n` 옵션: 기존 디렉토리가 있어도 심볼릭 링크로 덮어씁니다.

---

## 🔧 수정 절차

### 1. highschool-calendar 저장소의 Dockerfile 수정

```bash
cd /Users/seonpillhwang/GitHub/highschool-calendar

# Dockerfile 편집
# 16-19줄을 다음과 같이 수정:
```

**수정된 전체 Dockerfile:**

```dockerfile
# Multi-stage build for React application
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Prepare data
RUN npm run prepare:data && \
    mkdir -p public && \
    ln -sfn ../Data public/data

# Build the application
RUN npm run build

# Production stage - use Nginx to serve static files
FROM nginx:alpine

# Copy built files from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html/highschool

# Copy custom nginx config
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
```

### 2. 변경사항 커밋 및 푸시

```bash
git add Dockerfile
git commit -m "Fix: Use ln -sfn to handle existing data directory"
git push origin main
```

### 3. GitHub Actions 확인

- GitHub 저장소 → **Actions** 탭
- 새로운 워크플로우 실행 확인
- 성공하면 GHCR에 이미지 푸시됨

---

## 🔍 추가 확인 사항

### nginx/default.conf 파일 존재 여부 확인

Dockerfile에서 참조하는 nginx 설정 파일이 있는지 확인:

```bash
cd /Users/seonpillhwang/GitHub/highschool-calendar
ls -la nginx/default.conf
```

**파일이 없다면** 생성:

```bash
mkdir -p nginx

cat > nginx/default.conf << 'EOF'
server {
    listen 80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Highschool base path
    location /highschool/ {
        try_files $uri $uri/ /highschool/index.html;
    }

    # For direct access (development)
    location / {
        try_files $uri $uri/ /highschool/index.html;
    }

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
```

---

## 📝 변경사항 요약

1. **Dockerfile 수정**: `rm -f` → `ln -sfn` 사용
2. **nginx 설정 확인**: `nginx/default.conf` 파일 존재 여부
3. **커밋 및 푸시**: GitHub Actions 자동 실행
4. **GHCR 확인**: 이미지가 정상적으로 푸시되었는지 확인

---

## 🚀 다음 단계

빌드가 성공하면:

1. GHCR 이미지를 Public으로 설정
2. Infrastructure(indexpage) 저장소 업데이트
3. 서버 배포 및 테스트
