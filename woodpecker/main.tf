provider "nomad" {}
//Set everything via environment variables

resource "nomad_job" "woodpecker-server" {
  jobspec = file("./woodpecker-server.nomad")
  hcl2 {
    enabled = true
  }
}

resource "nomad_job" "woodpecker-agent" {
  jobspec = file("./woodpecker-agent.nomad")
  hcl2 {
    enabled = true
  }
}
