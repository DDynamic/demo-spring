data "aws_region" "current" {}

data "aws_availability_zones" "available_zones" {
  state = "available"
}

data "aws_iam_policy_document" "demo_spring_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "demo_spring_execution_role_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["${aws_cloudwatch_log_group.demo_spring.arn}:*"]
  }
}
