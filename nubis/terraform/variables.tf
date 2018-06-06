variable "account" {}

variable "region" {
  default = "us-west-2"
}

variable "arena" {
  default = "core"
}

variable "environment" {
  default = "stage"
}

variable "service_name" {
  default = "tableau"
}

variable "ami" {}

variable "ssh_key_file" {
  default = ""
}

variable "ssh_key_name" {
  default = ""
}

variable "nubis_sudo_groups" {
  default = "nubis_global_admins"
}

variable "nubis_user_groups" {
  default = "team_dbeng"
}

variable "domain_name" {
  type = "map"

  default = {
    "stage" = "dataviz-nubis.allizom.org"
    "prod"  = "dataviz-nubis.mozilla.org"
  }
}
