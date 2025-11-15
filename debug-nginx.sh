#!/bin/bash

echo "=========================================="
echo "Nginx 진단 스크립트"
echo "=========================================="
echo ""

echo "1. 실행 중인 컨테이너 확인"
echo "------------------------------------------"
docker ps -a
echo ""

echo "2. Nginx 컨테이너 로그 확인"
echo "------------------------------------------"
docker logs nginx-proxy --tail=50
echo ""

echo "3. Main-page 컨테이너 로그 확인"
echo "------------------------------------------"
docker logs main-page --tail=50
echo ""

echo "4. 네트워크 확인"
echo "------------------------------------------"
docker network ls
docker network inspect web
echo ""

echo "5. 포트 바인딩 확인"
echo "------------------------------------------"
docker port nginx-proxy
echo ""

echo "6. Nginx 설정 테스트"
echo "------------------------------------------"
docker exec nginx-proxy nginx -t
echo ""

echo "7. 서버 방화벽 확인 (포트 80, 443)"
echo "------------------------------------------"
# ss 명령어 사용 (netstat 대체)
sudo ss -tlnp | grep -E ':(80|443)'
echo ""
echo "또는 lsof로 확인:"
sudo lsof -i :80 -i :443
echo ""

echo "8. SSL 인증서 확인"
echo "------------------------------------------"
ls -la ~/indexpage/nginx/ssl/
echo ""

echo "9. Nginx 설정 파일 확인"
echo "------------------------------------------"
docker exec nginx-proxy cat /etc/nginx/conf.d/default.conf
echo ""

echo "10. 로컬에서 Nginx 접근 테스트"
echo "------------------------------------------"
curl -I http://localhost
echo ""

echo "11. main-page 컨테이너 접근 테스트"
echo "------------------------------------------"
docker exec nginx-proxy wget -O- http://main-page || echo "main-page 접근 실패"
echo ""

echo "=========================================="
echo "진단 완료"
echo "=========================================="
