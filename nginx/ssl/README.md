# SSL Certificate Management

이 디렉토리는 SSL 인증서를 저장합니다.

## 필요한 파일

- `fullchain.pem` - SSL 인증서 체인
- `privkey.pem` - SSL 개인 키 (gitignored)

## 서버에서 인증서 복사하기

```bash
# 서버에서 인증서 복사
sudo cp /etc/letsencrypt/live/hstarsp.net/fullchain.pem ~/indexpage/nginx/ssl/
sudo cp /etc/letsencrypt/live/hstarsp.net/privkey.pem ~/indexpage/nginx/ssl/
sudo chown $USER:$USER ~/indexpage/nginx/ssl/*.pem
```

## Let's Encrypt 인증서 갱신

```bash
# 인증서 갱신 (서버에서 실행)
sudo certbot renew

# 갱신 후 새 인증서 복사
sudo cp /etc/letsencrypt/live/hstarsp.net/fullchain.pem ~/indexpage/nginx/ssl/
sudo cp /etc/letsencrypt/live/hstarsp.net/privkey.pem ~/indexpage/nginx/ssl/
sudo chown $USER:$USER ~/indexpage/nginx/ssl/*.pem

# Nginx 재시작
cd ~/indexpage
docker compose restart nginx-proxy
```

## 자동 갱신 설정

Let's Encrypt 인증서는 90일마다 만료됩니다. 자동 갱신을 위해 cron을 설정할 수 있습니다.

```bash
# crontab 편집
sudo crontab -e

# 매월 1일 새벽 2시에 갱신 확인
0 2 1 * * certbot renew --quiet && cp /etc/letsencrypt/live/hstarsp.net/*.pem ~/indexpage/nginx/ssl/ && docker restart nginx-proxy
```

## 보안 주의사항

- `privkey.pem`은 절대 git에 커밋하지 마세요
- 서버에서만 인증서를 관리하세요
- 인증서 파일의 권한을 적절히 설정하세요 (600 또는 644)
