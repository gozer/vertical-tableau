locals {
  instance_type     = "m4.xlarge"
  root_storage_size = "256"
}

module "coordinator" {
  source            = "github.com/gozer/nubis-terraform//worker?ref=issue%2F160%2Faz"
  region            = "${var.region}"
  environment       = "${var.environment}"
  account           = "${var.account}"
  service_name      = "${var.service_name}"
  purpose           = "${var.service_name}-coordinator"
  ami               = "${var.ami}"
  elb               = "${module.load_balancer.name}"
  ssh_key_file      = "${var.ssh_key_file}"
  ssh_key_name      = "${var.ssh_key_name}"
  nubis_sudo_groups = "${var.nubis_sudo_groups}"
  nubis_user_groups = "${var.nubis_user_groups}"

  security_group        = "${data.consul_keys.vertical.var.client_security_group_id},${aws_security_group.tableau.id}"
  security_group_custom = true

  health_check_type = "EC2"

  tags = ["${list(
    map("key", "Tableau", "value", "Coordinator", "propagate_at_launch", true),
  )}"]

  instance_type     = "${local.instance_type}"
  root_storage_size = "${local.root_storage_size}"
}

module "worker" {
  source            = "github.com/gozer/nubis-terraform//worker?ref=issue%2F160%2Faz"
  region            = "${var.region}"
  environment       = "${var.environment}"
  account           = "${var.account}"
  service_name      = "${var.service_name}"
  purpose           = "${var.service_name}-worker"
  ami               = "${var.ami}"
  ssh_key_file      = "${var.ssh_key_file}"
  ssh_key_name      = "${var.ssh_key_name}"
  nubis_sudo_groups = "${var.nubis_sudo_groups}"
  nubis_user_groups = "${var.nubis_user_groups}"

  security_group        = "${data.consul_keys.vertical.var.client_security_group_id},${aws_security_group.tableau.id}"
  security_group_custom = true

  health_check_type = "EC2"
  min_instances     = 2

  tags = ["${list(
    map("key", "Tableau", "value", "Worker", "propagate_at_launch", true),
  )}"]

  instance_type     = "${local.instance_type}"
  root_storage_size = "${local.root_storage_size}"
}

module "load_balancer" {
  source       = "github.com/nubisproject/nubis-terraform//load_balancer?ref=v2.1.0"
  region       = "${var.region}"
  environment  = "${var.environment}"
  account      = "${var.account}"
  service_name = "${var.service_name}"
}

module "dns" {
  source       = "github.com/nubisproject/nubis-terraform//dns?ref=v2.1.0"
  region       = "${var.region}"
  environment  = "${var.environment}"
  account      = "${var.account}"
  service_name = "${var.service_name}"
  target       = "${module.load_balancer.address}"
}

provider "aws" {
  region = "${var.region}"
}

module "info" {
  source      = "github.com/nubisproject/nubis-terraform//info?ref=v2.1.0"
  region      = "${var.region}"
  environment = "${var.environment}"
  account     = "${var.account}"
}

resource "aws_security_group" "tableau" {
  name_prefix = "${var.service_name}-${var.arena}-${var.environment}-"

  vpc_id = "${module.info.vpc_id}"

  tags = {
    Name        = "${var.service_name}-${var.arena}-${var.environment}"
    Arena       = "${var.arena}"
    Region      = "${var.region}"
    Environment = "${var.environment}"
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    security_groups = [
      "${module.load_balancer.source_security_group_id}",
    ]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    security_groups = [
      "${module.load_balancer.source_security_group_id}",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
