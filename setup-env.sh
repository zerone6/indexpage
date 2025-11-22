#!/bin/bash

# .env 파일 자동 생성 스크립트

ENV_FILE=".env"
ENV_EXAMPLE=".env.example"

if [ -f "$ENV_FILE" ]; then
    echo "✅ .env 파일이 이미 존재합니다."
    echo "현재 설정:"
    cat "$ENV_FILE"
else
    if [ -f "$ENV_EXAMPLE" ]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        echo "✅ .env 파일이 생성되었습니다."
        echo ""
        echo "📝 다음 항목을 환경에 맞게 수정하세요:"
        echo "   - SPRING_PROFILES_ACTIVE (dev/prod)"
        echo "   - REALESTATE_DB_URL (데이터베이스 주소)"
        echo "   - REALESTATE_DB_USERNAME (데이터베이스 사용자명)"
        echo "   - REALESTATE_DB_PASSWORD (데이터베이스 비밀번호)"
        echo ""
        echo "편집: nano .env 또는 vi .env"
    else
        echo "❌ .env.example 파일을 찾을 수 없습니다."
        exit 1
    fi
fi
