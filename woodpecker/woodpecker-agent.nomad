job "woodpecker-agent" { 
  region = "global"
  datacenters = [ "nazrin" ]
  type = "service"
  group "svc" {
    count = 1
    network {
      mode = "bridge"
    }

    vault {
      policies = [ "woodpecker-agent" ]
    }

    service {
      name = "woodpecker-grpc-agent"
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "woodpecker-grpc"
              local_bind_port = 9000
            }
          }
        }
      }
    }


    task "woodpecker" {
      driver = "docker"

      config {
        image = "woodpeckerci/woodpecker-agent:next"
        command = "agent"
        volumes = [ "/var/run/docker.sock:/var/run/docker.sock"]
      }

      resources {
        cpu    = 2048
        memory = 2048
      }

      template {
        data = <<EOF
WOODPECKER_LOG_LEVEL=trace
WOODPECKER_USERNAME=Marisa
WOODPECKER_AGENT_SECRET={{ with secret "kv/data/woodpecker/agent" }}{{ .Data.data.agent_secret }}{{ end }}
WOODPECKER_MAX_PROCS=2
WOODPECKER_SERVER={{ env "NOMAD_UPSTREAM_ADDR_woodpecker_grpc" }}
EOF
        env = true
        change_mode = "restart"
        destination = "${NOMAD_SECRETS_DIR}/data.env"
      }
    }
  }
}
