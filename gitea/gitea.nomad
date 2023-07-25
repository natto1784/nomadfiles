job "nattotea" {
  region = "global"
  datacenters = [ "nazrin" ]
  type = "service"
  group "svc" {
    count = 1
    network {
      mode = "bridge"
      port "http" {
        static = 5001
        to = 3000
      }
      port "ssh_pass" {
        static = 202
        to = 22
      }
      port "db" {
        to = 5432
      }
    }
    service {
      name = "gitea-http"
      port = "http"
    } 
    vault {
      policies = [ "giteapolicy" ]
    }
    task "app" {
      template {
        data = <<EOF
APP_NAME=Natto Tea
RUN_MODE=prod
SSH_DOMAIN=git.weirdnatto.in
ROOT_URL=https://git.weirdnatto.in/
SSH_PORT=22
SSH_LISTEN_PORT=22
USER_UID=1002
USER_GID=1002
GITEA__database__DB_TYPE=postgres
GITEA__database__NAME=gitea
GITEA__database__USER=gitea
GITEA__database__HOST=localhost:{{ env "NOMAD_PORT_db" }}
{{with secret "kv/data/gitea"}}
GITEA__database__PASSWD_FILE={{.Data.data.dbpass}}
GITEA__mailer__ENABLED=true
GITEA__mailer__FROM={{.Data.data.mailer}}
GITEA__mailer__TYPE=smtp
GITEA__mailer__HOST={{.Data.data.mailhost}}
GITEA__mailer__IS_TLS_ENABLED=true
GITEA__mailer__USER={{.Data.data.mailer}}
GITEA__mailer__PASSWD={{.Data.data.mailerpass}}
GITEA__service__REGISTER_EMAIL_CONFIRM=true
GITEA__oauth2_client__REGISTER_EMAIL_CONFIRM=true
GITEA__actions__ENABLED=true
{{end}}
EOF
        destination = "${NOMAD_SECRETS_DIR}/data.env"
        env = true
      }
      driver = "docker"
      config {
        image = "gitea/gitea:latest"
        ports = [ "http", "ssh_pass" ]
        volumes = [ "/var/lib/nomad-st/gitea:/data" ]
      }
    }
    task "runner" {
      driver = "docker"
      config {
        image = "gitea/act_runner:latest"
        volumes = [
		    "/var/lib/nomad-st/mazdoor/data:/data",
		    "/var/lib/nomad-st/mazdoor/config.yaml:/config.yaml",
                    "/var/run/docker.sock:/var/run/docker.sock" 
                  ]
      }
      template {
        data = <<EOF
GITEA_INSTANCE_URL=http://localhost:{{env "NOMAD_PORT_http" }}
GITEA_RUNNER_NAME=mazdoor
{{with secret "kv/data/gitea"}}
GITEA_RUNNER_REGISTRATION_TOKEN={{.Data.data.runnertoken}}
{{end}}
EOF
        destination = "${NOMAD_SECRETS_DIR}/data.env"
        env = true
      }
    }
    task "db" {
      template {
        data = <<EOF
  {{with secret "kv/data/gitea"}}{{.Data.data.dbpass}}{{end}}
  EOF
        destination = "${NOMAD_SECRETS_DIR}/gitea_db.pass"
      }
      driver = "docker"
      config {
        image = "postgres:14-alpine"
        ports = ["db"]
        volumes = [ "/var/lib/nomad-st/postgres-gitea:/var/lib/postgresql/data" ]
      }
      resources {
        memory = 100
        cpu = 128
      }
      env {
        POSTGRES_USER     = "gitea"
        POSTGRES_PASSWORD_FILE="${NOMAD_SECRETS_DIR}/gitea_db.pass"
        POSTGRES_DB       = "gitea"
      }
      service {
        name = "gitea-db"
        port = "db"
      }
    }
  }
}
