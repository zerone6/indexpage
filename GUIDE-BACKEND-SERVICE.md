# 백엔드 서비스 추가 가이드

현재 마이크로서비스 아키텍처에 백엔드 서비스를 추가하는 방법입니다.

---

## 📋 필요한 설정 요약

### ✅ Infrastructure (indexpage) 저장소에서 설정 필요
1. **docker-compose.yml** - 서비스 정의
2. **nginx/conf.d/default.conf** - 라우팅 규칙

### ✅ 백엔드 서비스 저장소에서 설정 필요
1. **Dockerfile** - 이미지 빌드
2. **GitHub Actions** - GHCR 자동 배포
3. **포트 설정** - 컨테이너 내부 포트
4. **(선택) Health check endpoint** - 서비스 상태 확인

---

## 🎯 예제: Spring Boot 백엔드 서비스 추가

### 1. 백엔드 서비스 저장소 구성

#### 1.1 Dockerfile 생성

```dockerfile
# Spring Boot 애플리케이션 빌드
FROM gradle:8.5-jdk17 AS builder
WORKDIR /app
COPY . .
RUN gradle clean build -x test

# 실행 이미지
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar

# 포트 노출 (8080 권장)
EXPOSE 8080

# Health check 추가 (선택)
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# 애플리케이션 실행
ENTRYPOINT ["java", "-jar", "app.jar"]
```

#### 1.2 GitHub Actions 워크플로우 생성

`.github/workflows/build-and-push.yml`:

```yaml
name: Build and Push to GHCR

on:
  push:
    branches:
      - main
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

#### 1.3 application.yml 설정

```yaml
server:
  port: 8080

spring:
  application:
    name: my-backend-service

# Health check endpoint (Spring Boot Actuator)
management:
  endpoints:
    web:
      exposure:
        include: health
  endpoint:
    health:
      show-details: always
```

---

### 2. Infrastructure (indexpage) 저장소 설정

#### 2.1 docker-compose.yml에 서비스 추가

```yaml
services:
  # ... 기존 서비스들 ...

  # 새 백엔드 서비스
  my-backend:
    image: ghcr.io/YOUR_USERNAME/my-backend-service:latest
    container_name: my-backend
    expose:
      - "8080"
    networks:
      - web
    restart: unless-stopped
    environment:
      - SPRING_PROFILES_ACTIVE=prod
      # 다른 환경 변수들
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 5
```

#### 2.2 nginx/conf.d/default.conf에 라우팅 추가

```nginx
# Upstream 정의
upstream my-backend {
    server my-backend:8080;
}

# HTTPS 서버 블록 내부에 location 추가
server {
    # ... 기존 설정 ...

    # 백엔드 API 라우팅
    location /api/myservice/ {
        proxy_pass http://my-backend/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # API timeout 설정
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # CORS 설정 (필요시)
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;

        if ($request_method = 'OPTIONS') {
            return 204;
        }
    }
}
```

---

## 🔍 중요 포인트

### 1. **포트 일관성**

백엔드 서비스는 일관된 포트를 사용하는 것이 좋습니다:
- **8080**: Spring Boot, Tomcat 기본 포트
- **3000**: Node.js/Express 기본 포트
- **5000**: Python/Flask 기본 포트
- **8000**: Django, FastAPI 기본 포트

### 2. **네트워크 격리**

민감한 백엔드 서비스는 별도 네트워크를 사용할 수 있습니다:

```yaml
services:
  my-backend:
    networks:
      - web        # Nginx와 통신
      - backend    # DB와 통신

  postgres:
    networks:
      - backend    # 백엔드만 접근 가능

networks:
  web:
    driver: bridge
  backend:
    driver: bridge
```

### 3. **환경 변수 관리**

민감한 정보는 환경 변수로 관리:

```yaml
services:
  my-backend:
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=${DB_NAME}
      - DB_PASSWORD=${DB_PASSWORD}
      - JWT_SECRET=${JWT_SECRET}
    env_file:
      - .env
```

서버에 `.env` 파일 생성:
```bash
# 서버에서 실행
cat > ~/indexpage/.env << 'EOF'
DB_NAME=mydb
DB_PASSWORD=securepassword
JWT_SECRET=your-secret-key
EOF
```

### 4. **Health Check**

백엔드 서비스는 반드시 health check endpoint를 제공해야 합니다:

**Spring Boot (Actuator):**
```
GET /actuator/health
```

**Node.js/Express:**
```javascript
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});
```

**Python/Flask:**
```python
@app.route('/health')
def health():
    return {'status': 'healthy'}, 200
```

---

## 📊 URL 구조 권장 사항

```
https://hstarsp.net/                      → Main Page
https://hstarsp.net/highschool/           → Highschool Calendar (Frontend)
https://hstarsp.net/realestate/           → Real Estate Calc (Frontend)
https://hstarsp.net/api/realestate/       → Real Estate Calc (Backend API)
https://hstarsp.net/api/myservice/        → New Backend Service API
```

이렇게 `/api/` prefix를 사용하면:
- Frontend와 Backend를 명확히 구분
- API 라우팅이 간단해짐
- CORS 설정이 쉬워짐

---

## ✅ 배포 순서

### 1. 백엔드 서비스 저장소 작업

```bash
# 1. Dockerfile 생성
# 2. .github/workflows/build-and-push.yml 생성
# 3. Git 커밋 및 푸시
git add .
git commit -m "Add Docker build and GHCR deployment"
git push origin main

# 4. GitHub Actions 성공 확인
# 5. GHCR 이미지를 Public으로 설정
```

### 2. Infrastructure 저장소 업데이트

```bash
cd /Users/seonpillhwang/GitHub/homegroup/indexpage

# 1. docker-compose.yml 수정
# 2. nginx/conf.d/default.conf 수정
# 3. Git 커밋 및 푸시
git add docker-compose.yml nginx/conf.d/default.conf
git commit -m "Add my-backend service"
git push origin main
```

### 3. 서버에서 확인

```bash
# 서버 SSH 접속
ssh YOUR_SERVER

# 자동 배포되었는지 확인
cd ~/indexpage
docker ps | grep my-backend
docker logs my-backend --tail=50

# 또는 수동으로 pull
docker compose pull my-backend
docker compose up -d my-backend
```

---

## 🎯 요약

### ✅ 백엔드 서비스 저장소에서:
1. Dockerfile 작성
2. GitHub Actions 설정
3. Health check endpoint 구현
4. GHCR에 이미지 푸시

### ✅ Infrastructure 저장소에서:
1. `docker-compose.yml`에 서비스 추가
2. `nginx/conf.d/default.conf`에 라우팅 추가

### ❌ 추가 설정 **불필요**:
- ✅ 백엔드 서비스는 내부 네트워크에서만 통신
- ✅ Nginx가 모든 외부 트래픽 처리
- ✅ SSL/TLS는 Nginx에서 처리
- ✅ 로드밸런싱은 Nginx upstream으로 가능

---

## 💡 장점

1. **보안**: 백엔드 서비스는 외부에 직접 노출되지 않음
2. **유연성**: 서비스별 독립 배포 가능
3. **확장성**: 서비스 추가가 간단함
4. **관리 용이**: Infrastructure 저장소에서 중앙 관리

---

이 가이드가 도움이 되셨나요? 특정 백엔드 프레임워크(Spring Boot, Node.js, Python 등)에 대한 상세 예제가 필요하시면 말씀해주세요!
