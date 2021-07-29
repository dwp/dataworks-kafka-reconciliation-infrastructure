resource "aws_cloudwatch_event_rule" "kafka_reconciliation_started" {
  name          = "kafka_reconciliation_started"
  description   = "Check when Kafka reconciliation task starts"
  event_pattern = <<EOF
{
  "source": [
    "aws.glue"
  ],
  "detail-type": [
    "Glue Job State Change"
  ],
  "detail": {
    "state": [
      "STARTING"
    ],
    "name": [
      "${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.job_name_combined}"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_metric_alarm" "kafka_reconciliation_started" {
  alarm_name                = "kafka_reconcilation_started"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "TriggeredRules"
  namespace                 = "AWS/Events"
  period                    = "60"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Monitoring when kafka reconciliation starts"
  insufficient_data_actions = []
  alarm_actions             = [data.terraform_remote_state.security-tools.outputs.sns_topic_london_monitoring.arn]
  dimensions = {
    RuleName = aws_cloudwatch_event_rule.kafka_reconciliation_started.name
  }
  tags = merge(
    local.common_tags,
    {
      Name              = "kafka_reconciliation_started",
      notification_type = "Information",
      severity          = "Critical"
    },
  )
}

resource "aws_cloudwatch_event_rule" "batch_coalescer_job_status_change" {
  name          = "batch_coalescer_job_status_change"
  description   = "Check when Kafka reconciliation task starts"
  event_pattern = <<EOF
{
  "source": [
    "aws.batch"
  ],
  "detail-type": [
    "Batch Job State Change"
  ],
  "detail": {
    "name": [
      "${local.batch_corporate_storage_coalescer_name}"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "batch_coalescer_job_status_change" {
  rule = aws_cloudwatch_event_rule.batch_coalescer_job_status_change.name
  arn  = aws_lambda_function.glue_launcher.arn
}

resource "aws_cloudwatch_event_rule" "batch_coalescer_long_running_job_status_change" {
  name          = "batch_coalescer_long_running_job_status_change"
  description   = "Check when Kafka reconciliation task starts"
  event_pattern = <<EOF
{
  "source": [
    "aws.batch"
  ],
  "detail-type": [
    "Batch Job State Change"
  ],
  "detail": {
    "name": [
      "${local.batch_corporate_storage_coalescer_long_running_name}"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "batch_coalescer_long_running_job_status_change" {
  rule = aws_cloudwatch_event_rule.batch_coalescer_long_running_job_status_change.name
  arn  = aws_lambda_function.glue_launcher.arn
}
