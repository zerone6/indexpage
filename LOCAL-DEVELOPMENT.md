# 로컬 개발 환경 가이드

이 문서는 indexpage 프로젝트를 로컬에서 개발하고 테스트하는 방법을 설명합니다.

## 📋 목차

1. [개발 환경 구성](#개발-환경-구성)
2. [빠른 시작](#빠른-시작)
3. [로컬 vs 프로덕션 차이점](#로컬-vs-프로덕션-차이점)
4. [일반적인 개발 워크플로우](#일반적인-개발-워크플로우)
5. [트러블슈팅](#트러블슈팅)

---

## 개발 환경 구성

### 필수 요구사항

- Docker Desktop (macOS/Windows) 또는 Docker Engine (Linux)
- Git
- 최소 8GB RAM
- 10GB 이상의 디스크 공간

### 프로젝트 구조

로컬에서 개발하려면 다음과 같은 디렉토리 구조를 권장합니다:

```
~/GitHub/homegroup/
├── indexpage/                    # Infrastructure (이 저장소)
│   ├── docker-compose.yml        # 프로덕션 설정
│   ├── docker-compose.override.yml  # 로컬 개발 설정
│   ├── nginx/
│   ├── main-page/
│   └── local-dev.sh              # 로컬 환경 설정 스크립트
├── highschool-calendar/          # Highschool 서비스
│   ├── Dockerfile
│   └── src/
├── realestate-calc/              # Real Estate 서비스 (선택적)
│   ├── frontend/
│   └── backend/
└── ...
```

---

## 빠른 시작

### 방법 1: 자동 설정 스크립트 사용 (권장)

```bash
cd ~/GitHub/homegroup/indexpage

# 실행 권한 부여
chmod +x local-dev.sh

# 로컬 환경 설정 및 시작
./local-dev.sh
```

이 스크립트는 자동으로:
- SSL 인증서 생성 (자체 서명)
- Docker 네트워크 생성
- Main Page 이미지 빌드
- 모든 서비스 시작
- 헬스체크 수행

### 방법 2: 수동 설정

#### 1. SSL 인증서 생성 (로컬용)

```bash
mkdir -p nginx/ssl

# 자체 서명 인증서 생성
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout nginx/ssl/privkey.pem \
    -out nginx/ssl/fullchain.pem \
    -subj "/C=KR/ST=Seoul/L=Seoul/O=Local Dev/CN=localhost"
```

#### 2. Docker 네트워크 생성

```bash
docker network create web
```

#### 3. Main Page 이미지 빌드

```bash
docker build -t main-page:latest ./main-page
```

#### 4. 서비스 시작

```bash
# 로컬 개발 모드 (docker-compose.override.yml 사용)
docker compose up -d

# 또는 프로덕션 모드 테스트
docker compose -f docker-compose.yml up -d
```

### 접속 확인

- **Main Page**: http://localhost/ 또는 https://localhost/
- **Highschool**: http://localhost/highschool/
- **Health Check**: http://localhost/health

**참고**: HTTPS는 자체 서명 인증서를 사용하므로 브라우저 경고가 표시됩니다. "고급" → "계속 진행"을 클릭하면 됩니다.

---

## 로컬 vs 프로덕션 차이점

### docker-compose.override.yml의 역할

`docker-compose.override.yml`은 **로컬 개발 전용** 설정입니다:

| 항목 | 프로덕션 (docker-compose.yml) | 로컬 (+ override.yml) |
|------|-------------------------------|----------------------|
| **Highschool 이미지** | `ghcr.io/zerone6/highschool-calendar:latest` (GHCR) | 로컬 빌드 (`../highschool-calendar`) |
| **Real Estate 이미지** | `ghcr.io/zerone6/realestate-*:latest` | 로컬 빌드 |
| **SSL 인증서** | Let's Encrypt 프로덕션 인증서 | 자체 서명 인증서 |
| **서비스 프로필** | `profiles: [full]` (선택적) | 모든 서비스 자동 시작 |

### override.yml 작동 방식

Docker Compose는 다음 순서로 파일을 자동 병합합니다:

1. `docker-compose.yml` 읽기
2. `docker-compose.override.yml`이 있으면 읽기
3. 같은 서비스는 override 설정이 우선

**예시:**

```yaml
# docker-compose.yml
services:
  highschool:
    image: ghcr.io/zerone6/highschool-calendar:latest

# docker-compose.override.yml
services:
  highschool:
    build:
      context: ../highschool-calendar
    image: highschool:local
```

결과: 로컬에서는 `../highschool-calendar`를 빌드하여 사용

### 프로덕션 모드로 테스트하기

로컬에서 프로덕션 환경을 정확히 재현하려면:

```bash
# override.yml 무시하고 실행
docker compose -f docker-compose.yml up -d

# GHCR 이미지를 사용하므로 pull 필요
docker compose -f docker-compose.yml pull
```

---

## 일반적인 개발 워크플로우

### 시나리오 1: Main Page 수정

```bash
# 1. HTML/CSS 수정
vim main-page/index.html

# 2. 이미지 재빌드 및 재시작
docker compose up -d --build main-page

# 3. 브라우저에서 확인
open http://localhost/

# 4. 로그 확인
docker compose logs -f main-page
```

### 시나리오 2: Nginx 설정 변경

```bash
# 1. Nginx 설정 수정
vim nginx/conf.d/default.conf

# 2. 설정 문법 검증
docker compose exec nginx-proxy nginx -t

# 3. Nginx 리로드 (재시작 없이)
docker compose exec nginx-proxy nginx -s reload

# 또는 재시작
docker compose restart nginx-proxy

# 4. 로그 확인
docker compose logs -f nginx-proxy
```

### 시나리오 3: Highschool 서비스 개발

```bash
# 1. Highschool 프로젝트로 이동
cd ../highschool-calendar

# 2. 코드 수정
vim src/App.js

# 3. indexpage로 돌아와서 재빌드
cd ../indexpage
docker compose up -d --build highschool

# 4. 확인
curl http://localhost/highschool/
docker compose logs -f highschool
```

### 시나리오 4: 전체 스택 재시작

```bash
# 모든 컨테이너 중지
docker compose down

# 이미지 재빌드 및 시작
docker compose up -d --build

# 또는 캐시 무시하고 완전히 재빌드
docker compose build --no-cache
docker compose up -d
```

---

## 유용한 명령어

### 서비스 상태 확인

```bash
# 실행 중인 컨테이너 확인
docker compose ps

# 상세 상태
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# 리소스 사용량
docker stats
```

### 로그 확인

```bash
# 모든 서비스 로그 (실시간)
docker compose logs -f

# 특정 서비스 로그
docker compose logs -f nginx-proxy

# 최근 100줄만 보기
docker compose logs --tail=100 highschool

# 타임스탬프 포함
docker compose logs -f -t
```

### 컨테이너 내부 접근

```bash
# Nginx 컨테이너 shell 접속
docker compose exec nginx-proxy sh

# Main Page 컨테이너 접속
docker compose exec main-page sh

# 일회성 명령 실행
docker compose exec nginx-proxy cat /etc/nginx/conf.d/default.conf
```

### 네트워크 디버깅

```bash
# 네트워크 확인
docker network ls
docker network inspect web

# 컨테이너 간 통신 테스트
docker compose exec nginx-proxy ping highschool
docker compose exec nginx-proxy nslookup highschool

# 포트 확인
docker compose exec nginx-proxy netstat -tlnp
```

### 클린업

```bash
# 서비스 중지 및 제거
docker compose down

# 볼륨까지 제거
docker compose down -v

# 미사용 이미지 정리
docker image prune -a

# 전체 클린업 (주의!)
docker system prune -a --volumes
```

---

## 트러블슈팅

### 1. "host not found in upstream" 오류

**증상:**
```
nginx: [emerg] host not found in upstream "highschool"
```

**원인:** Nginx가 시작할 때 highschool 컨테이너를 찾지 못함

**해결:**
```bash
# 모든 서비스 재시작 (depends_on이 작동하도록)
docker compose down
docker compose up -d

# 또는 순서대로 시작
docker compose up -d main-page highschool
docker compose up -d nginx-proxy
```

### 2. SSL 인증서 오류

**증상:**
```
nginx: [emerg] cannot load certificate "/etc/nginx/ssl/fullchain.pem"
```

**해결:**
```bash
# 로컬 자체 서명 인증서 생성
mkdir -p nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout nginx/ssl/privkey.pem \
    -out nginx/ssl/fullchain.pem \
    -subj "/C=KR/ST=Seoul/L=Seoul/O=Local Dev/CN=localhost"

# 서비스 재시작
docker compose restart nginx-proxy
```

### 3. 포트 충돌 (80, 443 이미 사용 중)

**증상:**
```
Error starting userland proxy: listen tcp 0.0.0.0:80: bind: address already in use
```

**해결:**
```bash
# 포트 사용 중인 프로세스 확인
sudo lsof -i :80
sudo lsof -i :443

# 프로세스 종료 후 재시작
docker compose down
docker compose up -d
```

### 4. 이미지 빌드 실패

**증상:**
```
failed to solve: failed to compute cache key
```

**해결:**
```bash
# 빌드 캐시 무시
docker compose build --no-cache

# Docker BuildKit 비활성화
DOCKER_BUILDKIT=0 docker compose build
```

### 5. Highschool 서비스가 시작되지 않음

**원인:** `docker-compose.override.yml`의 경로가 잘못됨

**확인:**
```bash
# override.yml의 경로 확인
cat docker-compose.override.yml

# highschool-calendar 프로젝트 위치 확인
ls ../highschool-calendar
```

**해결:**
```bash
# override.yml 수정
vim docker-compose.override.yml

# context 경로를 실제 프로젝트 위치로 변경
services:
  highschool:
    build:
      context: ../highschool-calendar  # 실제 경로로 변경
```

또는 GHCR 이미지 사용:
```bash
# override.yml 무시하고 프로덕션 모드 실행
docker compose -f docker-compose.yml pull
docker compose -f docker-compose.yml up -d
```

### 6. 브라우저 캐시 문제

**증상:** 코드를 수정했는데 변경사항이 반영되지 않음

**해결:**
```bash
# 하드 리프레시
# Chrome/Edge: Ctrl+Shift+R (Windows/Linux) 또는 Cmd+Shift+R (Mac)
# Firefox: Ctrl+F5 또는 Cmd+Shift+R

# 또는 브라우저 개발자 도구 → Network 탭 → "Disable cache" 체크
```

### 7. 로그가 너무 많아서 느림

**해결:**
```bash
# 로그 크기 제한 (docker-compose.yml에 추가)
services:
  nginx-proxy:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

---

## 개발 팁

### 1. 빠른 반복 개발

Main Page 같은 정적 파일은 볼륨 마운트로 실시간 반영:

```yaml
# docker-compose.override.yml에 추가
services:
  main-page:
    volumes:
      - ./main-page/index.html:/usr/share/nginx/html/index.html:ro
```

이렇게 하면 HTML 수정 시 이미지 재빌드 없이 즉시 반영됩니다.

### 2. 특정 서비스만 실행

모든 서비스가 필요하지 않다면:

```bash
# Main Page와 Nginx만 시작
docker compose up -d nginx-proxy main-page
```

### 3. 환경 변수 오버라이드

`.env` 파일 생성:

```bash
# .env
COMPOSE_PROJECT_NAME=indexpage
COMPOSE_FILE=docker-compose.yml:docker-compose.override.yml
```

### 4. VS Code 개발 환경

`.vscode/tasks.json` 생성:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Start Local Dev",
      "type": "shell",
      "command": "docker compose up -d",
      "problemMatcher": []
    },
    {
      "label": "Stop Services",
      "type": "shell",
      "command": "docker compose down",
      "problemMatcher": []
    },
    {
      "label": "View Logs",
      "type": "shell",
      "command": "docker compose logs -f",
      "problemMatcher": []
    }
  ]
}
```

---

## 추가 리소스

- **[README.md](README.md)** - 프로젝트 전체 개요
- **[GUIDE-DEPLOY-PROCESS.md](GUIDE-DEPLOY-PROCESS.md)** - 배포 프로세스
- **[BACKEND-SERVICE-GUIDE.md](BACKEND-SERVICE-GUIDE.md)** - 백엔드 서비스 추가
- **Docker Compose 공식 문서**: https://docs.docker.com/compose/

---

**문의사항이 있으면 GitHub Issues를 활용하세요.**
