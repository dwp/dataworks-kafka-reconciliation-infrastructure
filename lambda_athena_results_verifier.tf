resource "aws_lambda_function" "kafka_reconciliation_results_verifier_launcher" {
  filename      = "${var.kafka_reconciliation_results_verifier_zip["base_path"]}/dataworks-kafka-reconciliation-results-verifier-${var.kafka_reconciliation_results_verifier_zip["version"]}.zip"
  function_name = "kafka_reconciliation_results_verifier"
  role          = aws_iam_role.kafka_reconciliation_results_verifier_lambda_role.arn
  handler       = "event_handler.handler"
  runtime       = "python3.8"
  source_code_hash = filebase64sha256(
    format(
      "%s/dataworks-kafka-reconciliation-results-verifier-%s.zip",
      var.kafka_reconciliation_results_verifier_zip["base_path"],
      var.kafka_reconciliation_results_verifier_zip["version"]
    )
  )
  publish = false
  timeout = 60

  environment {
    variables = {
      ENVIRONMENT                = local.environment
      APPLICATION                = "kafka_reconciliation_results_verifier"
      LOG_LEVEL                  = "INFO"
      SNS_TOPIC                  = data.terraform_remote_state.security-tools.outputs.sns_topic_london_monitoring.arn

    }
  }

  tags = {
    Name = "kafka_reconciliation_results_verifier"
  }

  depends_on = [
  aws_cloudwatch_log_group.kafka_reconciliation_results_verifier_lambda
  ]
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.kafka_reconciliation_results_verifier_launcher.arn
  principal     = "s3.amazonaws.com"
  source_arn    = local.manifest_bucket_arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = local.manifest_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.kafka_reconciliation_results_verifier_launcher.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "${local.manifest_s3_output_location}/results/"
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_iam_role" "kafka_reconciliation_results_verifier_lambda_role" {
  name               = "kafka_reconciliation_results_verifier_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.kafka_reconciliation_results_verifier_lambda_assume_role.json
}

data "aws_iam_policy_document" "kafka_reconciliation_results_verifier_lambda_assume_role" {
  statement {
    sid     = "AthenaResultsVerifierLambdaAssumeRolePolicy"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "kafka_reconciliation_results_verifier_lambda" {
  statement {
    sid    = "AllowS3Access"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject"
    ]

    resources = [
      local.manifest_bucket_arn,
      "${local.manifest_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "AllowManifestKms"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]

    resources = [
      local.manifest_bucket_cmk,
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

resource "aws_iam_role_policy_attachment" "kafka_reconciliation_results_verifier_launcher_iam_policy_attachment" {
  role       = aws_iam_role.kafka_reconciliation_results_verifier_lambda_role.name
  policy_arn = aws_iam_policy.kafka_reconciliation_results_verifier_lambda.arn
}

resource "aws_iam_role_policy_attachment" "kafka_reconciliation_results_verifier_launcher_basic_execution_policy_attachment" {
  role       = aws_iam_role.kafka_reconciliation_results_verifier_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "kafka_reconciliation_results_verifier_lambda" {
  name        = "ResultsVerifierLambdaIAM"
  description = "Allow Athena Reconciliation Lambda access to interact with Batch & SNS"
  policy      = data.aws_iam_policy_document.kafka_reconciliation_results_verifier_lambda.json
}



resource "aws_cloudwatch_log_group" "kafka_reconciliation_results_verifier_lambda" {
  name              = "/aws/lambda/kafka_reconciliation_results_verifier"
  retention_in_days = "180"
}
