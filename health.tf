provider "aws" {}

resource "aws_instance" "test-instance" {
  ami           = "ami-41e0b93b"
  instance_type = "t2.micro"
  key_name      = "my-key"
}

resource "aws_cloudwatch_metric_alarm" "test_alarm" {
  alarm_name                = "test_alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "0"
  alarm_description         = "This metric monitors ec2 cpu utilization"
  insufficient_data_actions = []
  alarm_actions = [
    "${aws_sns_topic.cloudwatch-alarms.arn}"
  ]
  dimensions {
    InstanceId = "${aws_instance.test-instance.id}"
  }
}

resource "aws_sns_topic" "cloudwatch-alarms" {
  name = "cloudwatch-alarms"
}

resource "aws_sqs_queue" "test-queue" {
  name = "test-queue"
}

resource "aws_sns_topic_subscription" "cloudwatchsubscription" {
  topic_arn = "${aws_sns_topic.cloudwatch-alarms.arn}"
  protocol  = "sqs"
  endpoint  = "${aws_sqs_queue.test-queue.arn}"
}

resource "aws_iam_policy" "lambda_exec_policy" {
  name        = "lambda_exec_policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:DeleteMessage",
        "sqs:ReceiveMessage"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:sqs:*"
    },
    {
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Effect": "Allow",
      "Resource": "${aws_lambda_function.sqs_lambda.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "cloudwatch-to-kinesis-health-notifications" {
  name			= "cloudwatch-to-kinesis-health-notifications"
  policy		= <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kinesis:PutRecord"
      ],
      "Resource":"${aws_kinesis_stream.healthstatus-stream.arn}"
    }
  ]
}
EOF
}


resource "aws_iam_role" "cloudwatch_kinesis_role" {
  name = "cloudwatch_kinesis_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda-exec-attachment" {
  role = "${aws_iam_role.cloudwatch_kinesis_role.name}"
  policy_arn = "${aws_iam_policy.lambda_exec_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "kinesis-put-attachment" {
  role = "${aws_iam_role.cloudwatch_kinesis_role.name}"
  policy_arn = "${aws_iam_policy.cloudwatch-to-kinesis-health-notifications.arn}"
}

resource "aws_lambda_function" "sqs_lambda" {
  filename         = "sqs_lambda.zip"
  function_name    = "sqs_lambda"
  role             = "${aws_iam_role.cloudwatch_kinesis_role.arn}"
  handler          = "exports.handler"
  source_code_hash = "${base64sha256(file("sqs_lambda.zip"))}"
  runtime          = "nodejs4.3"

  environment {
    variables = {
      queueUrl = "${aws_sqs_queue.test-queue.id}"
    }
  }
}

resource "aws_cloudwatch_log_group" "healthnotifications-loggroup" {
  name			= "healthnotifications-loggroup"
}

resource "aws_kinesis_stream" "healthstatus-stream" {
  name			= "healthstatus-stream"
  shard_count		= 1
  retention_period	= 48
}

resource "aws_cloudwatch_log_subscription_filter" "health-kinesis-filter" {
  name			= "health-kinesis-filter"
  role_arn		= "${aws_iam_role.cloudwatch_kinesis_role.arn}"
  log_group_name	= "${aws_cloudwatch_log_group.healthnotifications-loggroup.name}"
  filter_pattern	= ""
  destination_arn	= "${aws_kinesis_stream.healthstatus-stream.arn}"
}


