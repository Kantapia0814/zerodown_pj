job "hello-service" {
  datacenters = ["dc1"]

  group "hello-group" {
    count = 3

    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    network {
      port "http" {
        to = 8080
      }
    }

    task "hello-task" {
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