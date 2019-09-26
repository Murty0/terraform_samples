module "vpc" {
  source             = "git@github.com:owner/terraform-modules.git//modules/vpc?ref=v2.23.1"
  name               = "${var.name}"
  env                = "${var.env}"
  vpc_name           = "${var.name}-${var.env}"
  cidr               = "xxxx"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  public_subnets = [
    {
      az   = "us-east-1a"
      name = "public-${var.name}-${var.env}-1a"
      cidr = "xxxx"
    },
    {
      az   = "us-east-1b"
      name = "public-${var.name}-${var.env}-1b"
      cidr = "xxxx"
    },
  ]

  nat_gw_subnets_cidr = [
    "xxxx",
    "xxxx",
  ]

  natted_subnets = [
    {
      az            = "us-east-1a"
      name          = "natted-${var.name}-${var.env}-1a"
      cidr          = "xxxx"
    },
    {
      az            = "us-east-1b"
      name          = "natted-${var.name}-${var.env}-1b"
      cidr          = "xxxx"
    },
  ]
}

resource "aws_route53_record" "1Password_owner" {
  name    = "1password.owner.com"
  type    = "A"
  zone_id = "${data.aws_route53_zone.owner.zone_id}"

  alias {
    name                   = "${module.1Password_op_scim_elb.dns_name}"
    zone_id                = "${module.1Password_op_scim_elb.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "1Password_cert" {
  domain_name       = "1password.owner.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.1Password_cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.1Password_cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.owner.id}"
  records = ["${aws_acm_certificate.1Password_cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = "${aws_acm_certificate.1Password_cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]
}

module "1Password_op_scim_sg_public" {
  source = "git@github.com:owner/terraform-modules.git"

  vpc_id = "${module.vpc.vpc_id}"
}

module "1Password_op_scim_elb" {
  source = "git@github.com:owner/terraform-modules.git"

  app_name            = "1Password"
  env                 = "${var.env}"
  fleet_name          = "op-scim"
  elb_subnets         = ["${module.vpc.public_subnets}"]
  elb_security_groups = ["${module.1Password_op_scim_sg_public.id}"]
  bucket_name         = "${module.s3_loadbalancerlogs_owner.id}"

  backend_port        = "80"
  backend_protocol    = "http"
  ssl_certificate_id  = "${aws_acm_certificate_validation.cert.certificate_arn}"
  cloudwatch_notifier = ["arn:aws:sns:us-east-1:123456789:SCIM"]
  health_check_target = "TCP:80"
}

resource "aws_security_group" "1Password_op_scim_sg_private" {
  name        = "1Password-${var.env}-sg"
  description = "1Password op-scim sg"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${module.1Password_op_scim_sg_public.id}"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${module.bastion.sg_id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "1Password_op_scim_asg" {
  source               = "git@github.com:owner/terraform-modules.git"
  app_name             = "1Password"
  fleet_name           = "op-scim"
  env                  = "${var.env}"
  ami                  = "${data.aws_ami.ami.id}"
  min_size             = 2
  max_size             = 2
  instance_type        = "${var.instance_type}"
  security_groups      = ["${aws_security_group.1Password_op_scim_sg_private.id}"]
  iam_instance_profile = "${module.1password_op_scim_app_iam_role.name}"
  vpc_subnets_ids      = ["${module.vpc.natted_subnets}"]
  load_balancers       = ["${module.1Password_op_scim_elb.id}"]
  ssh_key_name         = ""
  health_check_type    = "ELB"

  user_data = <<EOF
#!/bin/bash

chkconfig docker on

mkdir -p /etc/docker

#turn on experimental flag for docker, otherwise unable to view docker service logs
echo '{"experimental": true}' > /etc/docker/daemon.json

#restart docker service, and experimental should be on this time
service docker restart

#create docker-compose.yml
mkdir /op-scim
touch /op-scim/docker-compose.yml

/bin/echo "version: '3.1'

services:
    scim:
        image: 1password/scim:v1.0
        deploy:
          replicas: 1
          restart_policy:
            condition: on-failure
        networks:
          - op-scim
        ports:
          - "80:8080"
        secrets:
          - scimsession
        entrypoint: ["/op-scim/op-scim", "--port=8080",  "--session=/run/secrets/scimsession"]
    redis:
        image: redis:latest
        deploy:
          replicas: 1
          restart_policy:
            condition: on-failure
        networks:
          - op-scim

networks:
  op-scim:

secrets:
  scimsession:
    external: true" > /op-scim/docker-compose.yml

#create scimsession
scimsession=`aws secretsmanager get-secret-value --secret-id arn:aws:secretsmanager:us-east-1:8123456789:secret:1password/scimsession-tjQgSy --region us-east-1 --output text --query SecretBinary | base64 --decode`

touch /op-scim/scimsession && chmod u+x /op-scim/scimsession
/bin/echo "$scimsession" > /op-scim/scimsession

#initiate the swarm
docker swarm init

#create docker swarm secret
cat /op-scim/scimsession | docker secret create scimsession -

#deploy the docker service/stack
docker stack deploy -c /op-scim/docker-compose.yml op-scim

#send logs to cloudwatch
touch /op-scim/fetch_scim_logs.sh && chmod u+x /op-scim/fetch_scim_logs.sh

/bin/echo "#!/bin/bash
docker service logs -f op-scim_scim >> /var/log/docker_scim.log" > /op-scim/fetch_scim_logs.sh
bash ./op-scim/fetch_scim_logs.sh &

/bin/echo "[general]
state_file = /var/lib/awslogs/agent-state
use_gzip_http_content_encoding = false
[logstream1]
log_group_name = /opscim/var/log/cloud-init-output
log_stream_name = {instance_id}
datetime_format = %Y-%m-%dT%H:%M:%S%z
time_zone = UTC
file = /var/log/cloud-init-output.log
file_fingerprint_lines = 1
multi_line_start_pattern = ^[^\s]
initial_position = start_of_file
encoding = utf_8
buffer_duration = 5000
batch_count = 1000
batch_size = 32768

[logstream2]
log_group_name = /opscim/var/log/docker_scim
log_stream_name = {instance_id}
datetime_format = %Y-%m-%dT%H:%M:%S%z
time_zone = UTC
file = /var/log/docker_scim.log
file_fingerprint_lines = 1
multi_line_start_pattern = ^[^\s]
initial_position = start_of_file
encoding = utf_8
buffer_duration = 5000
batch_count = 1000
batch_size = 32768" > /etc/awslogs/awslogs.conf

service awslogs restart

service datadog-agent start

metadata=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document)
region=$(echo $metadata | jq -r '.region')
instance_id=$(echo $metadata | jq -r .instanceId)

aws --region $region ec2 create-tags --resources $instance_id --tags Key=Name,Value=1Password-${var.env}
EOF
}
