# Scripts Directory

## nginx-auto-reload.sh

nginx 설정 파일 변경을 자동으로 감지하여 nginx를 리로드하는 스크립트입니다.

### 사용법

#### Linux/WSL에서 사용 시:
```bash
# 실행 권한 추가
chmod +x scripts/nginx-auto-reload.sh

# 백그라운드 실행
./scripts/nginx-auto-reload.sh &

# 또는 시스템에 설치
sudo cp scripts/nginx-auto-reload.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/nginx-auto-reload.sh
```

### 기능
- `/etc/nginx/conf.d/hello-service.conf` 파일 변경 감지
- 3초마다 파일 수정 시간 체크
- 변경 감지 시 nginx 설정 테스트 후 리로드
- 안전한 리로드 (설정 오류 시 리로드 하지 않음)

### 로그
스크립트 실행 시 다음과 같은 로그가 출력됩니다:
```
Nginx auto-reload watcher started...
Mon Aug  5 09:40:00 KST 2025: Config file changed, testing and reloading nginx...
Mon Aug  5 09:40:00 KST 2025: Nginx reloaded successfully
```