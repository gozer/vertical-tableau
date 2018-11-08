provider "aws" {
  region = "${var.region}"
}

locals {
  instance_type     = "${var.environment == "prod" ? "r4.4xlarge" : "m4.xlarge"}"
  root_storage_size = "256"
  worker_count      = "${var.environment == "prod" ? 0 : 0}"

  # Sloooowwww bootup, give it 40 minutes
  health_check_grace_period = "${ 40 * 60 }"

  psql_port = "8060"
}

module "coordinator" {
  source            = "github.com/nubisproject/nubis-terraform//worker?ref=v2.3.1"
  region            = "${var.region}"
  environment       = "${var.environment}"
  account           = "${var.account}"
  service_name      = "${var.service_name}"
  purpose           = "coordinator"
  ami               = "${var.ami}"
  elb               = "${module.load_balancer.name},${module.load_balancer_psql.name}"
  ssh_key_file      = "${var.ssh_key_file}"
  ssh_key_name      = "${var.ssh_key_name}"
  nubis_sudo_groups = "${var.nubis_sudo_groups}"
  nubis_user_groups = "${var.nubis_user_groups}"

  security_group        = "${data.consul_keys.vertical.var.client_security_group_id},${aws_security_group.tableau.id}"
  security_group_custom = true

  health_check_type         = "EC2"
  health_check_grace_period = "${local.health_check_grace_period}"

  instance_type     = "${local.instance_type}"
  root_storage_size = "${local.root_storage_size}"
}

module "worker" {
  source            = "github.com/nubisproject/nubis-terraform//worker?ref=v2.3.1"
  region            = "${var.region}"
  environment       = "${var.environment}"
  account           = "${var.account}"
  service_name      = "${var.service_name}"
  purpose           = "worker"
  ami               = "${var.ami}"
  elb               = "${module.load_balancer.name}"
  ssh_key_file      = "${var.ssh_key_file}"
  ssh_key_name      = "${var.ssh_key_name}"
  nubis_sudo_groups = "${var.nubis_sudo_groups}"
  nubis_user_groups = "${var.nubis_user_groups}"

  security_group        = "${data.consul_keys.vertical.var.client_security_group_id},${aws_security_group.tableau.id}"
  security_group_custom = true

  health_check_type         = "EC2"
  health_check_grace_period = "${local.health_check_grace_period}"
  min_instances             = "${local.worker_count}"

  instance_type     = "${local.instance_type}"
  root_storage_size = "${local.root_storage_size}"

  tags = ["${list(
    map("key", "DependsOn", "value", "${module.coordinator.autoscaling_group}", "propagate_at_launch", false),
  )}"]
}

module "load_balancer" {
  source       = "github.com/nubisproject/nubis-terraform//load_balancer?ref=v2.3.1"
  region       = "${var.region}"
  environment  = "${var.environment}"
  account      = "${var.account}"
  service_name = "${var.service_name}"

  ssl_cert_name_prefix = "${var.service_name}"

  backend_port_http  = 81
  backend_port_https = 81

  health_check_target = "HTTP:81/health.html"
}

module "load_balancer_psql" {
  source       = "github.com/nubisproject/nubis-terraform//load_balancer?ref=v2.3.1"
  region       = "${var.region}"
  environment  = "${var.environment}"
  account      = "${var.account}"
  service_name = "${var.service_name}-psql"

  no_ssl_cert        = "1"
  backend_protocol   = "tcp"
  protocol_http      = "tcp"
  protocol_https     = "tcp"
  backend_port_http  = "${local.psql_port}"
  backend_port_https = "${local.psql_port}"

  health_check_target = "TCP:${local.psql_port}"
}

module "dns" {
  source       = "github.com/nubisproject/nubis-terraform//dns?ref=v2.3.1"
  region       = "${var.region}"
  environment  = "${var.environment}"
  account      = "${var.account}"
  service_name = "${var.service_name}"
  target       = "${module.load_balancer.address}"
}

module "dns_psql" {
  source       = "github.com/nubisproject/nubis-terraform//dns?ref=v2.3.1"
  region       = "${var.region}"
  environment  = "${var.environment}"
  account      = "${var.account}"
  service_name = "${var.service_name}"
  prefix       = "psql"
  target       = "${module.load_balancer_psql.address}"
}

module "backups" {
  source       = "github.com/nubisproject/nubis-terraform//bucket?ref=v2.3.1"
  region       = "${var.region}"
  environment  = "${var.environment}"
  account      = "${var.account}"
  service_name = "${var.service_name}"
  purpose      = "backups"
  role_cnt     = "2"
  role         = "${module.coordinator.role},${module.worker.role}"
}

module "mail" {
  source       = "github.com/nubisproject/nubis-terraform//mail?ref=v2.3.1"
  region       = "${var.region}"
  environment  = "${var.environment}"
  account      = "${var.account}"
  service_name = "${var.service_name}"
}

module "info" {
  source      = "github.com/nubisproject/nubis-terraform//info?ref=v2.3.1"
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
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    security_groups = [
      "${module.info.ssh_security_group}",
    ]
  }

  ingress {
    from_port = 81
    to_port   = 81
    protocol  = "tcp"
    self      = true

    security_groups = [
      "${module.load_balancer.source_security_group_id}",
    ]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    self      = true

    security_groups = [
      "${module.load_balancer.source_security_group_id}",
    ]
  }

  # Dynamic port range, yeah tableau
  ingress {
    self      = true
    from_port = 8000
    to_port   = 9000
    protocol  = "tcp"
  }

  # Licensing component ?!?!
  ingress {
    self      = true
    from_port = 27000
    to_port   = 27010
    protocol  = "tcp"
  }

  # Internal PostgreSQL database
  ingress {
    from_port = "${local.psql_port}"
    to_port   = "${local.psql_port}"
    protocol  = "tcp"
    self      = true

    security_groups = [
      "${module.load_balancer_psql.source_security_group_id}",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_user" "backups_files" {
  name = "${var.service_name}-${var.environment}-backups_files"
  path = "/applicaton/${var.service_name}/"
}

resource "aws_iam_access_key" "backups_files" {
  user = "${aws_iam_user.backups_files.name}"
}

resource "aws_iam_user_policy" "backups_files" {
  name = "${var.service_name}-${var.environment}-backups_files"
  user = "${aws_iam_user.backups_files.name}"

  policy = "${data.aws_iam_policy_document.backups_files.json}"
}

data "aws_iam_policy_document" "backups_files" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]

    resources = [
      "${module.backups.arn}",
      "${module.backups.arn}/*",
    ]
  }
}
