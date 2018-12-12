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
  elb               = "${module.load_balancer.name}"
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

module "dns" {
  source       = "github.com/nubisproject/nubis-terraform//dns?ref=v2.3.1"
  region       = "${var.region}"
  environment  = "${var.environment}"
  account      = "${var.account}"
  service_name = "${var.service_name}"
  target       = "${module.load_balancer.address}"
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

    cidr_blocks = [
      "${concat(var.psql_whitelist, formatlist("%s/32",flatten(data.aws_network_interface.psql.*.private_ips)))}",
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

resource "aws_lb" "psql" {
  name                             = "${var.service_name}-psql-${var.environment}"
  internal                         = false
  load_balancer_type               = "network"
  enable_cross_zone_load_balancing = true

  #XXX: Turn into a dynamic
  subnet_mapping {
    subnet_id     = "${element(split(",",module.info.public_subnets),0)}"
    allocation_id = "${element(aws_eip.psql.*.id, 0)}"
  }

  subnet_mapping {
    subnet_id     = "${element(split(",",module.info.public_subnets),1)}"
    allocation_id = "${element(aws_eip.psql.*.id, 1)}"
  }

  subnet_mapping {
    subnet_id     = "${element(split(",",module.info.public_subnets),2)}"
    allocation_id = "${element(aws_eip.psql.*.id, 2)}"
  }

  tags = {
    Name        = "${var.service_name}-psql-${var.environment}"
    Region      = "${var.region}"
    Environment = "${var.environment}"
  }
}

resource "aws_lb_target_group" "psql" {
  name     = "${var.service_name}-psql-${var.environment}"
  port     = 5433
  protocol = "TCP"
  vpc_id   = "${module.info.vpc_id}"

  tags = {
    Name        = "${var.service_name}-psql-${var.environment}"
    Region      = "${var.region}"
    Environment = "${var.environment}"
  }
}

resource "aws_autoscaling_attachment" "worker" {
  autoscaling_group_name = "${module.worker.autoscaling_group}"
  alb_target_group_arn   = "${aws_lb_target_group.psql.arn}"
}

resource "aws_lb_listener" "public" {
  load_balancer_arn = "${aws_lb.psql.arn}"
  port              = "${local.psql_port}"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.psql.arn}"
  }
}

data "aws_network_interface" "psql" {
  count = "${length(split(",",module.info.public_subnets))}"

  filter = {
    name   = "description"
    values = ["ELB ${aws_lb.psql.arn_suffix}"]
  }

  filter = {
    name   = "subnet-id"
    values = ["${element(split(",",module.info.public_subnets), count.index)}"]
  }
}

resource "aws_eip" "psql" {
  count = "${length(split(",",module.info.public_subnets))}"
  vpc   = true

  tags = {
    Name        = "${var.service_name}-psql-${var.environment}-az${count.index}"
    Region      = "${var.region}"
    Environment = "${var.environment}"
  }
}

module "dns_psql" {
  source       = "github.com/nubisproject/nubis-terraform//dns?ref=v2.3.1"
  region       = "${var.region}"
  environment  = "${var.environment}"
  account      = "${var.account}"
  service_name = "${var.service_name}"
  prefix       = "psql"
  target       = "${aws_lb.psql.dns_name}"
}
