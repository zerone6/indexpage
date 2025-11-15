#!/bin/bash

echo "=========================================="
echo "서비스 재시작 스크립트"
echo "=========================================="
echo ""

cd ~/indexpage

echo "1. 모든 컨테이너 중지"
echo "------------------------------------------"
docker compose down
echo ""

echo "2. Docker 네트워크 확인"
echo "------------------------------------------"
docker network create web 2>/dev/null && echo "✓ 네트워크 'web' 생성" || echo "✓ 네트워크 'web' 이미 존재"
docker network ls | grep web
echo ""

echo "3. 모든 서비스 시작"
echo "------------------------------------------"
docker compose up -d
echo ""

echo "4. 컨테이너 상태 확인 (10초 대기)"
echo "------------------------------------------"
sleep 10
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "5. 각 서비스 로그 확인"
echo "------------------------------------------"
echo "=== Nginx Proxy ==="
docker logs nginx-proxy --tail=20 2>&1 | tail -10
echo ""

echo "=== Main Page ==="
docker logs main-page --tail=10 2>&1 | tail -5
echo ""

echo "=== Highschool ==="
docker logs highschool --tail=10 2>&1 | tail -5 || echo "Highschool 컨테이너 없음"
echo ""

echo "6. 네트워크 연결 확인"
echo "------------------------------------------"
docker network inspect web | grep -A 2 "Containers" | head -20
echo ""

echo "7. 헬스체크"
echo "------------------------------------------"
echo "HTTP Health:"
curl -s http://localhost/health || echo "✗ 실패"
echo ""

echo "Main Page:"
curl -s http://localhost/ | grep -q "가족 정보" && echo "✓ Main Page 정상" || echo "✗ Main Page 접근 실패"
echo ""

if docker ps | grep -q highschool; then
    echo "Highschool Service:"
    curl -s http://localhost/highschool/ | head -n 1 || echo "✗ Highschool 접근 실패"
fi
echo ""

echo "=========================================="
echo "재시작 완료"
echo "=========================================="
echo ""
echo "외부 접근 테스트:"
echo "  https://hstarsp.net/"
echo "  https://hstarsp.net/highschool/"
