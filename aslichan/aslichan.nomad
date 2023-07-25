job "aslichan" {
  region = "global"
  datacenters = [ "nazrin" ]
  type = "service"
  group "svc" {
    count = 1
    network {
      mode = "bridge"
      port "http" {
        static = 4004
        to = 8080
      }
      port "db" {
        to = 3306
      }
    }
    vault {
      policies = [ "vichan" ]
    }
    task "db" {
      driver = "docker"
      config {
        image = "mysql/mysql-server:8.0"
        ports = ["db"]
        volumes = [ "/var/lib/nomad-st/aslichan/mysql:/var/lib/mysql",
                    "/var/lib/nomad-st/aslichan/mysqld.cnf:/etc/mysql/my.cnf"]
        ulimit {
          nofile = "262144:262144"
        }
      }
      env {
        MYSQL_USER = "aslichan"
        MYSQL_DATABASE = "aslichan"
        MYSQL_PASSWORD = "aslichan"
        MYSQL_ROOT_PASSWORD = "asliroot"
      }
      resources {
        cpu = "512"
        memory = "256"
      }
    }
    task "app" {
      driver = "docker"
      config {
        image = "natto17/vichan:latest"
        volumes = [ "/var/lib/nomad-st/aslichan/app:/app",
                    "/tmp:/tmp"]
        ports = ["http"]
      }
    }
    task "torgate" {
      driver = "docker"
      config {
        image = "natto17/vichan:torgate"
        volumes = [ "/var/lib/nomad-st/aslichan/aslitor:/var/lib/tor/aslitor" ]
      }
      env {
        TORGATE_ENDPOINT = "127.0.0.1:${NOMAD_PORT_http}"
        TORGATE_DIRNAME = "aslitor"
      }
    }
  }
}
