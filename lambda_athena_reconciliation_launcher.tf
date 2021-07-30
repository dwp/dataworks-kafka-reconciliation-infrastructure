resource "aws_lambda_function" "athena_reconciliation_launcher" {
  filename      = "${var.athena_reconciliation_launcher_zip["base_path"]}/glue-launcher-${var.athena_reconciliation_launcher_zip["version"]}.zip"
  function_name = "athena_reconciliation_launcher"
  role          = aws_iam_role.athena_reconciliation_launcher_lambda_role.arn
  handler       = "athena_reconciliation_launcher.handler"
  runtime       = "python3.7"
  source_code_hash = filebase64sha256(
    format(
      "%s/glue-launcher-%s.zip",
      var.athena_reconciliation_launcher_zip["base_path"],
      var.athena_reconciliation_launcher_zip["version"]
    )
  )
  publish = false
  timeout = 60

  environment {
    variables = {
      ENVIRONMENT                                              = local.environment
      APPLICATION                                              = "athena_reconciliation_launcher"
      LOG_LEVEL                                                = "INFO"
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
    sid     = "GlueLauncherLambdaAssumeRolePolicy"
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
    sid    = "AllowBatchListJobs"
    effect = "Allow"
    actions = [
      "batch:ListJobs",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid    = "AllowGlueJobStart"
    effect = "Allow"
    actions = [
      "glue:StartJobRun",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid    = "AllowAthenaAccess"
    effect = "Allow"
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
    ]
    resources = [
      "*"
    ]
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
  name        = "GlueLauncherLambdaIAM"
  description = "Allow Glue Launcher Lambda to view Batch Jobs and kick off Glue jobs"
  policy      = data.aws_iam_policy_document.athena_reconciliation_launcher_lambda.json
}

resource "aws_lambda_permission" "batch_coalescer_job_status_change" {
  statement_id  = "AllowExecution_batch_coalescer_job_status_change"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.athena_reconciliation_launcher.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.batch_coalescer_job_status_change.arn
}

resource "aws_lambda_permission" "batch_coalescer_long_running_job_status_change" {
  statement_id  = "AllowExecution_batch_coalescer_long_running_job_status_change"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.athena_reconciliation_launcher.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.batch_coalescer_long_running_job_status_change.arn
}

resource "aws_cloudwatch_log_group" "athena_reconciliation_launcher_lambda" {
  name              = "/aws/lambda/athena_reconciliation_launcher"
  retention_in_days = "180"
}
