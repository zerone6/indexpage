# 배포 프로세스 완전 가이드

이 문서는 마이크로서비스 아키텍처의 배포 프로세스를 상세히 설명합니다. 특히 서비스 저장소(예: highschool-calendar)에서 이미지를 생성하고 Infrastructure 저장소(indexpage)에서 배포하는 전체 흐름을 이해하기 쉽게 설명합니다.

## 📋 목차

1. [배포 아키텍처 이해하기](#배포-아키텍처-이해하기)
2. [배포 프로세스 상세 설명](#배포-프로세스-상세-설명)
3. [배포 시나리오별 가이드](#배포-시나리오별-가이드)
4. [주의사항 및 체크리스트](#주의사항-및-체크리스트)
5. [트러블슈팅](#트러블슈팅)

---

## 배포 아키텍처 이해하기

### 전체 구조 개요

우리의 마이크로서비스 아키텍처는 **2-Tier 저장소 구조**로 되어있습니다:

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub 저장소                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ Service Repos    │  │ Infrastructure   │                │
│  │                  │  │ Repo             │                │
│  │ - highschool-    │  │                  │                │
│  │   calendar       │  │ - indexpage      │                │
│  │ - realestate-    │  │                  │                │
│  │   calc           │  │   ├── docker-    │                │
│  │                  │  │   │   compose.yml│                │
│  │ Each has:        │  │   ├── nginx/     │                │
│  │ - Source code    │  │   ├── main-page/ │                │
│  │ - Dockerfile     │  │   └── .github/   │                │
│  │ - GitHub Actions │  │       workflows/ │                │
│  └────────┬─────────┘  └─────────┬────────┘                │
│           │                      │                          │
│           │ Builds Docker Image  │ Orchestrates Services    │
│           ↓                      ↓                          │
│  ┌────────────────────────────────────────────┐            │
│  │ GitHub Container Registry (GHCR)           │            │
│  │                                            │            │
│  │ - ghcr.io/zerone6/highschool-calendar     │            │
│  │ - ghcr.io/zerone6/realestate-calc-fe      │            │
│  │ - ghcr.io/zerone6/realestate-calc-be      │            │
│  └────────────────┬───────────────────────────┘            │
│                   │                                         │
└───────────────────┼─────────────────────────────────────────┘
                    │ Docker Pull
                    ↓
         ┌──────────────────────┐
         │  Oracle Cloud Server │
         │                      │
         │  - Nginx Proxy       │
         │  - Main Page         │
         │  - Highschool        │
         │  - Real Estate       │
         └──────────────────────┘
```

### 저장소 역할 분리

#### 1. 서비스 저장소 (Service Repositories)

**역할:** 개별 서비스의 소스코드 관리 및 Docker 이미지 빌드

**예시:** `highschool-calendar`, `realestate-calc`

**포함 내용:**
- 서비스 소스 코드 (React, Vue, Spring Boot 등)
- `Dockerfile` - 이미지 빌드 방법 정의
- `.github/workflows/docker-publish.yml` - GHCR에 이미지 자동 푸시

**워크플로우:**
```yaml
# highschool-calendar/.github/workflows/docker-publish.yml
name: Build and Push Docker Image

on:
  push:
    branches: [ main ]

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Log in to GHCR
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:latest
```

**핵심 포인트:**
- 서비스 코드를 수정하고 `git push`하면 자동으로 Docker 이미지가 GHCR에 푸시됨
- 이미지는 `ghcr.io/사용자명/저장소명:latest` 형식으로 저장됨
- 서버 배포와는 **독립적** - 이미지만 업데이트됨

#### 2. Infrastructure 저장소 (indexpage)

**역할:** 서비스 오케스트레이션 및 서버 배포 관리

**포함 내용:**
- `docker-compose.yml` - 모든 서비스 정의
- `nginx/` - 리버스 프록시 설정
- `main-page/` - 랜딩 페이지
- `.github/workflows/deploy.yml` - 서버 자동 배포

**워크플로우:**
```yaml
# indexpage/.github/workflows/deploy.yml
name: Deploy Infrastructure

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      # 1. 파일을 서버로 복사
      - name: Copy Infrastructure Files
        uses: appleboy/scp-action@master
        with:
          source: "docker-compose.yml,nginx/,main-page/"
          target: "~/indexpage/"

      # 2. 서버에서 배포 실행
      - name: Deploy Services
        uses: appleboy/ssh-action@master
        with:
          script: |
            cd ~/indexpage
            docker compose pull  # GHCR에서 최신 이미지 다운
            docker compose up -d # 서비스 시작
```

**핵심 포인트:**
- Infrastructure 저장소를 수정하고 `git push`하면 서버에 자동 배포됨
- `docker compose pull`이 GHCR에서 서비스 이미지를 가져옴
- Nginx 설정 변경, 새 서비스 추가 등은 여기서 관리

---

## 배포 프로세스 상세 설명

### 시나리오 1: 서비스 코드 업데이트 (예: Highschool Calendar 수정)

이는 가장 자주 발생하는 시나리오입니다. 서비스의 기능을 수정하거나 버그를 고치는 경우입니다.

#### Step 1: 서비스 저장소에서 코드 수정

```bash
# 로컬 개발 환경
cd ~/GitHub/highschool-calendar

# 코드 수정
vim src/App.js

# Git 커밋 및 푸시
git add .
git commit -m "Fix calendar date selection bug"
git push origin main
```

#### Step 2: GitHub Actions가 자동으로 이미지 빌드

```
GitHub Actions 실행:
1. Checkout code
2. Log in to GHCR
3. Build Docker image
4. Push to ghcr.io/zerone6/highschool-calendar:latest
```

**진행 상황 확인:**
- GitHub 저장소 → Actions 탭에서 워크플로우 진행 상황 확인
- 성공하면 초록색 체크마크 표시

#### Step 3: 서버에 새 이미지 배포

**옵션 A: 자동 배포 (권장)**

Infrastructure 저장소를 푸시하면 자동 배포:

```bash
cd ~/GitHub/indexpage

# 아무 파일이나 수정 (예: README.md 업데이트)
echo "Updated: $(date)" >> README.md
git add .
git commit -m "Trigger deployment for highschool-calendar update"
git push origin main
```

**옵션 B: 수동 배포 (빠른 테스트용)**

서버에 SSH 접속해서 수동으로 실행:

```bash
ssh ubuntu@your-server

cd ~/indexpage
docker compose pull highschool  # 새 이미지 다운로드
docker compose up -d highschool # 컨테이너 재시작

# 확인
docker ps | grep highschool
docker logs highschool --tail=50
```

#### 배포 플로우 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Developer: Code Change in highschool-calendar           │
│    git push origin main                                     │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. GitHub Actions (highschool-calendar repo)                │
│    - Build Dockerfile                                       │
│    - Create Docker Image                                    │
│    - Push to GHCR                                           │
│      ghcr.io/zerone6/highschool-calendar:latest            │
└────────────────────────┬────────────────────────────────────┘
                         ↓
                    [GHCR Storage]
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Trigger Deployment (2가지 방법)                          │
│    A) indexpage 저장소 push → Auto deploy                   │
│    B) 서버 SSH → docker compose pull                        │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Server: Pull & Restart                                   │
│    docker compose pull highschool                           │
│    docker compose up -d highschool                          │
└────────────────────────┬────────────────────────────────────┘
                         ↓
                 [Service Updated]
```

---

### 시나리오 2: Infrastructure 설정 변경 (Nginx, docker-compose.yml)

Nginx 설정을 변경하거나 새로운 서비스를 추가하는 경우입니다.

#### Step 1: 로컬에서 설정 파일 수정

```bash
cd ~/GitHub/indexpage

# 예: Nginx 설정 변경
vim nginx/conf.d/default.conf

# 또는 새 서비스 추가
vim docker-compose.yml
```

#### Step 2: Git 푸시로 자동 배포

```bash
git add .
git commit -m "Add timeout settings to nginx config"
git push origin main
```

#### Step 3: GitHub Actions가 자동으로 서버 배포

```
Deploy Workflow 실행:
1. SSL 인증서 백업 (서버의 /tmp/ssl_backup)
2. 파일 복사 (SCP)
   - docker-compose.yml
   - nginx/
   - main-page/
   - *.md, *.sh
3. SSL 인증서 복원
4. Docker 이미지 Pull
5. 서비스 재시작
```

#### 주의사항

**⚠️ SSL 인증서 보존:**
- 배포 시 `nginx/ssl/` 폴더가 삭제될 수 있음
- GitHub Actions에서 자동으로 백업/복원함
- 첫 배포 전에 반드시 서버에 SSL 인증서가 있어야 함

**⚠️ Nginx 설정 검증:**
배포 전 로컬에서 Nginx 설정 문법 검사:

```bash
# 로컬에서 테스트
docker run --rm -v $(pwd)/nginx:/etc/nginx nginx:alpine nginx -t
```

---

### 시나리오 3: 새 서비스 추가

완전히 새로운 마이크로서비스를 추가하는 전체 프로세스입니다.

#### Step 1: 새 서비스 저장소 생성 및 설정

```bash
# 1. GitHub에서 새 저장소 생성 (예: my-new-service)

# 2. 로컬에서 프로젝트 생성
mkdir my-new-service
cd my-new-service

# 3. Dockerfile 작성
cat > Dockerfile <<EOF
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
EOF

# 4. GitHub Actions 워크플로우 추가
mkdir -p .github/workflows
cat > .github/workflows/docker-publish.yml <<EOF
name: Docker Build and Push

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v3

      - name: Log in to GHCR
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: \${{ github.actor }}
          password: \${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: ghcr.io/\${{ github.repository }}:latest
EOF

# 5. Git 초기화 및 푸시
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/my-new-service.git
git push -u origin main
```

#### Step 2: GHCR 이미지 Public 설정

```
1. GitHub → Packages → my-new-service 클릭
2. Package settings → Change visibility → Public
3. "I understand the consequences" 체크 → Make public
```

**⚠️ 중요:** GHCR 이미지가 Private이면 서버에서 pull 실패합니다!

#### Step 3: Infrastructure 저장소에서 서비스 등록

```bash
cd ~/GitHub/indexpage

# 1. docker-compose.yml 수정
vim docker-compose.yml
```

**docker-compose.yml에 추가:**
```yaml
services:
  # ... 기존 서비스들 ...

  my-new-service:
    image: ghcr.io/YOUR_USERNAME/my-new-service:latest
    container_name: my-new-service
    expose:
      - "3000"  # 포트는 서비스에 맞게 변경
    networks:
      - web
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

```bash
# 2. Nginx 설정 추가
vim nginx/conf.d/default.conf
```

**default.conf에 추가:**
```nginx
# Upstream 정의 (파일 상단)
upstream my-new-service {
    server my-new-service:3000;
}

# HTTPS server 블록 안에 location 추가
server {
    # ... 기존 설정 ...

    location /myservice/ {
        proxy_pass http://my-new-service/;
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
}
```

#### Step 4: 배포

```bash
# Git 푸시로 자동 배포
git add .
git commit -m "Add my-new-service to infrastructure"
git push origin main
```

#### Step 5: 배포 확인

```bash
# 서버 SSH 접속
ssh ubuntu@your-server

# 서비스 상태 확인
docker ps | grep my-new-service

# 로그 확인
docker logs my-new-service --tail=50

# 헬스체크 확인
curl http://localhost:3000/health  # 컨테이너 내부
curl https://hstarsp.net/myservice/health  # 외부 접근
```

---

## 배포 시나리오별 가이드

### 긴급 롤백이 필요한 경우

새 버전에 치명적인 버그가 있어서 즉시 이전 버전으로 되돌려야 하는 경우:

#### 방법 1: 이전 이미지 태그 사용

```bash
# 서버 SSH 접속
ssh ubuntu@your-server
cd ~/indexpage

# docker-compose.yml 임시 수정
vim docker-compose.yml
# 이미지 태그를 latest에서 특정 버전으로 변경
# image: ghcr.io/zerone6/highschool-calendar:v1.2.3

# 재배포
docker compose pull highschool
docker compose up -d highschool
```

#### 방법 2: 서비스 저장소에서 롤백 후 재배포

```bash
# 로컬에서 이전 커밋으로 되돌리기
cd ~/GitHub/highschool-calendar
git log --oneline  # 이전 커밋 확인
git revert HEAD    # 또는 git reset --hard <commit-hash>
git push origin main

# 자동으로 이미지 빌드되면 서버에서 pull
# (또는 indexpage 푸시로 자동 배포)
```

### 여러 서비스를 동시에 업데이트하는 경우

여러 서비스가 동시에 업데이트되어야 하는 경우 (예: Frontend + Backend):

```bash
# 각 서비스 저장소에서 푸시 (순서 무관)
cd ~/GitHub/realestate-calc-frontend
git push origin main

cd ~/GitHub/realestate-calc-backend
git push origin main

# 모든 이미지 빌드 완료 후 한 번에 배포
cd ~/GitHub/indexpage
echo "Deploy both services: $(date)" >> README.md
git add .
git commit -m "Deploy realestate frontend and backend updates"
git push origin main
```

### 서버 재부팅 후 복구

서버가 재부팅된 경우:

```bash
ssh ubuntu@your-server

cd ~/indexpage

# 모든 서비스 시작
docker compose up -d

# 상태 확인
docker ps
docker compose logs -f
```

Docker는 `restart: unless-stopped` 정책으로 자동 재시작되지만, 수동 확인이 안전합니다.

---

## 주의사항 및 체크리스트

### 배포 전 체크리스트

**서비스 저장소 배포 시:**
- [ ] Dockerfile이 올바르게 작성되었는가?
- [ ] GitHub Actions 워크플로우가 성공적으로 실행되었는가?
- [ ] GHCR 이미지가 Public으로 설정되었는가?
- [ ] 이미지 빌드 로그에 에러가 없는가?

**Infrastructure 저장소 배포 시:**
- [ ] Nginx 설정 문법이 올바른가? (`nginx -t`)
- [ ] docker-compose.yml에 문법 오류가 없는가?
- [ ] SSL 인증서가 서버에 존재하는가?
- [ ] 새 upstream은 실제로 실행 중인 서비스를 가리키는가?

### 일반적인 실수와 예방법

#### 1. **GHCR 이미지가 Private 상태**

**증상:**
```
Error response from daemon: pull access denied for ghcr.io/zerone6/my-service
```

**해결:**
GitHub → Packages → 해당 패키지 → Settings → Change visibility → Public

#### 2. **Nginx가 존재하지 않는 upstream 참조**

**증상:**
```
nginx: [emerg] host not found in upstream "my-service"
```

**해결:**
- upstream 정의와 docker-compose.yml의 서비스명이 정확히 일치하는지 확인
- 서비스가 실행되기 전에는 해당 upstream 주석 처리

#### 3. **SSL 인증서 누락**

**증상:**
```
nginx: [emerg] cannot load certificate "/etc/nginx/ssl/fullchain.pem"
```

**해결:**
```bash
# 서버에서 SSL 인증서 확인
ls -la ~/indexpage/nginx/ssl/

# 없으면 Let's Encrypt에서 복사
sudo cp /etc/letsencrypt/live/hstarsp.net/fullchain.pem ~/indexpage/nginx/ssl/
sudo cp /etc/letsencrypt/live/hstarsp.net/privkey.pem ~/indexpage/nginx/ssl/
sudo chown $USER:$USER ~/indexpage/nginx/ssl/*.pem
```

#### 4. **포트 충돌**

**증상:**
```
Error starting userland proxy: listen tcp4 0.0.0.0:80: bind: address already in use
```

**해결:**
```bash
# 포트를 사용 중인 프로세스 확인
sudo lsof -i :80

# 기존 서비스 중지 후 재시작
docker compose down
docker compose up -d
```

#### 5. **배포 시 파일 누락**

**증상:**
서버에 특정 파일들이 복사되지 않음 (특히 .md, .sh 파일)

**해결:**
`deploy.yml`의 scp-action에서 source 패턴 확인:
```yaml
source: "docker-compose.yml,.gitignore,*.md,*.sh,nginx/,main-page/"
```

---

## 트러블슈팅

### 배포가 실패하는 경우

#### 1. GitHub Actions 로그 확인

```
GitHub 저장소 → Actions 탭 → 실패한 워크플로우 클릭
```

일반적인 실패 원인:
- Docker 빌드 에러 (Dockerfile 문법)
- SSH 연결 실패 (Secrets 설정 확인)
- SCP 파일 전송 실패 (권한 문제)

#### 2. 서버 상태 확인

```bash
ssh ubuntu@your-server

# 디스크 공간 확인
df -h

# Docker 상태 확인
sudo systemctl status docker

# 컨테이너 상태 확인
docker ps -a

# 특정 서비스 로그
docker logs <container-name> --tail=100
```

#### 3. 네트워크 연결 확인

```bash
# 서버에서
docker network ls
docker network inspect web

# 컨테이너 간 통신 테스트
docker exec nginx-proxy ping highschool -c 3
```

### 서비스가 시작되지 않는 경우

#### 1. 이미지가 제대로 Pull 되었는지 확인

```bash
docker images | grep ghcr.io

# 수동으로 pull 시도
docker pull ghcr.io/zerone6/highschool-calendar:latest
```

#### 2. 컨테이너 재생성

```bash
cd ~/indexpage

# 강제 재생성
docker compose up -d --force-recreate highschool

# 또는 완전히 삭제 후 재생성
docker compose down
docker compose up -d
```

#### 3. 헬스체크 상태 확인

```bash
docker inspect highschool | grep -A 10 Health

# 또는
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Nginx 설정 문제

#### 1. Nginx 설정 테스트

```bash
# 서버에서
docker compose exec nginx-proxy nginx -t

# 설정이 올바르면:
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

#### 2. Nginx 로그 확인

```bash
# Access log
docker logs nginx-proxy --tail=50

# Error log 필터링
docker logs nginx-proxy 2>&1 | grep error
```

#### 3. Nginx 리로드

```bash
# 설정 변경 후 리로드 (재시작 없이)
docker compose exec nginx-proxy nginx -s reload

# 또는 컨테이너 재시작
docker compose restart nginx-proxy
```

---

## 배포 플로우 요약

### 일일 개발 워크플로우

```bash
# 1. 서비스 개발
cd ~/GitHub/highschool-calendar
# ... 코드 수정 ...
git push origin main
# → GitHub Actions 자동 빌드 → GHCR 푸시

# 2. 서버에 배포 (2가지 방법 중 선택)

# 방법 A: 자동 배포
cd ~/GitHub/indexpage
echo "Trigger deploy: $(date)" >> README.md
git add . && git commit -m "Deploy" && git push

# 방법 B: 수동 배포 (빠름)
ssh ubuntu@server "cd ~/indexpage && docker compose pull && docker compose up -d"

# 3. 확인
curl https://hstarsp.net/highschool/
docker logs highschool --tail=20
```

### 주간/월간 유지보수

```bash
# 서버 접속
ssh ubuntu@your-server

# 1. 모든 서비스 업데이트
cd ~/indexpage
docker compose pull
docker compose up -d

# 2. 사용하지 않는 이미지 정리
docker image prune -a

# 3. SSL 인증서 갱신 (Let's Encrypt)
sudo certbot renew --dry-run  # 테스트
sudo certbot renew            # 실제 갱신

# 4. 로그 확인
docker compose logs --tail=50

# 5. 리소스 사용량 모니터링
docker stats --no-stream
```

---

## 추가 리소스

- **[README.md](README.md)** - 전체 프로젝트 개요
- **[BACKEND-SERVICE-GUIDE.md](BACKEND-SERVICE-GUIDE.md)** - 백엔드 서비스 추가 상세 가이드
- **[HIGHSCHOOL-SETUP.md](HIGHSCHOOL-SETUP.md)** - Highschool Calendar 분리 과정
- **[nginx/ssl/README.md](nginx/ssl/README.md)** - SSL 인증서 관리

---

**마지막 업데이트:** 2024-12-15

**문의사항이나 문제가 발생하면 GitHub Issues를 활용하세요.**
