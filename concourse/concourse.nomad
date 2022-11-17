job "concourse" {
  region = "global"
  datacenters = [ "nazrin" ]
  type = "service"
  update { 
    health_check = "checks"   
    min_healthy_time  = "30s"   
    healthy_deadline  = "15m"
    progress_deadline = "30m"
  }
  group "svc" {
    count = 1
    network {
      mode = "bridge"
       port "db" {
        to = 5432
      }
      port "http" { 
        static = "6666"
        to = "8080"
      }
      port "tsa" {
        to = "2222"
      }
    }
    vault {
      policies = [ "concourse-ci" ]
    }
    service {
      name = "concourse-db"
      port = "db"
    }
    service {
      name = "concourse-http"
      port = "http"
    }
    service {
      name = "concourse-tsa"
      port = "2222"
      connect {   
        sidecar_service {}   
      }
    }
    task "db" {
      template {
        data = <<EOF
{{with secret "kv/data/concourse/db"}}{{.Data.data.pass}}{{end}}
EOF
        destination = "${NOMAD_SECRETS_DIR}/cc-db.pass"
      }
      driver = "docker"
      config {
        image = "postgres:alpine"
        ports = ["db"]
        volumes = [ "/var/lib/nomad-st/postgres-concourse:/var/lib/postgresql/data" ]
      }
      env {
        POSTGRES_USER     = "concourse"
        POSTGRES_PASSWORD_FILE="${NOMAD_SECRETS_DIR}/cc-db.pass"
        POSTGRES_DB       = "concourse"
      }
    }
    task "concourse" {
      driver = "docker"
      config {
        image = "rdclda/concourse:7.8.3"
        command = "web"
        image_pull_timeout = "30m"
        ports = ["http", "tsa" ]
      }
      template {
        data = <<EOF
{{ with secret "kv/data/concourse/keys" }}
{{ .Data.data.session_signing_key }}
{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/session_signing_key"
      }

      template {
        data = <<EOF
{{ with secret "kv/data/concourse/keys" }}
{{ .Data.data.tsa_host_key }}
{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/tsa_host_key"
      }


      template {
        data = <<EOF
{{ range secrets "kv/metadata/concourse/workers/" }}
{{ with secret (printf "kv/data/concourse/workers/%s" .) }}{{ .Data.data.worker_key_pub }}
{{ end }}
{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/authorized_worker_keys"
        change_mode = "restart"
      }
      template {
        data = <<EOF
{{ with secret "kv/data/concourse/keys" }}
CONCOURSE_ADD_LOCAL_USER={{ .Data.data.local_username }}:{{ .Data.data.local_userpass }}
CONCOURSE_MAIN_TEAM_LOCAL_USER={{ .Data.data.local_username }}
{{end}}
CONCOURSE_SESSION_SIGNING_KEY={{ env "NOMAD_SECRETS_DIR" }}/session_signing_key
CONCOURSE_TSA_HOST_KEY={{ env "NOMAD_SECRETS_DIR" }}/tsa_host_key
CONCOURSE_TSA_AUTHORIZED_KEYS={{ env "NOMAD_SECRETS_DIR" }}/authorized_worker_keys
CONCOURSE_POSTGRES_HOST=localhost
CONCOURSE_POSTGRES_PORT={{ env "NOMAD_PORT_db" }}
CONCOURSE_POSTGRES_USER=concourse
CONCOURSE_POSTGRES_DATABASE=concourse
CONCOURSE_EXTERNAL_URL=https://ci.weirdnatto.in
{{ with secret "kv/data/concourse/db" }}CONCOURSE_POSTGRES_PASSWORD={{ .Data.data.pass }}{{end}}
CONCOURSE_VAULT_URL=https://vault.weirdnatto.in
CONCOURSE_VAULT_PATH_PREFIX=/kv/concourse
{{ with secret "kv/data/concourse/vault" }}CONCOURSE_VAULT_CLIENT_TOKEN={{ .Data.data.token }}{{end}}
EOF
        env = true
        change_mode = "restart"
        destination = "${NOMAD_SECRETS_DIR}/data.env"
      }
    }
  }
}
