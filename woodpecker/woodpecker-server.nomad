job "woodpecker-server" {
  region = "global"
  datacenters = [ "nazrin" ]
  type = "service"

  group "svc" {
    count = 1
    network {
      mode = "bridge"
      port "db" {
        to = 5432
      }
      port "http" { 
        static = "6666"
        to = "8000"
      }
      port "grpc" {
        to = "9000"
      }
    }

    vault {
      policies = [ "woodpecker-server" ]
    }

    service {
      name = "woodpecker-grpc"
      port = "9000"
      connect {   
        sidecar_service {}   
      }
    }

    service {
      name = "woodpecker-db"
      port = "db"
    }

    service {
      name = "woodpecker-http"
      port = "http"
    }

    task "db" {
      template {
        data = <<EOF
{{ with secret "kv/data/woodpecker/db" }}{{ .Data.data.pass }}{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/db.pass"
      }
      driver = "docker"
      config {
        image = "postgres:alpine"
        ports = [ "db" ]
        volumes = [ "/var/lib/nomad-st/postgres-woodpecker:/var/lib/postgresql/data" ]
      }
      env {
        POSTGRES_USER     = "woodpecker"
        POSTGRES_PASSWORD_FILE="${NOMAD_SECRETS_DIR}/db.pass"
        POSTGRES_DB       = "woodpecker"
      }
      resources {
        cpu    = 250
        memory = 128
      }
    }
    task "woodpecker" {
      driver = "docker"
      config {
        image = "woodpeckerci/woodpecker-server:latest"
        command = "web"
        image_pull_timeout = "30m"
        ports = [ "http" ]
      }

      resources {
        cpu    = 250
        memory = 128
      }

      template {
        data = <<EOF
{{ with secret "kv/data/woodpecker/keys" }}
WOODPECKER_LOG_LEVEL=info
WOODPECKER_HOST={{ .Data.data.external_host }}
WOODPECKER_AGENT_SECRET={{ .Data.data.agent_secret }}
{{end}}

{{ with secret "kv/data/woodpecker/admin" }}
WOODPECKER_ADMIN={{ .Data.data.users }}
{{ end }}

WOODPECKER_OPEN=true
WOODPECKER_DATABASE_DRIVER=postgres

{{ with secret "kv/data/woodpecker/db" }}
WOODPECKER_DATABASE_DATASOURCE=postgres://woodpecker:{{ .Data.data.pass }}@localhost:{{ env "NOMAD_PORT_db" }}/woodpecker?sslmode=disable
{{ end }}

{{ with secret "kv/data/woodpecker/gitea" }}
 WOODPECKER_GITEA=true
WOODPECKER_GITEA_URL={{ .Data.data.url }}
WOODPECKER_GITEA_CLIENT={{ .Data.data.client }}
WOODPECKER_GITEA_SECRET={{ .Data.data.secret }}
{{ end }}
EOF
        env = true
        change_mode = "restart"
        destination = "${NOMAD_SECRETS_DIR}/data.env"
      }
    }
  }
}
