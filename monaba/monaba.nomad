job "monaba" {
  region = "global"
  datacenters = [ "nazrin" ]
  type = "service"
  group "svc" {
    count = 1
    network {
      mode = "bridge"
      port "http" {
        static = 4004
        to = 80
      }
      port "db" {
        to = 5432
      }
    }
    vault {
      policies = [ "monaba" ]
    }
    task "db" {
      driver = "docker"
      config {
        image = "postgres:alpine"
        ports = ["db"]
        hostname = "db"
        volumes = [ "/var/lib/nomad-st/monaba/postgres:/var/lib/postgresql/data" ]
        network_mode = "monabanet"
      }
      template {
        data = <<EOF
{{with secret "kv/data/monaba"}}
POSTGRES_USER=monaba
POSTGRES_DB=monaba
POSTGRES_PASSWORD={{.Data.data.dbpass}}
{{end}}
EOF
        env = true
        destination = "${NOMAD_SECRETS_DIR}/data.env"
      }
      resources {
        cpu    = 200
        memory = 128
      }
    }
    task "app" {
      driver = "docker"
      config {
        image = "docker.pkg.github.com/ahushh/monaba/app:latest"
        hostname = "app"
        volumes = [ "/var/lib/nomad-st/monaba/upload:/opt/monaba/upload",
                    "/var/lib/nomad-st/monaba/banners:/opt/monaba/static/banners",
                    "/var/lib/nomad-st/monaba/settings.yml:/var/settings.yml"
        ]
        network_mode = "monabanet"
      }
      template {
        data = <<EOF
{{with secret "kv/data/monaba"}}
PGUSER=monaba
PGDATABASE=monaba
PGPASS={{.Data.data.dbpass}}
{{end}}
PGHOST_APP=db
SEARCH_HOST=search
MAX_UPLOAD_SIZE=50
EOF
        env = true
        destination = "${NOMAD_SECRETS_DIR}/data.env"
      }
    }
    task "webserver" {
      driver = "docker"
      config {
        image = "docker.pkg.github.com/ahushh/monaba/webserver:latest"
        ports = ["http"]
        volumes = [ "/var/lib/nomad-st/monaba/upload:/opt/monaba/upload" ]
        network_mode = "monabanet"
      }
    }
    task "search" {
      driver = "docker"
      config {
        image = "docker.pkg.github.com/ahushh/monaba/search:latest"
        hostname = "search"
        volumes = [ "/var/lib/nomad-st/monaba/searchdata:/var/lib/sphinxsearch/data" ]
        network_mode = "monabanet"
      }
    }
  }
}
