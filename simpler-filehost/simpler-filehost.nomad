job "simpler-filehost" {
  region = "global"
  datacenters = [ "nazrin" ]
  type = "service"
  group "svc" {
    count = 1
    network {
      mode = "bridge"
      port "http" {
        static = 8888
        to = 8000
      }
    }

    task "simpler-filehost" {
      driver = "docker"
      config {
        image = "natto17/simpler-filehost:latest"
        ports = ["http"]
        volumes = [ "/var/lib/files:/var/files", "/tmp:/tmp" ]
      }
      env {
        USER_URL = "https://f.weirdnatto.in"
        ROCKET_LIMITS = "{file=\"512MB\",data-form=\"512MB\"}"
        ROCKET_LOG_LEVEL = "debug"
      }
      resources {
        cpu    = 500
        memory = 256
      }
      service {
        name = "simpler-filehost"
        port = "http"
      }
    }
  }
}
