job "hello-service-separated" {
  datacenters = ["dc1"]

  # 서비스 v3-a (포트 10001)
  group "v3-group-a" {
    count = 1

    network {
      port "http" {
        to = 8080
        static = 10001
      }
    }

    task "hello-task-v3" {
      driver = "docker"

      config {
        image = "kantapia14/hello-service:v3"
        ports = ["http"]
      }

      resources {
        cpu    = 500
        memory = 256
      }

      service {
        name = "hello-service-v3"
        port = "http"
        tags = ["v3", "production", "instance-a"]
        check {
          type     = "http"
          path     = "/hello"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }

  # 서비스 v3-b (포트 10002)
  group "v3-group-b" {
    count = 1

    network {
      port "http" {
        to = 8080
        static = 10002
      }
    }

    task "hello-task-v3" {
      driver = "docker"

      config {
        image = "kantapia14/hello-service:v3"
        ports = ["http"]
      }

      resources {
        cpu    = 500
        memory = 256
      }

      service {
        name = "hello-service-v3"
        port = "http"
        tags = ["v3", "production", "instance-b"]
        check {
          type     = "http"
          path     = "/hello"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }

  # 서비스 v2-e (포트 10005)
  group "v2-group-e" {
    count = 1

    network {
      port "http" {
        to = 8080
        static = 10005
      }
    }

    task "hello-task-v2" {
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
        name = "hello-service-v2"
        port = "http"
        tags = ["v2", "staging", "instance-e"]
        check {
          type     = "http"
          path     = "/hello"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }

  # 서비스 v2-f (포트 10006)
  group "v2-group-f" {
    count = 1

    network {
      port "http" {
        to = 8080
        static = 10006
      }
    }

    task "hello-task-v2" {
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
        name = "hello-service-v2"
        port = "http"
        tags = ["v2", "staging", "instance-f"]
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