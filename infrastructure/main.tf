terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  backend "s3" {
    bucket = "dylanseidt-terraform-state"
    key    = "demospring.json"
    region = "us-west-2"
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "demospring-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []
}

module "alb_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"

  name   = "alb-sg"
  vpc_id = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
}

module "application_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name   = "application-sg"
  vpc_id = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 8080
      to_port                  = 8080
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
    },
  ]

  egress_rules = ["all-all"]
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name = "demospring-alb"

  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [module.alb_sg.security_group_id]

  target_groups = [
    {
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]
}

resource "aws_cloudwatch_log_group" "demo_spring" {
  name              = "/aws/ecs/demospring"
  retention_in_days = 1
}

resource "aws_iam_role" "execution_role" {
  name = "demospring-execution-role"

  assume_role_policy = data.aws_iam_policy_document.demo_spring_assume_role_policy.json

  inline_policy {
    name   = "demospring-execution-role-policy"
    policy = data.aws_iam_policy_document.demo_spring_execution_role_policy.json
  }
}

resource "aws_ecs_cluster" "demo_spring" {
  name = "demospring"
}

resource "aws_ecs_task_definition" "demo_spring" {
  family = "demospring"

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution_role.arn
  container_definitions = jsonencode([
    {
      name  = "demospring"
      image = "public.ecr.aws/aws-containers/hello-app-runner:latest"
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-group"         = aws_cloudwatch_log_group.demo_spring.name
          "awslogs-stream-prefix" = "/ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "demo_spring" {
  name            = "demospring"
  cluster         = aws_ecs_cluster.demo_spring.arn
  task_definition = aws_ecs_task_definition.demo_spring.arn
  launch_type     = "FARGATE"

  desired_count = 1

  network_configuration {
    subnets          = module.vpc.public_subnets
    assign_public_ip = true
    security_groups  = [module.application_sg.security_group_id]
  }

  load_balancer {
    target_group_arn = module.alb.target_group_arns[0]
    container_name   = "demospring"
    container_port   = 8080
  }
}
