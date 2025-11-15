#!/bin/bash

echo "=========================================="
echo "배포 문제 해결 스크립트"
echo "=========================================="
echo ""

# 1. SSL 인증서 확인 및 복사
echo "1. SSL 인증서 확인 및 복사"
echo "------------------------------------------"
if sudo test -d /etc/letsencrypt/live/hstarsp.net; then
    echo "✓ Let's Encrypt 인증서 발견"

    mkdir -p ~/indexpage/nginx/ssl
    sudo cp /etc/letsencrypt/live/hstarsp.net/fullchain.pem ~/indexpage/nginx/ssl/
    sudo cp /etc/letsencrypt/live/hstarsp.net/privkey.pem ~/indexpage/nginx/ssl/
    sudo chown $USER:$USER ~/indexpage/nginx/ssl/*.pem

    echo "✓ SSL 인증서 복사 완료:"
    ls -la ~/indexpage/nginx/ssl/
else
    echo "✗ ERROR: Let's Encrypt 인증서를 찾을 수 없습니다"
    echo "  setup-ssl.sh 스크립트를 먼저 실행하여 SSL 인증서를 생성하세요"
    exit 1
fi
echo ""

# 2. Docker 네트워크 생성
echo "2. Docker 네트워크 생성"
echo "------------------------------------------"
docker network create web 2>/dev/null && echo "✓ 네트워크 'web' 생성" || echo "✓ 네트워크 'web' 이미 존재"
echo ""

# 3. 서비스 재시작
echo "3. 모든 서비스 재시작"
echo "------------------------------------------"
cd ~/indexpage
docker compose down
echo "✓ 기존 컨테이너 중지"

docker compose up -d
echo "✓ 서비스 시작"
echo ""

# 4. 서비스 상태 확인
echo "4. 서비스 상태 확인"
echo "------------------------------------------"
sleep 5
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# 5. Nginx 로그 확인
echo "5. Nginx 로그 확인 (최근 20줄)"
echo "------------------------------------------"
docker logs nginx-proxy --tail=20
echo ""

# 6. 헬스체크
echo "6. 헬스체크 수행"
echo "------------------------------------------"
echo "HTTP Health Check:"
curl -s http://localhost/health && echo "" || echo "✗ HTTP 헬스체크 실패"

echo "HTTPS Health Check:"
curl -k -s https://localhost/health && echo "" || echo "✗ HTTPS 헬스체크 실패"

echo "Main Page Check:"
curl -k -s https://localhost/ | grep -q "가족 정보 공유" && echo "✓ Main Page 정상" || echo "✗ Main Page 접근 실패"

echo "Highschool Service Check:"
curl -s http://localhost/highschool/ | head -n 5 || echo "✗ Highschool 서비스 접근 실패"
echo ""

echo "=========================================="
echo "해결 완료"
echo "=========================================="
echo ""
echo "외부 접근 테스트:"
echo "  https://hstarsp.net/"
echo "  https://hstarsp.net/highschool/"
