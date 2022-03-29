provider "nomad" {}
//Set everything via environment variables

resource "nomad_job" "gitea" {
  jobspec = file("./gitea.nomad")
  hcl2 {
    enabled = true
  }
}
