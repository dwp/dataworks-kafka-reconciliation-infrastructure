resource "aws_lambda_function" "glue_launcher" {
  filename      = "${var.glue_launcher_zip["base_path"]}/glue-launcher-${var.glue_launcher_zip["version"]}.zip"
  function_name = "glue_launcher"
  role          = aws_iam_role.glue_launcher_lambda_role.arn
  handler       = "glue_launcher.handler"
  runtime       = "python3.7"
  source_code_hash = filebase64sha256(
    format(
      "%s/glue-launcher-%s.zip",
      var.glue_launcher_zip["base_path"],
      var.glue_launcher_zip["version"]
    )
  )
  publish = false
  timeout = 60

  environment {
    variables = {
      ENVIRONMENT                                              = local.environment
      APPLICATION                                              = "glue_launcher"
      LOG_LEVEL                                                = "INFO"
      JOB_QUEUE_DEPENDENCIES_ARN_LIST                          = "${local.batch_corporate_storage_coalescer},${local.batch_corporate_storage_coalescer_long_running}"
      ETL_GLUE_JOB_NAME                                        = local.manifest_etl_combined_name
      MANIFEST_COUNTS_PARQUET_TABLE_NAME                       = local.manifest_counts_parquet_table_name
      MANIFEST_MISMATCHED_TIMESTAMPS_TABLE_NAME                = local.manifest_mismatched_timestamps_table_name
      MANIFEST_MISSING_IMPORTS_TABLE_NAME                      = local.missing_imports_parquet_table_name
      MANIFEST_MISSING_EXPORTS_TABLE_NAME                      = local.missing_exports_parquet_table_name
      MANIFEST_S3_INPUT_LOCATION_IMPORT                        = data.terraform_remote_state.aws-ingestion.outputs.manifest_comparison_parameters.streaming_folder_main
      MANIFEST_S3_INPUT_LOCATION_EXPORT                        = "${data.terraform_remote_state.aws-internal-compute.outputs.manifest_s3_prefixes.export}/${local.manifest_snapshot_type}"
      MANIFEST_COMPARISON_CUT_OFF_DATE_START                   = "PREVIOUS_DAY_MIDNIGHT" # Set an 'YYYY-MM-DD HH:MM:SS' to define. Else lambda will calculate date if empty or set to "PREVIOUS_DAY_MIDNIGHT"
      MANIFEST_COMPARISON_CUT_OFF_DATE_END                     = "TODAY_MIDNIGHT"        # Set an 'YYYY-MM-DD HH:MM:SS' to define. Else lambda will calculate date if empty or set to "TODAY_MIDNIGHT"
      MANIFEST_COMPARISON_MARGIN_OF_ERROR_MINUTES              = "0"
      MANIFEST_COMPARISON_SNAPSHOT_TYPE                        = local.manifest_snapshot_type
      MANIFEST_COMPARISON_IMPORT_TYPE                          = local.manifest_import_type
      MANIFEST_S3_INPUT_PARQUET_LOCATION_MISSING_IMPORT        = "${local.manifest_s3_input_parquet_location_base}/missing_import"
      MANIFEST_S3_INPUT_PARQUET_LOCATION_MISSING_EXPORT        = "${local.manifest_s3_input_parquet_location_base}/missing_export"
      MANIFEST_S3_INPUT_PARQUET_LOCATION_COUNTS                = "${local.manifest_s3_input_parquet_location_base}/counts"
      MANIFEST_S3_INPUT_PARQUET_LOCATION_MISMATCHED_TIMESTAMPS = "${local.manifest_s3_input_parquet_location_base}/mismatched_timestamps"
      MANIFEST_S3_PREFIX                                        = "${local.manifest_s3_output_location}/templates"
      MANIFEST_S3_BUCKET                                        = local.manifest_bucket_id
    }
  }

  tags = {
    Name = "glue_launcher"
  }

  depends_on = [
  aws_cloudwatch_log_group.glue_launcher_lambda]
}

resource "aws_iam_role" "glue_launcher_lambda_role" {
  name               = "glue_launcher_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.glue_launcher_lambda_assume_role.json
}

data "aws_iam_policy_document" "glue_launcher_lambda_assume_role" {
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

data "aws_iam_policy_document" "glue_launcher_lambda" {
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
      "glue:CreateTable",
      "glue:StartJobRun",
      "glue:GetTable*",
      "glue:GetDatabase*",
      "glue:GetPartition*",
      "glue:DeleteTable",
      "glue:DeletePartition*",
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
      "athena:GetQueryResult*"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid    = "AllowS3AccessForAthena"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
      "s3:PutObject"
    ]

    resources = [
      local.manifest_bucket_arn,
      "${local.manifest_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "AllowInteractWithS3Objects"
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
}

resource "aws_iam_role_policy_attachment" "glue_launcher_iam_policy_attachment" {
  role       = aws_iam_role.glue_launcher_lambda_role.name
  policy_arn = aws_iam_policy.glue_launcher_lambda.arn
}

resource "aws_iam_role_policy_attachment" "glue_launcher_basic_execution_policy_attachment" {
  role       = aws_iam_role.glue_launcher_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "glue_launcher_lambda" {
  name        = "GlueLauncherLambdaIAM"
  description = "Allow Glue Launcher Lambda to view Batch Jobs and kick off Glue jobs"
  policy      = data.aws_iam_policy_document.glue_launcher_lambda.json
}

resource "aws_lambda_permission" "batch_coalescer_job_status_change" {
  statement_id  = "AllowExecution_batch_coalescer_job_status_change"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.glue_launcher.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.batch_coalescer_job_status_change.arn
}

resource "aws_lambda_permission" "batch_coalescer_long_running_job_status_change" {
  statement_id  = "AllowExecution_batch_coalescer_long_running_job_status_change"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.glue_launcher.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.batch_coalescer_long_running_job_status_change.arn
}

resource "aws_cloudwatch_log_group" "glue_launcher_lambda" {
  name              = "/aws/lambda/glue_launcher"
  retention_in_days = "180"
}
