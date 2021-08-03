resource "aws_lambda_function" "athena_reconciliation_launcher" {
  filename      = "${var.athena_reconciliation_launcher_zip["base_path"]}/athena-reconciliation-launcher-${var.athena_reconciliation_launcher_zip["version"]}.zip"
  function_name = "athena_reconciliation_launcher"
  role          = aws_iam_role.athena_reconciliation_launcher_lambda_role.arn
  handler       = "batch_job_launcher.handler"
  runtime       = "python3.7"
  source_code_hash = filebase64sha256(
    format(
      "%s/athena-reconciliation-launcher-%s.zip",
      var.athena_reconciliation_launcher_zip["base_path"],
      var.athena_reconciliation_launcher_zip["version"]
    )
  )
  publish = false
  timeout = 60

  environment {
    variables = {
      ENVIRONMENT                = local.environment
      APPLICATION                = "athena_reconciliation_launcher"
      LOG_LEVEL                  = "INFO"
      MONITORING_SNS_TOPIC       = data.terraform_remote_state.security-tools.outputs.sns_topic_london_monitoring.name
      MONITORING_ERRORS_SEVERITY = "High"
      MONITORING_ERRORS_TYPE     = "Warning"
      SLACK_CHANNEL_OVERRIDE     = "dataworks-critical-errors"
      BATCH_JOB_NAME             = local.kafka_reconciliation_application_name
      BATCH_JOB_QUEUE            = aws_batch_job_queue.kafka_reconciliation.name
      BATCH_JOB_DEFINITION_NAME  = aws_batch_job_definition.kafka_reconciliation.name
      BATCH_PARAMETERS_JSON = jsonencode({
        "manifest_prefix" : local.manifest_s3_output_location,
        "manifest_s3_bucket" : local.manifest_bucket_id
      })
    }
  }

  tags = {
    Name = "athena_reconciliation_launcher"
  }

  depends_on = [
  aws_cloudwatch_log_group.athena_reconciliation_launcher_lambda]
}

resource "aws_iam_role" "athena_reconciliation_launcher_lambda_role" {
  name               = "athena_reconciliation_launcher_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.athena_reconciliation_launcher_lambda_assume_role.json
}

data "aws_iam_policy_document" "athena_reconciliation_launcher_lambda_assume_role" {
  statement {
    sid     = "AthenaReconciliationLambdaAssumeRolePolicy"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "athena_reconciliation_launcher_lambda" {
  statement {
    sid    = "AllowBatchSubmitJobs"
    effect = "Allow"
    actions = [
      "batch:SubmitJob",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid    = "AllowGlueJobStart"
    effect = "Allow"
    actions = [
      "sns:Publish",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid     = "PublishToMonitoringSnsTopic"
    effect  = "Allow"
    actions = ["SNS:Publish"]
    resources = [
      data.terraform_remote_state.security-tools.outputs.sns_topic_london_monitoring.arn,
    ]
  }

  statement {
    sid       = "AllowLogging"
    effect    = "Allow"
    actions   = ["logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "athena_reconciliation_launcher_iam_policy_attachment" {
  role       = aws_iam_role.athena_reconciliation_launcher_lambda_role.name
  policy_arn = aws_iam_policy.athena_reconciliation_launcher_lambda.arn
}

resource "aws_iam_role_policy_attachment" "athena_reconciliation_launcher_basic_execution_policy_attachment" {
  role       = aws_iam_role.athena_reconciliation_launcher_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "athena_reconciliation_launcher_lambda" {
  name        = "AthenaReconciliationLambdaIAM"
  description = "Allow Athena Reconciliation Lambda access to interact with Batch & SNS"
  policy      = data.aws_iam_policy_document.athena_reconciliation_launcher_lambda.json
}

resource "aws_sns_topic_subscription" "kafka_reconciliation_topic" {
  topic_arn = aws_sns_topic.kafka_reconciliation_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.athena_reconciliation_launcher.arn
}

resource "aws_lambda_permission" "kafka_reconciliation_topic" {
  statement_id  = "BatchJobAllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.athena_reconciliation_launcher.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.kafka_reconciliation_topic.arn
}

resource "aws_cloudwatch_log_group" "athena_reconciliation_launcher_lambda" {
  name              = "/aws/lambda/athena_reconciliation_launcher"
  retention_in_days = "180"
}
