# Nginx Configurations

consul-template 기반 동적 nginx 설정 파일들입니다.

## 파일 설명

### hello-service.conf
현재 운영 중인 nginx 설정 파일입니다.
- `upstream hello_backend`: active 태그를 가진 서비스들
- `upstream hello_backend_standby`: standby 태그를 가진 서비스들

### hello-service.ctmpl
consul-template이 사용하는 템플릿 파일입니다.
- Consul 서비스 디스커버리를 통해 동적으로 nginx 설정 생성
- active/standby 태그에 따라 자동으로 upstream 구성

## 사용법

### 시스템에 설치
```bash
# nginx 설정 디렉토리로 복사
sudo cp nginx-configs/hello-service.conf /etc/nginx/conf.d/
sudo cp nginx-configs/hello-service.ctmpl /etc/nginx/conf.d/

# consul-template 실행 (별도 터미널)
consul-template -template="/etc/nginx/conf.d/hello-service.ctmpl:/etc/nginx/conf.d/hello-service.conf:service nginx reload"
```

### 엔드포인트

#### 메인 서비스
- `GET http://localhost:8080/` - active 서비스로 라우팅
- `GET http://localhost:8080/health` - 헬스체크 엔드포인트

#### 테스트용 
- `GET http://localhost:8080/standby` - standby 서비스로 라우팅
- `GET http://localhost:8080/consul-status` - 서비스 상태 JSON

### consul-template 동작 원리

1. Consul에서 `hello-service` 서비스들 조회
2. `active` 태그를 가진 서비스 → `hello_backend` upstream
3. `standby` 태그를 가진 서비스 → `hello_backend_standby` upstream  
4. 설정 파일 생성 후 nginx 리로드

## Zero-Downtime 배포 플로우

```
1. Nomad job 실행 (태그 변경)
   ↓
2. Consul 서비스 등록 갱신
   ↓  
3. consul-template이 변경 감지
   ↓
4. 새 nginx 설정 생성
   ↓
5. nginx-auto-reload.sh가 파일 변경 감지
   ↓
6. nginx reload 자동 실행
   ↓
7. 새 설정으로 트래픽 라우팅 ✅
```