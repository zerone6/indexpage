#!/bin/bash

echo "=========================================="
echo "Highschool 서비스 진단 스크립트"
echo "=========================================="
echo ""

echo "1. Git 상태 확인"
echo "------------------------------------------"
cd ~/indexpage
git status
echo ""

echo "2. Docker Compose 설정 확인"
echo "------------------------------------------"
cat docker-compose.yml | grep -A 15 "highschool:"
echo ""

echo "3. Nginx 설정 확인"
echo "------------------------------------------"
echo "Upstream 확인:"
cat nginx/conf.d/default.conf | grep -A 3 "upstream highschool"
echo ""
echo "Location 확인:"
cat nginx/conf.d/default.conf | grep -A 12 "location /highschool/"
echo ""

echo "4. 실행 중인 컨테이너 확인"
echo "------------------------------------------"
docker ps -a | grep -E "CONTAINER|highschool|nginx-proxy|main-page"
echo ""

echo "5. Highschool 컨테이너 로그 확인"
echo "------------------------------------------"
docker logs highschool --tail=30 2>&1 || echo "highschool 컨테이너가 없습니다"
echo ""

echo "6. Docker 이미지 확인"
echo "------------------------------------------"
docker images | grep -E "REPOSITORY|highschool"
echo ""

echo "7. GHCR에서 이미지 Pull 테스트"
echo "------------------------------------------"
docker pull ghcr.io/zerone6/highschool-calendar:latest
echo ""

echo "8. Docker Compose에서 Highschool Pull"
echo "------------------------------------------"
cd ~/indexpage
docker compose pull highschool
echo ""

echo "9. 네트워크 확인"
echo "------------------------------------------"
docker network inspect web | grep -A 10 "Containers"
echo ""

echo "10. Highschool 서비스 시작 시도"
echo "------------------------------------------"
docker compose up -d highschool
echo ""

echo "11. 최종 상태 확인"
echo "------------------------------------------"
docker ps | grep -E "CONTAINER|highschool"
echo ""

echo "12. Nginx 재시작"
echo "------------------------------------------"
docker compose restart nginx-proxy
echo ""

echo "13. Nginx 로그 확인"
echo "------------------------------------------"
docker logs nginx-proxy --tail=20
echo ""

echo "=========================================="
echo "진단 완료"
echo "=========================================="
