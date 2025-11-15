# Highschool Calendar 프로젝트 분리 가이드

이 가이드는 Highschool 프로젝트를 별도 저장소로 분리하고, GHCR(GitHub Container Registry)에 Docker 이미지를 자동으로 배포하는 방법을 설명합니다.

---

## 📋 목표

- Highschool 프로젝트를 `highschool-calendar` 저장소로 분리
- GitHub Actions로 GHCR에 이미지 자동 빌드/푸시
- Infrastructure(indexpage) 저장소에서 해당 이미지 사용

---

## 🚀 1단계: 새 저장소 생성 및 파일 복사

### 1.1 GitHub에서 새 저장소 생성

1. GitHub에서 **New repository** 클릭
2. Repository name: `highschool-calendar`
3. Visibility: Public (GHCR 무료 사용을 위해)
4. **Create repository** 클릭

### 1.2 로컬에 저장소 클론

```bash
cd /Users/seonpillhwang/GitHub
git clone https://github.com/YOUR_USERNAME/highschool-calendar.git
cd highschool-calendar
```

### 1.3 Highschool 프로젝트 파일 복사

```bash
# Highschool 프로젝트의 highschool 디렉토리 내용을 모두 복사
cp -r /Users/seonpillhwang/GitHub/Highschool/highschool/* .

# Data 디렉토리도 필요하다면 복사
cp -r /Users/seonpillhwang/GitHub/Highschool/Data .

# 확인
ls -la
```

---

## 🐳 2단계: Dockerfile 수정 (필요시)

기존 Dockerfile이 이미 있다면 그대로 사용하거나, 필요에 따라 수정합니다.

**현재 Dockerfile 구조 확인:**
```bash
cat Dockerfile
```

**예상되는 구조:**
```dockerfile
# Multi-stage build
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run prepare:data && mkdir -p public && ln -sf ../Data public/data
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html/highschool
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

## 🔧 3단계: GitHub Actions 워크플로우 생성

### 3.1 디렉토리 생성

```bash
mkdir -p .github/workflows
```

### 3.2 워크플로우 파일 생성

`.github/workflows/build-and-push.yml` 파일을 생성합니다:

```yaml
name: Build and Push to GHCR

on:
  push:
    branches:
      - main
      - master
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

      - name: Extract metadata (tags, labels)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Image digest
        run: echo ${{ steps.meta.outputs.digest }}
```

---

## 📝 4단계: .gitignore 생성

```bash
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Build output
dist/
build/
.next/
out/

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Temporary files
tmp/
temp/
EOF
```

---

## 📄 5단계: README.md 생성

```bash
cat > README.md << 'EOF'
# Highschool Calendar

입시일정 선택 서비스

## 🚀 Quick Start

### Development

```bash
# Install dependencies
npm install

# Prepare data
npm run prepare:data

# Start development server
npm run dev
```

### Docker

```bash
# Build image
docker build -t highschool-calendar .

# Run container
docker run -p 80:80 highschool-calendar
```

## 📦 Deployment

This project automatically builds and pushes Docker images to GitHub Container Registry (GHCR) when code is pushed to the main branch.

### Pull the latest image

```bash
docker pull ghcr.io/YOUR_USERNAME/highschool-calendar:latest
```

### Run the container

```bash
docker run -d -p 80:80 --name highschool ghcr.io/YOUR_USERNAME/highschool-calendar:latest
```

## 🔗 Related Repositories

- [indexpage](https://github.com/YOUR_USERNAME/indexpage) - Infrastructure orchestration
- [realestate-calc](https://github.com/YOUR_USERNAME/realestate-calc) - Real estate calculator service

## 📝 License

Private - Family use only
EOF
```

---

## 🎯 6단계: Git 초기화 및 푸시

```bash
# Git 초기화 (이미 클론했다면 생략)
git init
git branch -M main

# 파일 추가
git add .

# 커밋
git commit -m "Initial commit: Highschool Calendar service"

# 원격 저장소 연결 (이미 클론했다면 생략)
git remote add origin https://github.com/YOUR_USERNAME/highschool-calendar.git

# 푸시
git push -u origin main
```

---

## ✅ 7단계: GitHub Actions 확인

1. GitHub 저장소로 이동
2. **Actions** 탭 클릭
3. 워크플로우가 자동으로 실행되는지 확인
4. 성공하면 **Packages** 탭에 이미지가 나타남

---

## 🔓 8단계: GHCR 이미지를 Public으로 설정

1. GitHub 프로필 → **Packages** 클릭
2. `highschool-calendar` 패키지 선택
3. **Package settings** 클릭
4. **Change visibility** → **Public** 선택
5. 확인

---

## 🔄 9단계: Infrastructure 저장소 업데이트

Infrastructure(indexpage) 저장소의 nginx 설정을 활성화합니다.

### 9.1 nginx 설정 수정

`/Users/seonpillhwang/GitHub/homegroup/indexpage/nginx/conf.d/default.conf` 파일에서 주석 제거:

```nginx
# Upstream 정의
upstream highschool {
    server highschool:80;
}

# Location 설정
location /highschool/ {
    proxy_pass http://highschool/highschool/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_cache_bypass $http_upgrade;
    proxy_redirect off;
}
```

### 9.2 docker-compose.yml 수정

Highschool 서비스의 `profiles` 제거:

```yaml
highschool:
  image: ghcr.io/YOUR_USERNAME/highschool-calendar:latest
  container_name: highschool
  expose:
    - "80"
  networks:
    - web
  restart: unless-stopped
  # profiles 제거!
  healthcheck:
    test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]
    interval: 30s
    timeout: 10s
    retries: 3
```

### 9.3 커밋 및 푸시

```bash
cd /Users/seonpillhwang/GitHub/homegroup/indexpage

git add nginx/conf.d/default.conf docker-compose.yml
git commit -m "Enable Highschool Calendar service"
git push origin main
```

---

## 🎉 완료!

이제 다음과 같이 작동합니다:

1. **Highschool Calendar 저장소**에 코드 푸시
2. GitHub Actions가 자동으로 Docker 이미지 빌드
3. GHCR에 이미지 푸시
4. **Infrastructure 저장소**에서 최신 이미지를 pull하여 배포
5. https://hstarsp.net/highschool/ 에서 서비스 접근 가능

---

## 🔍 트러블슈팅

### 이미지를 pull할 수 없는 경우

```bash
# 이미지가 Public인지 확인
# GitHub 프로필 → Packages → highschool-calendar → Settings → Change visibility

# 서버에서 직접 pull 테스트
docker pull ghcr.io/YOUR_USERNAME/highschool-calendar:latest
```

### GitHub Actions 실패

- **Actions** 탭에서 로그 확인
- Dockerfile 경로가 올바른지 확인
- package.json의 scripts가 정상인지 확인

### Nginx 프록시 오류

```bash
# 서버에서 확인
cd ~/indexpage
docker logs nginx-proxy
docker logs highschool
```

---

## 📚 다음 단계

동일한 방법으로 Real Estate Calculator 프로젝트도 분리할 수 있습니다.
