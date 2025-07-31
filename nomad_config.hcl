# Nomad 서버 및 클라이언트 설정
# 단일 노드에서 서버와 클라이언트를 모두 실행

# 데이터 디렉토리 (절대 경로)
data_dir = "/tmp/nomad-data"

# 서버 설정
server {
  enabled = true
  bootstrap_expect = 1
}

# 클라이언트 설정
client {
  enabled = true
  servers = ["127.0.0.1:4647"]
  # consul {
  #   address = "127.0.0.1:8500"
  #   auto_advertise = true
  #   client_auto_join = true
  # }
}

# 네트워크 주소 설정
addresses {
  http = "127.0.0.1"
  rpc  = "127.0.0.1"
  serf = "127.0.0.1"
}

# advertise 주소 설정
advertise {
  http = "127.0.0.1"
  rpc  = "127.0.0.1"
  serf = "127.0.0.1"
}

# 포트 설정 (기본 포트 사용)
ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}

# 로깅 설정
log_level = "INFO"

# 텔레메트리 설정
telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}

# ACL 설정 (개발 환경에서는 비활성화)
acl {
  enabled = false
}

# TLS 설정 (개발 환경에서는 비활성화)
tls {
  http = false
  rpc  = false
} 