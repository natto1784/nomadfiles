provider "nomad" {}
//Set everything via environment variables

resource "nomad_job" "singh3" {
  jobspec = file("./singh3.nomad")
  purge_on_destroy = true
  hcl2 {
    enabled = true
  }
}
