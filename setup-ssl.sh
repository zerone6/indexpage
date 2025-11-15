#!/bin/bash

# Let's Encrypt SSL 인증서 발급 스크립트
# 사용법: sudo ./setup-ssl.sh

echo "=========================================="
echo "Let's Encrypt SSL 인증서 발급"
echo "=========================================="
echo ""

# 도메인 설정
DOMAIN="hstarsp.net"
EMAIL="your-email@example.com"  # 실제 이메일로 변경 필요

# Certbot 설치 확인
if ! command -v certbot &> /dev/null; then
    echo "Certbot이 설치되어 있지 않습니다. 설치를 시작합니다..."

    # Ubuntu/Debian
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y certbot python3-certbot-nginx
    # CentOS/RHEL
    elif command -v yum &> /dev/null; then
        sudo yum install -y certbot python3-certbot-nginx
    else
        echo "패키지 매니저를 찾을 수 없습니다. 수동으로 certbot을 설치해주세요."
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo "옵션 1: Standalone 모드 (권장)"
echo "=========================================="
echo "이 방법은 기존 웹서버를 잠시 중지하고 인증서를 발급받습니다."
echo ""
echo "명령어:"
echo "sudo certbot certonly --standalone -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos"
echo ""

echo "=========================================="
echo "옵션 2: Webroot 모드"
echo "=========================================="
echo "이 방법은 실행 중인 웹서버를 유지하면서 인증서를 발급받습니다."
echo ""
echo "명령어:"
echo "sudo certbot certonly --webroot -w /var/www/html -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos"
echo ""

echo "=========================================="
echo "인증서 발급 후 작업"
echo "=========================================="
echo ""
echo "1. 인증서를 indexpage 디렉토리로 복사:"
echo "   mkdir -p ~/indexpage/nginx/ssl"
echo "   sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ~/indexpage/nginx/ssl/"
echo "   sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ~/indexpage/nginx/ssl/"
echo "   sudo chown \$USER:\$USER ~/indexpage/nginx/ssl/*.pem"
echo ""
echo "2. Docker 컨테이너 재시작:"
echo "   cd ~/indexpage"
echo "   docker compose down"
echo "   docker compose up -d nginx-proxy main-page"
echo ""
echo "3. 인증서 확인:"
echo "   sudo certbot certificates"
echo ""

echo "=========================================="
echo "자동 갱신 설정"
echo "=========================================="
echo ""
echo "Certbot은 systemd 타이머로 자동 갱신됩니다."
echo "확인: sudo systemctl status certbot.timer"
echo ""
echo "수동 갱신 테스트:"
echo "sudo certbot renew --dry-run"
echo ""
