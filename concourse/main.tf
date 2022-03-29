provider "nomad" {}
//Set everything via environment variables

resource "nomad_job" "concourse" {
  jobspec = file("./concourse.nomad")
  hcl2 {
    enabled = true
  }
}

resource "nomad_job" "concourse-worker" {
  jobspec = file("./concourse-worker.nomad")
  hcl2 {
    enabled = true
  }
}
