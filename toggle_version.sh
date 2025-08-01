#!/bin/bash

# v3 ↔ v2 왔다갔다 전환 테스트 스크립트
# 사용법: ./toggle_version.sh [v3|v2|auto]

CURRENT_VERSION_FILE="/tmp/current_active_version"

# 현재 활성 버전 확인
if [ -f "$CURRENT_VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat $CURRENT_VERSION_FILE)
else
    CURRENT_VERSION="v3"  # 기본값
fi

# 사용자 입력 처리
if [ "$1" = "v3" ]; then
    TARGET_VERSION="v3"
elif [ "$1" = "v2" ]; then
    TARGET_VERSION="v2"
elif [ "$1" = "auto" ]; then
    # 자동 토글: v3 → v2, v2 → v3
    if [ "$CURRENT_VERSION" = "v3" ]; then
        TARGET_VERSION="v2"
    else
        TARGET_VERSION="v3"
    fi
else
    echo "========================================"
    echo "🔄 버전 전환 테스트 도구"
    echo "========================================"
    echo "현재 활성 버전: $CURRENT_VERSION"
    echo ""
    echo "사용법:"
    echo "  ./toggle_version.sh v3     # v3으로 전환"
    echo "  ./toggle_version.sh v2     # v2로 전환"  
    echo "  ./toggle_version.sh auto   # 자동 토글"
    echo ""
    read -p "전환할 버전을 선택하세요 (v3/v2/auto): " TARGET_VERSION
    
    if [ "$TARGET_VERSION" = "auto" ]; then
        if [ "$CURRENT_VERSION" = "v3" ]; then
            TARGET_VERSION="v2"
        else
            TARGET_VERSION="v3"
        fi
    fi
fi

# 버전별 포트 설정
if [ "$TARGET_VERSION" = "v3" ]; then
    PORTS="10001 10002"
    VERSION_NAME="v3"
elif [ "$TARGET_VERSION" = "v2" ]; then
    PORTS="10005 10006"
    VERSION_NAME="v2"
else
    echo "❌ 잘못된 버전: $TARGET_VERSION"
    exit 1
fi

echo "========================================"
echo "🔄 $CURRENT_VERSION → $TARGET_VERSION 전환 중..."
echo "========================================"

# 1단계: 타겟 버전 헬스체크
echo "⏳ $TARGET_VERSION 헬스체크 중..."
healthy_count=0
for port in $PORTS; do
    response=$(curl -s -m 2 http://localhost:$port/hello 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "✅ 포트 $port: $response"
        ((healthy_count++))
    else
        echo "❌ 포트 $port: FAILED"
    fi
done

if [ $healthy_count -lt 2 ]; then
    echo "❌ $TARGET_VERSION 버전에 헬시한 인스턴스가 2개 미만입니다. 전환을 중단합니다."
    exit 1
fi

# 2단계: Load Balancer 설정 변경
echo ""
echo "🔄 Load Balancer → $TARGET_VERSION 전환 중..."

cat > /tmp/nginx_upstream.conf << NGINX_EOF
upstream hello_backend {
$(for port in $PORTS; do
    echo "    server 127.0.0.1:$port;"
done)
}

server {
    listen 8080;
    location / {
        proxy_pass http://hello_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Version $VERSION_NAME;
    }
}
NGINX_EOF

sudo cp /tmp/nginx_upstream.conf /etc/nginx/conf.d/hello-service.conf

# 3단계: Nginx 재로드
if sudo nginx -t; then
    sudo systemctl reload nginx
    echo "✅ Load Balancer가 $TARGET_VERSION으로 전환되었습니다!"
else
    echo "❌ Nginx 설정 오류입니다."
    exit 1
fi

# 4단계: 전환 확인
echo ""
echo "🧪 전환 확인 테스트:"
for i in {1..3}; do
    response=$(curl -s -w "\n응답시간:%{time_total}s" http://localhost:8080/hello)
    echo "테스트 $i: $response"
    sleep 1
done

# 5단계: 현재 버전 저장
echo "$TARGET_VERSION" > "$CURRENT_VERSION_FILE"

echo ""
echo "========================================"
echo "🎉 $CURRENT_VERSION → $TARGET_VERSION 전환 완료!"
echo "========================================"
echo "✅ 활성 포트: $PORTS"
echo "✅ Load Balancer: http://localhost:8080"
first_port=$(echo $PORTS | cut -d' ' -f1)
echo "📊 직접 접근: http://localhost:$first_port/hello"
