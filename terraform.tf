variable "cluster_name" {
  type = "string"
  default = "nginx"
}
variable "container_port" {
  type = "string"
  default = "80"
}
variable "host_port" {
  type = "string"
  default = "0"
}
variable "image" {
  type = "string"
  default = "nginx:alpine"
}
variable "vpc_id" {
  type = "string"
}
variable "public_subnets" {
  type = "list"
}
variable "security_groups" {
  type = "list"
}
variable "ami_id" {
  type = "string"
}
variable "max_instance_size" {
  type = "string"
  default = "2"
}
variable "min_instance_size" {
  type = "string"
  default = "1"
}
variable "desired_capacity" {
  type = "string"
  default = "1"
}
variable "key_name" {
  type = "string"
  default = "default"
}
variable "instance_type" {
  type = "string"
  default = "t2.micro"
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.cluster_name}"
}

data "aws_ecs_task_definition" "test" {
  task_definition = "${aws_ecs_task_definition.test.family}"
  depends_on      = ["aws_ecs_task_definition.test"]
}

resource "aws_ecs_task_definition" "test" {
  family = "test-family"

  container_definitions = <<DEFINITION
[
  {
"name": "web",
"image": "${var.image}",
"memory": 512,
"cpu": 128,
"essential": true,
"name": "nginx",
"PortMappings": [
{

    "containerPort": ${var.container_port},
    "hostPort": ${var.host_port}
}

]
}
]
DEFINITION
}

resource "aws_ecs_service" "test-ecs-service" {
  name            = "ecs-service"
  cluster         = "${aws_ecs_cluster.cluster.id}"
  task_definition = "${aws_ecs_task_definition.test.family}:${max("${aws_ecs_task_definition.test.revision}", "${data.aws_ecs_task_definition.test.revision}")}"
  desired_count   = 1
  iam_role        = "${aws_iam_role.ecs-service-role.name}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.test.id}"
    container_name   = "nginx"
    container_port   = "${var.container_port}"
  }
}

resource "aws_iam_role" "ecs-instance-role" {
  name               = "ecs-instance-role"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.ecs-instance-policy.json}"
}

data "aws_iam_policy_document" "ecs-instance-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment" {
  role       = "${aws_iam_role.ecs-instance-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs-instance-profile" {
  name = "ecs-instance-profile"
  path = "/"
  role = "${aws_iam_role.ecs-instance-role.id}"

  provisioner "local-exec" {
    command = "sleep 60"
  }
}

resource "aws_iam_role" "ecs-service-role" {
  name               = "ecs-service-role"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.ecs-service-policy.json}"
}

resource "aws_iam_role_policy_attachment" "ecs-service-role-attachment" {
  role       = "${aws_iam_role.ecs-service-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

data "aws_iam_policy_document" "ecs-service-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_alb_target_group" "test" {
  port     = "${var.container_port}"
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"
}

resource "aws_alb" "main" {
  subnets         = "${var.public_subnets}"
  security_groups = "${var.security_groups}"
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = "${aws_alb.main.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.test.id}"
    type             = "forward"
  }
}

resource "aws_launch_configuration" "ecs-launch-configuration" {
  name                 = "ecs-launch-configuration"
  image_id             = "${var.ami_id}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.ecs-instance-profile.id}"

  root_block_device {
    volume_type           = "standard"
    volume_size           = 30
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }

  security_groups             = "${var.security_groups}"
  associate_public_ip_address = "true"
  key_name                    = "${var.key_name}"
  user_data = <<EOF
#!/bin/bash
echo ECS_CLUSTER=${var.cluster_name} >> /etc/ecs/ecs.config
EOF
}

resource "aws_autoscaling_group" "ecs-autoscaling-group" {
  max_size             = "${var.max_instance_size}"
  min_size             = "${var.min_instance_size}"
  desired_capacity     = "${var.desired_capacity}"
  vpc_zone_identifier  = "${var.public_subnets}"
  launch_configuration = "${aws_launch_configuration.ecs-launch-configuration.name}"
  health_check_type    = "ELB"
}

resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = "${aws_autoscaling_group.ecs-autoscaling-group.id}"
  alb_target_group_arn   = "${aws_alb_target_group.test.id}"
}
