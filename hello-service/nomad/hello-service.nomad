job "hello-service" {
  datacenters = ["dc1"]

  group "hello-group" {
    count = 3

    task "hello-task" {
      driver = "docker"

      config {
        image = "kantapia14/hello-service:v2"
        port_map {
          http = 8080
        }
      }

      resources {
        cpu    = 500
        memory = 256
        network {
          port "http" {
            // 동적 포트 할당 - Nomad가 자동으로 사용 가능한 포트를 할당
          }
        }
      }

      service {
        name = "hello-service"
        port = "http"
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