# Discover Consul settings from another deplyoment
module "consul_vertical" {
  source       = "github.com/nubisproject/nubis-terraform//consul?ref=v2.4.0"
  region       = "${var.region}"
  environment  = "${var.environment}"
  account      = "${var.account}"
  service_name = "vertical"
}

module "consul" {
  source       = "github.com/nubisproject/nubis-terraform//consul?ref=v2.4.0"
  region       = "${var.region}"
  environment  = "${var.environment}"
  account      = "${var.account}"
  service_name = "${var.service_name}"
}

# Configure our Consul provider, module can't do it for us
provider "consul" {
  version    = "~> 1.0"
  address    = "${module.consul_vertical.address}"
  scheme     = "${module.consul_vertical.scheme}"
  datacenter = "${module.consul_vertical.datacenter}"
}

# Publish our outputs into Consul for our application to consume
data "consul_keys" "vertical" {
  key {
    name = "client_security_group_id"
    path = "${module.consul_vertical.config_prefix}/clients/security-group-id"
  }
}

# Publish our outputs into Consul for our application to consume
resource "consul_keys" "config" {
  key {
    path   = "${module.consul.config_prefix}/S3/Bucket/Backups"
    value  = "${module.backups.name}"
    delete = true
  }

  key {
    path   = "${module.consul.config_prefix}/PublicHostname"
    value  = "${lookup(var.domain_name, var.environment, module.dns.fqdn)}"
    delete = true
  }

  key {
    path   = "${module.consul.config_prefix}/Users/BackupsFiles/AccessKey"
    value  = "${aws_iam_access_key.backups_files.id}"
    delete = true
  }

  key {
    path   = "${module.consul.config_prefix}/Users/BackupsFiles/SecretKey"
    value  = "${aws_iam_access_key.backups_files.secret}"
    delete = true
  }
}
