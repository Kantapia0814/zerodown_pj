#!/bin/bash

# 진정한 무중단(Zero-Downtime) Consul 기반 동적 포트 버전 전환 스크립트
# 핵심: 재배포 없이 태그만 변경하여 즉시 전환
#
# ⚠️ 주의사항:
# - v3 이미지가 올바른 메시지를 반환하는지 확인 필요
# - 현재 v3가 "Zinedine Zidane"을 반환한다면 이미지 재빌드 필요:
#   cd hello-service && docker build -t kantapia14/hello-service:v3 . && docker push kantapia14/hello-service:v3

CONSUL_ADDR="http://127.0.0.1:8500"
SERVICE_NAME="hello-service"
NOMAD_JOB_FILE="hello-service-dynamic.nomad"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_magic() { echo -e "${PURPLE}[MAGIC]${NC} $1"; }
log_zero() { echo -e "${CYAN}[ZERO-DOWNTIME]${NC} $1"; }

# Consul에서 서비스 조회
get_services() {
    local tag_filter="$1"
    curl -s "${CONSUL_ADDR}/v1/catalog/service/${SERVICE_NAME}?tag=${tag_filter}" | jq -r '.[] | "\(.ServiceAddress):\(.ServicePort) (\(.ServiceMeta.version)) [\(.ServiceID)]"' 2>/dev/null
}

# 서비스 상태 확인
check_service_health() {
    local address="$1"
    local port="$2"
    curl -s -m 2 "http://${address}:${port}/hello" > /dev/null 2>&1
    return $?
}

# 현재 서비스 상태 표시
show_status() {
    echo "========================================"
    echo "🔍 Zero-Downtime 시스템 상태"
    echo "========================================"
    
    log_info "🔵 Active 서비스들 (현재 트래픽 처리 중):"
    local active_services=$(get_services "active")
    if [ -z "$active_services" ]; then
        log_warning "Active 서비스가 없습니다!"
    else
        echo "$active_services" | while read line; do
            if [ ! -z "$line" ]; then
                log_success "  ✅ $line"
            fi
        done
    fi
    
    echo ""
    log_info "⚪ Standby 서비스들 (대기 중):"
    local standby_services=$(get_services "standby")
    if [ -z "$standby_services" ]; then
        log_warning "Standby 서비스가 없습니다!"
    else
        echo "$standby_services" | while read line; do
            if [ ! -z "$line" ]; then
                echo -e "  ⏸️  $line"
            fi
        done
    fi
    
    echo ""
    log_info "🎯 실제 응답 테스트:"
    echo -n "  Active (via LB): "
    curl -s http://localhost:8080/hello | head -c 60
    echo ""
    echo -n "  Standby (via LB): "
    curl -s http://localhost:8080/standby | head -c 60
    echo ""
    
    echo ""
    log_info "🔍 개별 서비스 직접 응답 확인:"
    log_info "Active 서비스들:"
    curl -s "${CONSUL_ADDR}/v1/catalog/service/${SERVICE_NAME}?tag=active" | jq -r '.[] | "\(.ServiceAddress):\(.ServicePort) \(.ServiceMeta.version)"' 2>/dev/null | while read endpoint version; do
        if [ ! -z "$endpoint" ]; then
            local address_port=$(echo $endpoint | cut -d' ' -f1)
            local version_info=$(echo $endpoint | cut -d' ' -f2-)
            local response=$(curl -s -m 2 "http://$address_port/hello" 2>/dev/null | head -c 50)
            if [ $? -eq 0 ]; then
                log_info "  🔵 $address_port ($version_info): $response"
            else
                log_warning "  ❌ $address_port ($version_info): 응답 없음"
            fi
        fi
    done
    
    log_info "Standby 서비스들:"
    curl -s "${CONSUL_ADDR}/v1/catalog/service/${SERVICE_NAME}?tag=standby" | jq -r '.[] | "\(.ServiceAddress):\(.ServicePort) \(.ServiceMeta.version)"' 2>/dev/null | while read endpoint version; do
        if [ ! -z "$endpoint" ]; then
            local address_port=$(echo $endpoint | cut -d' ' -f1)
            local version_info=$(echo $endpoint | cut -d' ' -f2-)
            local response=$(curl -s -m 2 "http://$address_port/hello" 2>/dev/null | head -c 50)
            if [ $? -eq 0 ]; then
                log_info "  ⚪ $address_port ($version_info): $response"
            else
                log_warning "  ❌ $address_port ($version_info): 응답 없음"
            fi
        fi
    done
}

# 즉시 전환 (재배포 없이 태그만 변경)
instant_switch() {
    echo "========================================"
    echo "⚡ 즉시 전환 (Zero-Downtime Switch)"
    echo "========================================"
    
    log_zero "재배포 없이 태그만 변경하여 즉시 전환합니다!"
    
    # 1. 현재 상태 확인
    log_info "현재 서비스 상태 확인 중..."
    
    local active_services=$(curl -s "${CONSUL_ADDR}/v1/catalog/service/${SERVICE_NAME}?tag=active" | jq -r '.[].ServiceID' 2>/dev/null)
    local standby_services=$(curl -s "${CONSUL_ADDR}/v1/catalog/service/${SERVICE_NAME}?tag=standby" | jq -r '.[].ServiceID' 2>/dev/null)
    
    if [ -z "$active_services" ] || [ -z "$standby_services" ]; then
        log_error "Active 또는 Standby 서비스가 없습니다!"
        return 1
    fi
    
    # 2. Standby 헬스체크
    log_info "Standby 서비스 헬스체크 중..."
    local healthy_standby=0
    
    while read address port; do
        if [ ! -z "$address" ] && [ ! -z "$port" ]; then
            if check_service_health "$address" "$port"; then
                log_success "  ✅ $address:$port - 정상"
                ((healthy_standby++))
            else
                log_error "  ❌ $address:$port - 비정상"
                return 1
            fi
        fi
    done < <(curl -s "${CONSUL_ADDR}/v1/catalog/service/${SERVICE_NAME}?tag=standby" | jq -r '.[] | "\(.ServiceAddress) \(.ServicePort)"' 2>/dev/null)
    
    if [ $healthy_standby -lt 1 ]; then
        log_error "헬시한 Standby 서비스가 없습니다!"
        return 1
    fi
    
    # 3. 현재 응답 확인
    log_info "전환 전 응답 확인:"
    echo -n "  Current Active: "
    local before_response=$(curl -s http://localhost:8080/hello | head -c 50)
    echo "$before_response"
    
    # 4. 진정한 Zero-Downtime: 트래픽 라우팅만 변경
    log_magic "🎭 트래픽 라우팅 교환 중 (재배포 없음)..."
    
    # 현재 active/standby 서비스들의 포트 정보 수집
    local active_ports=$(curl -s "${CONSUL_ADDR}/v1/catalog/service/${SERVICE_NAME}?tag=active" | jq -r '.[] | "\(.ServiceAddress):\(.ServicePort)"' 2>/dev/null)
    local standby_ports=$(curl -s "${CONSUL_ADDR}/v1/catalog/service/${SERVICE_NAME}?tag=standby" | jq -r '.[] | "\(.ServiceAddress):\(.ServicePort)"' 2>/dev/null)
    
    log_info "현재 Active 포트들:"
    echo "$active_ports" | while read port; do
        [ ! -z "$port" ] && log_info "  🔵 $port"
    done
    
    log_info "현재 Standby 포트들:"
    echo "$standby_ports" | while read port; do
        [ ! -z "$port" ] && log_info "  ⚪ $port"
    done
    
    # 5. API Gateway/Load Balancer 설정 업데이트 (실제 환경에 맞게 수정 필요)
    log_magic "🌐 API Gateway 라우팅 규칙 업데이트 중..."
    
    # 임시로 Consul KV에 라우팅 정보 저장 (실제로는 API Gateway 설정 변경)
    echo "$standby_ports" | while read port; do
        if [ ! -z "$port" ]; then
            curl -s -X PUT "${CONSUL_ADDR}/v1/kv/routing/active-endpoints" -d "$port" > /dev/null
            log_info "  🔄 라우팅 타겟: $port (새로 활성화)"
        fi
    done
    
    log_warning "⚠️  실제 환경에서는 API Gateway/Load Balancer 설정을 변경해야 합니다."
    log_info "현재는 시뮬레이션으로 Consul 태그만 교환합니다..."
    
    # 6. 파일 백업
    cp "$NOMAD_JOB_FILE" "${NOMAD_JOB_FILE}.instant.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 7. 태그만 교환 (재배포 최소화)
    log_magic "🏷️  서비스 태그만 교환 중..."
    
    sed -i 's/tags = \["active",/tags = ["temp",/g' "$NOMAD_JOB_FILE"
    sed -i 's/tags = \["standby",/tags = ["active",/g' "$NOMAD_JOB_FILE"
    sed -i 's/tags = \["temp",/tags = ["standby",/g' "$NOMAD_JOB_FILE"
    
    # deployment_group도 변경
    sed -i 's/deployment_group = "active"/deployment_group = "temp"/g' "$NOMAD_JOB_FILE"
    sed -i 's/deployment_group = "standby"/deployment_group = "active"/g' "$NOMAD_JOB_FILE"
    sed -i 's/deployment_group = "temp"/deployment_group = "standby"/g' "$NOMAD_JOB_FILE"
    
    # 8. 태그 업데이트만 수행 (force-deploy로 최소 재시작)
    log_zero "서비스 태그 업데이트 중... (최소 재시작)"
    
    if nomad job run "$NOMAD_JOB_FILE"; then
        log_success "✅ 태그 교환 완료!"
        
        # 9. 짧은 안정화 대기
        log_info "서비스 안정화 대기 중... (3초)"
        sleep 3
        
        # 10. 전환 결과 확인
        echo ""
        log_magic "🧪 전환 결과 확인:"
        echo -n "  New Active: "
        local after_response=$(curl -s http://localhost:8080/hello | head -c 50)
        echo "$after_response"
        
        # 11. 실제 서비스별 응답 확인
        log_info "🔍 개별 서비스 응답 확인:"
        curl -s "${CONSUL_ADDR}/v1/catalog/service/${SERVICE_NAME}?tag=active" | jq -r '.[] | "\(.ServiceAddress):\(.ServicePort)"' 2>/dev/null | while read endpoint; do
            if [ ! -z "$endpoint" ]; then
                local response=$(curl -s -m 2 "http://$endpoint/hello" 2>/dev/null | head -c 50)
                log_info "  🔵 $endpoint: $response"
            fi
        done
        
        # 12. 전환 성공 여부 판단
        if [ "$before_response" != "$after_response" ]; then
            log_success "🎉 전환 성공! 응답이 변경되었습니다!"
            log_zero "Zero-Downtime 전환 완료!"
        else
            log_warning "⚠️ 응답이 동일합니다. 실제 트래픽 라우팅 확인이 필요합니다."
        fi
        
    else
        log_error "❌ 태그 업데이트 실패. 백업에서 복원합니다."
        cp "${NOMAD_JOB_FILE}.instant.backup."* "$NOMAD_JOB_FILE"
        return 1
    fi
    
    echo ""
    show_status
}

# 새 버전을 Standby로 배포 (Active는 건드리지 않음)
deploy_new_version() {
    local new_version="$1"
    
    if [ -z "$new_version" ]; then
        echo "사용법: deploy_new_version v3"
        return 1
    fi
    
    echo "========================================"
    echo "🚀 $new_version 버전을 Standby로 배포"
    echo "========================================"
    
    log_zero "Active 서비스는 건드리지 않고 Standby만 업데이트합니다!"
    
    # 1. 이미지 준비 확인
    read -p "🐳 $new_version 이미지 (kantapia14/hello-service:$new_version)가 준비되었나요? (y/N): " ready
    
    if [[ $ready != [yY] ]]; then
        log_info "$new_version 이미지를 먼저 준비해주세요:"
        echo ""
        echo "cd hello-service"
        echo "# HelloController.java 수정 ($new_version 메시지)"
        echo "docker build -t kantapia14/hello-service:$new_version ."
        echo "docker push kantapia14/hello-service:$new_version"
        return 1
    fi
    
    # 2. 백업
    cp "$NOMAD_JOB_FILE" "${NOMAD_JOB_FILE}.${new_version}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 3. Standby 그룹만 새 버전으로 변경
    log_magic "🎭 Standby 그룹을 $new_version으로 업데이트 중..."
    
    # standby-group의 이미지와 버전 변경 (awk를 사용한 안전한 방법)
    log_info "standby-group만 수정 중..."
    
    # awk를 사용하여 standby-group 내부만 정확히 수정
    awk -v new_ver="$new_version" '
    /group "standby-group"/ { in_standby = 1 }
    in_standby && /^  }$/ { in_standby = 0 }
    in_standby && /image = "kantapia14\/hello-service:v[0-9]+"/ {
        gsub(/v[0-9]+/, new_ver)
    }
    in_standby && /version = "v[0-9]+"/ {
        gsub(/"v[0-9]+"/, "\"" new_ver "\"")
    }
    { print }
    ' "$NOMAD_JOB_FILE" > "${NOMAD_JOB_FILE}.tmp" && mv "${NOMAD_JOB_FILE}.tmp" "$NOMAD_JOB_FILE"
    
    log_info "변경 사항:"
    log_info "standby-group 구성:"
    sed -n '/group "standby-group"/,/^  }$/p' "$NOMAD_JOB_FILE" | grep -E "(image|version)" | head -3
    
    # 4. Standby만 재배포
    log_zero "Standby 그룹만 재배포 중... (Active는 그대로!)"
    
    if nomad job run "$NOMAD_JOB_FILE"; then
        log_success "✅ $new_version Standby 배포 완료!"
        
        # 5. 새 버전 헬스체크
        log_info "$new_version 헬스체크 대기 중... (15초)"
        sleep 15
        
        # 6. 새 버전 테스트
        echo ""
        log_info "🧪 $new_version 테스트:"
        echo -n "  Standby ($new_version): "
        curl -s http://localhost:8080/standby | head -c 60
        echo ""
        
        log_success "🎉 $new_version이 Standby로 성공적으로 배포되었습니다!"
        log_info "이제 './$(basename $0) switch'로 $new_version을 Active로 전환할 수 있습니다!"
        
    else
        log_error "❌ $new_version 배포 실패. 백업에서 복원합니다."
        cp "${NOMAD_JOB_FILE}.${new_version}.backup."* "$NOMAD_JOB_FILE"
        return 1
    fi
}

# 메인 로직
case "$1" in
    "status")
        show_status
        ;;
    "switch")
        instant_switch
        ;;
    "deploy")
        if [ -z "$2" ]; then
            echo "사용법: $0 deploy v3"
            echo "예시: $0 deploy v4"
        else
            deploy_new_version "$2"
        fi
        ;;
    "diagnose"|"diag")
        echo "========================================"
        echo "🩺 서비스 진단 (Diagnose)"
        echo "========================================"
        
        log_info "🔍 모든 서비스 인스턴스 상세 확인:"
        curl -s "${CONSUL_ADDR}/v1/catalog/service/${SERVICE_NAME}" | jq -r '.[] | "\(.ServiceAddress):\(.ServicePort) \(.ServiceTags | join(",")) \(.ServiceMeta.version // "unknown")"' 2>/dev/null | while read endpoint tags version; do
            if [ ! -z "$endpoint" ]; then
                local address_port=$(echo $endpoint | cut -d' ' -f1)
                local tag_info=$(echo $endpoint | cut -d' ' -f2)
                local version_info=$(echo $endpoint | cut -d' ' -f3-)
                
                echo ""
                log_info "서비스: $address_port"
                log_info "  태그: $tag_info"
                log_info "  버전: $version_info"
                
                local response=$(curl -s -m 3 "http://$address_port/hello" 2>/dev/null)
                if [ $? -eq 0 ]; then
                    log_success "  응답: $response"
                else
                    log_error "  응답: 서비스 응답 없음"
                fi
            fi
        done
        
        echo ""
        log_info "🩺 v3 이미지 문제 진단:"
        log_warning "만약 v3가 'Zinedine Zidane'을 반환한다면 이미지 재빌드가 필요합니다:"
        echo "  cd hello-service"
        echo "  docker build -t kantapia14/hello-service:v3 ."
        echo "  docker push kantapia14/hello-service:v3"
        echo "  $0 deploy v3  # 재배포"
        ;;
    *)
        echo "========================================"
        echo "⚡ Zero-Downtime 배포 시스템"
        echo "========================================"
        echo "사용법:"
        echo "  $0 status           # 현재 상태 확인"
        echo "  $0 switch           # 즉시 전환 (트래픽 라우팅만 변경)"
        echo "  $0 deploy v3        # v3를 Standby로 배포"
        echo "  $0 deploy v4        # v4를 Standby로 배포"
        echo "  $0 diagnose         # 서비스 상세 진단"
        echo ""
        echo "🎯 진정한 무중단 배포 시나리오:"
        echo "1. $0 deploy v3      # v3를 Standby로 배포 (Active는 그대로!)"
        echo "2. $0 switch         # v3를 Active로 즉시 전환 (Zero-Downtime)"
        echo "3. 구버전은 자동으로 Standby가 됨"
        echo ""
        echo "🩺 문제 해결:"
        echo "- v3 응답이 잘못된 경우: $0 diagnose로 확인 후 이미지 재빌드"
        echo ""
        echo "현재 상태:"
        show_status
        ;;
esac 