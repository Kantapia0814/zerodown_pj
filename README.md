# 🚀 Zero-Downtime 배포 시스템

[![Nomad](https://img.shields.io/badge/Nomad-00CA8E?style=flat&logo=nomad&logoColor=white)](https://www.nomadproject.io/)
[![Consul](https://img.shields.io/badge/Consul-F24C53?style=flat&logo=consul&logoColor=white)](https://www.consul.io/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://docker.com/)
[![Nginx](https://img.shields.io/badge/Nginx-009639?style=flat&logo=nginx&logoColor=white)](https://nginx.org/)

**진정한 무중단(Zero-Downtime) 배포**를 구현한 마이크로서비스 오케스트레이션 시스템입니다.

## 📋 프로젝트 개요

- **🎯 목표**: 0.00% 다운타임으로 서비스 버전 전환
- **🏗️ 아키텍처**: Nomad + Consul + Docker + Nginx
- **⚡ 성능**: 1,000 RPS, 평균 응답시간 1ms 미만
- **🔄 배포 방식**: Blue-Green 배포 with 동적 라우팅

## 🎬 데모

```bash
# 부하 테스트 중 무중단 전환
k6 run k6-quick-test.js &  # 1000 RPS 부하
./toggle_version_consul_true_zero_downtime.sh switch  # 즉시 전환

# 결과: 0% 에러율, 300,001개 요청 모두 성공 ✅
```

---

## 🛠️ 시스템 요구사항

### **운영체제**
- **Linux** (Ubuntu 20.04+ 권장)
- **Windows** (WSL2 필수)
- **macOS** (10.15+ 권장)

### **하드웨어**
- **CPU**: 2코어 이상
- **메모리**: 4GB 이상
- **디스크**: 10GB 이상 여유공간

---

## 📦 필수 도구 설치

### **1. Docker 설치**

#### Ubuntu/Linux:
```bash
# Docker 설치
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 사용자 권한 추가
sudo usermod -aG docker $USER

# 확인
docker --version
```

#### Windows:
1. [Docker Desktop](https://www.docker.com/products/docker-desktop) 다운로드 및 설치
2. WSL2 활성화 필요

#### macOS:
1. [Docker Desktop](https://www.docker.com/products/docker-desktop) 다운로드 및 설치

### **2. Nomad 설치**

```bash
# Linux/macOS
curl -LO https://releases.hashicorp.com/nomad/1.6.1/nomad_1.6.1_linux_amd64.zip
unzip nomad_1.6.1_linux_amd64.zip
sudo mv nomad /usr/local/bin/

# 확인
nomad version
```

### **3. Consul 설치**

```bash
# Linux/macOS
curl -LO https://releases.hashicorp.com/consul/1.16.1/consul_1.16.1_linux_amd64.zip
unzip consul_1.16.1_linux_amd64.zip
sudo mv consul /usr/local/bin/

# 확인
consul version
```

### **4. Nginx 설치**

#### Ubuntu/Linux:
```bash
sudo apt update
sudo apt install nginx -y
```

#### macOS:
```bash
brew install nginx
```

### **5. k6 설치 (성능 테스트용)**

```bash
# Linux
curl -LO https://github.com/grafana/k6/releases/download/v0.46.0/k6-v0.46.0-linux-amd64.tar.gz
tar -xzf k6-v0.46.0-linux-amd64.tar.gz
sudo mv k6-v0.46.0-linux-amd64/k6 /usr/local/bin/

# macOS
brew install k6

# 확인
k6 version
```

### **6. 기타 도구**

```bash
# jq (JSON 파싱용)
sudo apt install jq -y  # Ubuntu
brew install jq         # macOS

# curl (이미 설치되어 있을 가능성 높음)
curl --version
```

---

## 🚀 프로젝트 설정

### **1. 저장소 클론**

```bash
git clone https://github.com/your-username/kantapia_pj.git
cd kantapia_pj
```

### **2. IP 주소 설정**

```bash
# 현재 IP 주소 확인
ip addr show  # Linux
ipconfig      # Windows

# 예시: 172.17.187.181
```

**⚠️ 중요**: 모든 설정 파일에서 `172.17.187.181`을 실제 IP로 변경해야 합니다.

### **3. 설정 파일 수정**

```bash
# Nomad 설정
sed -i 's/172.17.187.181/YOUR_IP/g' hello-service-dynamic.nomad

# 스크립트 설정 (필요시)
# toggle_version_consul_true_zero_downtime.sh 파일에서 IP 확인
```

### **4. 실행 권한 부여**

```bash
chmod +x toggle_version_consul_true_zero_downtime.sh
chmod +x scripts/*.sh
chmod +x *.sh
```

### **5. Hello Service 이미지 준비**

```bash
cd hello-service

# Docker 이미지 빌드
docker build -t kantapia14/hello-service:v1 .
docker build -t kantapia14/hello-service:v2 .

# (선택) Docker Hub에 푸시
docker push kantapia14/hello-service:v1
docker push kantapia14/hello-service:v2

cd ..
```

---

## 🎯 시스템 실행

### **단계 1: 인프라 서비스 시작**

#### **터미널 1 - Consul 서버**
```bash
consul agent -dev -bind=YOUR_IP -client=0.0.0.0

# 확인
curl http://localhost:8500/v1/status/leader
```

#### **터미널 2 - Nomad 서버**
```bash
nomad agent -dev -bind=YOUR_IP

# 확인
nomad status
```

### **단계 2: Load Balancer 설정**

#### **Nginx 시작**
```bash
sudo systemctl start nginx
sudo systemctl enable nginx
```

#### **터미널 3 - Nginx 자동 리로드**
```bash
./scripts/nginx-auto-reload.sh
```

#### **터미널 4 - Consul Template**
```bash
# Nginx 설정 파일을 시스템에 복사 (최초 1회)
sudo cp nginx-configs/hello-service.conf /etc/nginx/conf.d/
sudo cp nginx-configs/hello-service.ctmpl /etc/nginx/conf.d/

# Consul Template 실행 (동적 설정 생성)
consul-template \
  -template="/etc/nginx/conf.d/hello-service.ctmpl:/etc/nginx/conf.d/hello-service.conf:echo 'Config updated'" \
  -consul-addr="127.0.0.1:8500" &
```

### **단계 3: 애플리케이션 배포**

#### **터미널 5 - 메인 작업용**
```bash
# Nomad 주소 설정
export NOMAD_ADDR="http://YOUR_IP:4646"

# 서비스 배포
nomad job run hello-service-dynamic.nomad

# 서비스 등록 대기 (중요!)
echo "서비스 등록 대기 중..."
sleep 30
```

---

## ✅ 시스템 확인

### **1. 기본 상태 확인**

```bash
# 전체 시스템 상태
./toggle_version_consul_true_zero_downtime.sh status

# API 테스트
curl http://localhost:8080/hello    # Active 서비스
curl http://localhost:8080/standby  # Standby 서비스
```

### **2. 웹 UI 접속**

- **Consul UI**: http://localhost:8500
- **Nomad UI**: http://localhost:4646

---

## 🔧 구성 요소 상세

### **Nginx 설정 (nginx-configs/)**

#### **파일 구성**:
- **`hello-service.conf`**: 현재 운영 중인 nginx 설정 파일
  - `upstream hello_backend`: active 태그를 가진 서비스들
  - `upstream hello_backend_standby`: standby 태그를 가진 서비스들

- **`hello-service.ctmpl`**: consul-template용 템플릿 파일
  - Consul 서비스 디스커버리를 통해 동적으로 nginx 설정 생성
  - active/standby 태그에 따라 자동으로 upstream 구성

#### **엔드포인트**:
- `GET http://localhost:8080/hello` - active 서비스로 라우팅
- `GET http://localhost:8080/standby` - standby 서비스로 라우팅  
- `GET http://localhost:8080/health` - 헬스체크 엔드포인트
- `GET http://localhost:8080/consul-status` - 서비스 상태 JSON

#### **Zero-Downtime 배포 플로우**:
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

### **자동화 스크립트 (scripts/)**

#### **nginx-auto-reload.sh**:
nginx 설정 파일 변경을 자동으로 감지하여 nginx를 리로드하는 스크립트입니다.

**기능**:
- `/etc/nginx/conf.d/hello-service.conf` 파일 변경 감지
- 3초마다 파일 수정 시간 체크
- 변경 감지 시 nginx 설정 테스트 후 리로드
- 안전한 리로드 (설정 오류 시 리로드 하지 않음)

**사용법**:
```bash
# 실행 권한 추가
chmod +x scripts/nginx-auto-reload.sh

# 백그라운드 실행
./scripts/nginx-auto-reload.sh &

# 또는 시스템에 설치
sudo cp scripts/nginx-auto-reload.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/nginx-auto-reload.sh
```

**로그 예시**:
```
Nginx auto-reload watcher started...
Mon Aug  5 09:40:00 KST 2025: Config file changed, testing and reloading nginx...
Mon Aug  5 09:40:00 KST 2025: Nginx reloaded successfully
```

---

## 🧪 테스트 및 사용법

### **1. 성능 테스트**

```bash
# 기본 부하 테스트 (5분, 1000 RPS)
k6 run k6-quick-test.js

# 결과 예시:
# ✓ checks_succeeded: 100.00% (600,002 out of 600,002)
# ✓ http_req_failed: 0.00% (0 out of 300,001)
```

### **2. 무중단 버전 전환**

```bash
# 현재 상태 확인
./toggle_version_consul_true_zero_downtime.sh status

# 즉시 전환 (Active ↔ Standby)
./toggle_version_consul_true_zero_downtime.sh switch

# 새 버전 배포 (Standby로)
./toggle_version_consul_true_zero_downtime.sh deploy v3
```

### **3. 무중단 배포 + 부하 테스트 동시 실행**

```bash
# 부하 테스트 백그라운드 실행
k6 run k6-quick-test.js &

# 즉시 버전 전환
./toggle_version_consul_true_zero_downtime.sh switch

# 결과: 0% 에러율로 무중단 전환 성공! 🎉
```

---

## 🔧 트러블슈팅

### **자주 발생하는 문제들**

#### **1. Docker 이미지 없음 오류**
```bash
# 해결: 이미지 빌드 또는 다운로드
cd hello-service
docker build -t kantapia14/hello-service:v1 .
```

#### **2. Consul 연결 실패**
```bash
# 확인: Consul 실행 상태
curl http://localhost:8500/v1/status/leader

# 해결: Consul 재시작
pkill consul
consul agent -dev -bind=YOUR_IP -client=0.0.0.0
```

#### **3. Nomad 서비스 등록 안됨**
```bash
# 확인: Nomad 작업 상태
nomad job status hello-service-dynamic

# 해결: 서비스 재배포
nomad job stop hello-service-dynamic
nomad job run hello-service-dynamic.nomad
```

#### **4. Nginx 설정 오류**
```bash
# 확인: Nginx 설정 테스트
sudo nginx -t

# 해결: 설정 리로드
sudo systemctl reload nginx
```

### **로그 확인**

```bash
# Nomad 로그
nomad alloc logs <allocation-id>

# Consul 로그
consul monitor

# Docker 컨테이너 로그
docker logs <container-id>
```

---

## 📊 성능 지표

- **처리량**: 997 RPS
- **평균 응답시간**: 962.71µs
- **95% 응답시간**: 1.53ms 이하
- **에러율**: 0.00%
- **가용성**: 100% (무중단 전환)

---

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📝 라이선스

이 프로젝트는 MIT 라이선스 하에 있습니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.

---

## 🙏 감사의 말

- [HashiCorp Nomad](https://www.nomadproject.io/)
- [HashiCorp Consul](https://www.consul.io/)
- [Docker](https://www.docker.com/)
- [Nginx](https://nginx.org/)
- [k6](https://k6.io/)

---

## 📞 문의

프로젝트에 대한 질문이나 제안사항이 있으시면 이슈를 생성해 주세요.

**🎯 Happy Zero-Downtime Deploying!** 🚀