#!/bin/bash

echo "=========================================="
echo "로컬 개발 환경 설정 스크립트"
echo "=========================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 현재 디렉토리 확인
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}✗ 오류: indexpage 디렉토리에서 실행해주세요${NC}"
    exit 1
fi

echo "1. 프로젝트 구조 확인"
echo "------------------------------------------"

# 필요한 프로젝트 체크
PROJECTS_DIR="$(dirname $(pwd))"
REQUIRED_PROJECTS=("highschool-calendar")

for project in "${REQUIRED_PROJECTS[@]}"; do
    if [ -d "$PROJECTS_DIR/$project" ]; then
        echo -e "${GREEN}✓${NC} $project 발견: $PROJECTS_DIR/$project"
    else
        echo -e "${YELLOW}⚠${NC} $project 없음: $PROJECTS_DIR/$project"
        echo "   docker-compose.override.yml을 수정하여 경로를 조정하세요"
    fi
done
echo ""

echo "2. SSL 인증서 설정 (로컬 자체 서명 인증서)"
echo "------------------------------------------"

if [ -f "nginx/ssl/fullchain.pem" ] && [ -f "nginx/ssl/privkey.pem" ]; then
    echo -e "${GREEN}✓${NC} SSL 인증서가 이미 존재합니다"
else
    echo "로컬 개발용 자체 서명 인증서를 생성합니다..."
    mkdir -p nginx/ssl

    # 자체 서명 인증서 생성
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout nginx/ssl/privkey.pem \
        -out nginx/ssl/fullchain.pem \
        -subj "/C=KR/ST=Seoul/L=Seoul/O=Local Dev/CN=localhost" \
        2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} 로컬 SSL 인증서 생성 완료"
    else
        echo -e "${RED}✗${NC} SSL 인증서 생성 실패"
        echo "   수동으로 생성하거나 프로덕션 인증서를 복사하세요"
    fi
fi
echo ""

echo "3. Docker 네트워크 생성"
echo "------------------------------------------"
docker network create web 2>/dev/null && echo -e "${GREEN}✓${NC} 네트워크 'web' 생성" || echo -e "${GREEN}✓${NC} 네트워크 'web' 이미 존재"
echo ""

echo "4. Main Page 이미지 빌드"
echo "------------------------------------------"
docker build -t main-page:latest ./main-page
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Main Page 이미지 빌드 완료"
else
    echo -e "${RED}✗${NC} Main Page 이미지 빌드 실패"
    exit 1
fi
echo ""

echo "5. 로컬 환경 시작"
echo "------------------------------------------"
echo "docker-compose.override.yml을 사용하여 로컬 빌드로 서비스를 시작합니다..."
echo ""

# 사용 가능한 서비스만 시작
docker compose up -d

echo ""
echo "6. 서비스 상태 확인 (10초 대기)"
echo "------------------------------------------"
sleep 10
docker compose ps
echo ""

echo "7. 서비스 헬스체크"
echo "------------------------------------------"

# HTTP Health Check
echo -n "HTTP Health Check: "
if curl -s http://localhost/health > /dev/null; then
    echo -e "${GREEN}✓ 성공${NC}"
else
    echo -e "${RED}✗ 실패${NC}"
fi

# HTTPS Health Check (자체 서명 인증서이므로 -k 옵션 사용)
echo -n "HTTPS Health Check: "
if curl -k -s https://localhost/health > /dev/null; then
    echo -e "${GREEN}✓ 성공${NC}"
else
    echo -e "${RED}✗ 실패${NC}"
fi

# Main Page Check
echo -n "Main Page: "
if curl -s http://localhost/ | grep -q "가족 정보"; then
    echo -e "${GREEN}✓ 성공${NC}"
else
    echo -e "${RED}✗ 실패${NC}"
fi

# Highschool Service Check
if docker compose ps | grep -q highschool; then
    echo -n "Highschool Service: "
    if curl -s http://localhost/highschool/ > /dev/null; then
        echo -e "${GREEN}✓ 성공${NC}"
    else
        echo -e "${RED}✗ 실패${NC}"
    fi
fi

echo ""
echo "=========================================="
echo "로컬 개발 환경 준비 완료!"
echo "=========================================="
echo ""
echo "접속 URL:"
echo "  • Main Page:      http://localhost/"
echo "  • Main Page:      https://localhost/ (자체 서명 인증서)"
echo "  • Highschool:     http://localhost/highschool/"
echo "  • Health Check:   http://localhost/health"
echo ""
echo "유용한 명령어:"
echo "  • 로그 보기:       docker compose logs -f"
echo "  • 특정 로그:       docker compose logs -f highschool"
echo "  • 서비스 재시작:   docker compose restart"
echo "  • 서비스 중지:     docker compose down"
echo "  • 이미지 재빌드:   docker compose up -d --build"
echo ""
echo "프로덕션 모드로 테스트:"
echo "  docker compose -f docker-compose.yml up -d"
echo ""
