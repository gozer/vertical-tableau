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
    "stage" = "dataviz.allizom.org"
    "prod"  = "dataviz.mozilla.org"
  }
}

variable "psql_whitelist" {
  type = "list"

  default = [
    # MDC VPNs
    "63.245.208.132/32",
    "63.245.208.133/32",
    "63.245.210.132/32",
    "63.245.210.133/32",
    "63.245.222.198/32",

    #SCL3
    "63.245.214.169/32",

    #hala.data.mozaws.net
    "35.155.141.29/32",

    #sql.telemetry.mozilla.com
    "52.36.66.76/32",

    #John Miller's home
    "192.76.2.90/32",
    "69.249.207.121/32",
    "108.52.99.186/32",

    #Gozer's Home
    "96.22.236.163/32",
    "76.67.140.225/32",
    "67.68.121.229/32",

    #Vu's Home
    "24.130.202.158/32",
    "63.245.222.198/32",
  ]
}
