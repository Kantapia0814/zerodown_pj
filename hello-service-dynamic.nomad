job "hello-service-dynamic" {
  datacenters = ["dc1"]

  # Active 그룹 (현재 트래픽 처리)
  group "active-group" {
    count = 2

    network {
      port "http" {
        to = 8080
        # 동적 포트 할당 - Nomad가 자동으로 할당
      }
    }

    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }

    task "hello-service" {
      driver = "docker"

      config {
        image = "kantapia14/hello-service:v1"
        ports = ["http"]
      }

      resources {
        cpu    = 500
        memory = 256
      }

      service {
        name = "hello-service"
        port = "http"
        tags = ["active", "v1", "production"]
        
        meta {
          version = "v1"
          deployment_group = "active"
        }

        check {
          type     = "http"
          path     = "/hello"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }

  # Standby 그룹 (대기 상태)
  group "standby-group" {
    count = 2

    network {
      port "http" {
        to = 8080
        # 동적 포트 할당
      }
    }

    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }

    task "hello-service" {
      driver = "docker"

      config {
        image = "kantapia14/hello-service:v2"
        ports = ["http"]
      }

      resources {
        cpu    = 500
        memory = 256
      }

      service {
        name = "hello-service"
        port = "http"
        tags = ["standby", "v2", "production"]
        
        meta {
          version = "v2"
          deployment_group = "standby"
        }

        check {
          type     = "http"
          path     = "/hello"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
} 