job "concourse-worker" { 
  region = "global"
  datacenters = [ "nazrin" ]
  type = "service"
  group "svc" {
    count = 1
    network {
      mode = "bridge"
    }
    vault {
      policies = [ "concourse-worker" ]
    }
    service {
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "concourse-tsa"
              local_bind_port = 2222
            }
          }
        }
      }
    }
    task "concourse" {
      driver = "docker"
      config {
        image = "rdclda/concourse:7.7.0"
        command = "worker"
        image_pull_timeout = "30m"
        privileged = true
        volumes = [ "/var/lib/nomad-st/concourse-worker:/work"]
        entrypoint = [ "dumb-init", "/work/entrypoint.sh" ]
      }
      resources {
        cpu    = 2048
        memory = 2048
      }
      template {
        data = <<EOF
{{ with secret (printf "kv/data/concourse/workers/%s" (env "node.unique.name") )}}{{ .Data.data.worker_key }}{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/worker_key"
      }
      template {
        data = <<EOF
{{ with secret "kv/data/concourse/keys" }}{{ .Data.data.tsa_host_key_pub }}{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/tsa_host_key.pub"
      }
      env {
        CONCOURSE_RUNTIME="containerd"
        CONCOURSE_TSA_PUBLIC_KEY="${NOMAD_SECRETS_DIR}/tsa_host_key.pub"
        CONCOURSE_TSA_WORKER_PRIVATE_KEY="${NOMAD_SECRETS_DIR}/worker_key"
        CONCOURSE_WORK_DIR="/work"
        CONCOURSE_TSA_HOST="${NOMAD_UPSTREAM_ADDR_concourse_tsa}"
 #       CONCOURSE_WORKER_BAGGAGECLAIM_DRIVER = "btrfs"
      }
    }
  }
}
