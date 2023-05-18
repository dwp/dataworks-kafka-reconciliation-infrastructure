resource "aws_cloudwatch_event_rule" "kafka_reconciliation_started" {
  name          = "kafka_reconciliation_started"
  description   = "Check when Kafka reconciliation task starts"
  event_pattern = <<EOF
{
  "source": [
    "aws.glue"
  ],
  "detail-type": [
    "Glue Job Run Status"
  ],
  "detail": {
    "state": [
      "RUNNING"
    ],
    "jobName": [
      "${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.job_name_combined}"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_metric_alarm" "kafka_reconciliation_started" {
  alarm_name                = "kafka_reconciliation_started"
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
  tags = {
    Name              = "kafka_reconciliation_started",
    notification_type = "Information",
    severity          = "Critical"
  }
}

resource "aws_cloudwatch_event_rule" "manifest_glue_job_failed" {
  name          = "manifest_glue_job_failed"
  description   = "Check when manifest glue job fails"
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
      "FAILED",
      "TIMEOUT",
      "STOPPED"
    ],
    "jobName": [
      "${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.job_name_combined}"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "retry_glue_job_on_failure" {
  arn  = aws_lambda_function.glue_launcher.arn
  rule = aws_cloudwatch_event_rule.manifest_glue_job_failed.id

  input = <<EOF
{
    "detail" : {
        "jobName": "retry_glue_job_on_failure",
        "jobQueue": "aws_cloudwatch_event_target",
        "status": "SUCCEEDED",
        "ignoreBatchChecks": "true"
    }
}
EOF
}

resource "aws_cloudwatch_metric_alarm" "manifest_glue_job_failed" {
  alarm_name                = "manifest_glue_job_failed"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "TriggeredRules"
  namespace                 = "AWS/Events"
  period                    = "60"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Monitoring when manifest glue job fails"
  insufficient_data_actions = []
  alarm_actions             = [data.terraform_remote_state.security-tools.outputs.sns_topic_london_monitoring.arn]
  dimensions = {
    RuleName = aws_cloudwatch_event_rule.manifest_glue_job_failed.name
  }
  tags = {
    Name              = "manifest_glue_job_failed",
    notification_type = "Error",
    severity          = "High"
  }
}

resource "aws_cloudwatch_event_rule" "manifest_glue_job_completed" {
  name        = "manifest_glue_job_completed"
  description = "Events when manifest glue job is completed"

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
      "SUCCEEDED"
    ],
    "jobName": [
      "${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.job_name_combined}"
    ]
  }
}
EOF

  tags = {
    Name = "manifest_glue_job_completed"
  }
}

resource "aws_cloudwatch_event_target" "manifest_glue_job_completed" {
  rule      = aws_cloudwatch_event_rule.manifest_glue_job_completed.name
  target_id = "SendSNSMessageToHandlerLambda"
  arn       = aws_sns_topic.kafka_reconciliation_topic.arn
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
    "jobQueue": [
      "${local.batch_corporate_storage_coalescer}"
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
    "jobQueue": [
      "${local.batch_corporate_storage_coalescer_long_running}"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "batch_coalescer_long_running_job_status_change" {
  rule = aws_cloudwatch_event_rule.batch_coalescer_long_running_job_status_change.name
  arn  = aws_lambda_function.glue_launcher.arn
}

resource "aws_cloudwatch_log_group" "kafka_reconciliation_ecs_cluster" {
  name              = local.cw_k2hb_recon_trimmer_agent_log_group_name
  retention_in_days = 180
  tags              = local.common_tags
}