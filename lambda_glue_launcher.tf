variable "glue_launcher_zip" {
  type = map(string)

  default = {
    base_path = ""
    version   = ""
  }
}

locals {
  manifest_bucket_id     = data.terraform_remote_state.aws-internal-compute.outputs.manifest_bucket.id
  manifest_import_type   = "streaming_main"
  manifest_snapshot_type = "incremental"
  manifest_data_name     = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.database_name

  manifest_s3_input_parquet_location = data.terraform_remote_state.aws-internal-compute.outputs.manifest_s3_prefixes.parquet

  manifest_counts_parquet_table_name        = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.table_name_counts_parquet
  manifest_mismatched_timestamps_table_name = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.table_name_mismatched_timestamps_parquet
  missing_imports_parquet_table_name        = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.table_name_missing_imports_parquet
  missing_exports_parquet_table_name        = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.table_name_missing_exports_parquet

  manifest_s3_input_parquet_location_base = "s3://${local.manifest_bucket_id}/${local.manifest_s3_input_parquet_location}/${local.manifest_import_type}_${local.manifest_snapshot_type}"
  manifest_s3_output_location             = data.terraform_remote_state.aws-ingestion.outputs.manifest_comparison_parameters.query_output_s3_prefix
}

resource "aws_lambda_function" "glue_launcher" {
  filename      = "${var.glue_launcher_zip["base_path"]}/emr-launcher-${var.glue_launcher_zip["version"]}.zip"
  function_name = "glue_launcher"
  role          = aws_iam_role.glue_launcher_lambda_role.arn
  handler       = "glue_launcher_lambda.glue_launcher.handler"
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
      JOB_QUEUE_DEPENDENCIES                                   = "${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.batch_job_queues.batch_corporate_storage_coalescer.name},${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.batch_job_queues.batch_corporate_storage_coalescer_long_running.name}"
      ETL_GLUE_JOB_NAME                                        = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.job_name_combined
      MANIFEST_COUNTS_PARQUET_TABLE_NAME                       = "${local.manifest_data_name}.${local.manifest_counts_parquet_table_name}_${local.manifest_import_type}_${local.manifest_snapshot_type}"
      MANIFEST_MISMATCHED_TIMESTAMPS_TABLE_NAME                = "${local.manifest_data_name}.${local.manifest_mismatched_timestamps_table_name}_${local.manifest_import_type}_${local.manifest_snapshot_type}"
      MANIFEST_MISSING_IMPORTS_TABLE_NAME                      = "${local.manifest_data_name}.${local.missing_imports_parquet_table_name}_${local.manifest_import_type}_${local.manifest_snapshot_type}"
      MANIFEST_MISSING_EXPORTS_TABLE_NAME                      = "${local.manifest_data_name}.${local.missing_exports_parquet_table_name}_${local.manifest_import_type}_${local.manifest_snapshot_type}"
      MANIFEST_S3_INPUT_LOCATION_IMPORT                        = data.terraform_remote_state.aws-internal-compute.outputs.manifest_comparison_parameters.historic_folder
      MANIFEST_S3_INPUT_LOCATION_EXPORT                        = data.terraform_remote_state.aws-ingestion.outputs.manifest_comparison_parameters.query_output_s3_prefix
      MANIFEST_COMPARISON_CUT_OFF_DATE_START                   = "PREVIOUS_DAY_MIDNIGHT" # Set an 'YYYY-MM-DD HH:MM:SS.MMM' to define. Else lambda will calculate date if empty or set to "PREVIOUS_DAY_MIDNIGHT"
      MANIFEST_COMPARISON_CUT_OFF_DATE_END                     = "TODAY_MIDNIGHT"        # Set an 'YYYY-MM-DD HH:MM:SS.MMM' to define. Else lambda will calculate date if empty or set to "TODAY_MIDNIGHT"
      MANIFEST_COMPARISON_MARGIN_OF_ERROR_MINUTES              = "2"                     # Lambda defaults to 2 if not set
      MANIFEST_COMPARISON_SNAPSHOT_TYPE                        = local.manifest_snapshot_type
      MANIFEST_COMPARISON_IMPORT_TYPE                          = local.manifest_import_type
      MANIFEST_S3_INPUT_PARQUET_LOCATION_MISSING_IMPORT        = "${local.manifest_s3_input_parquet_location_base}/missing_import"
      MANIFEST_S3_INPUT_PARQUET_LOCATION_MISSING_EXPORT        = "${local.manifest_s3_input_parquet_location_base}/missing_export"
      MANIFEST_S3_INPUT_PARQUET_LOCATION_COUNTS                = "${local.manifest_s3_input_parquet_location_base}/counts"
      MANIFEST_S3_INPUT_PARQUET_LOCATION_MISMATCHED_TIMESTAMPS = "${local.manifest_s3_input_parquet_location_base}/mismatched_timestamps"
      MANIFEST_S3_OUTPUT_LOCATION                              = "s3://${local.manifest_bucket_id}/${local.manifest_s3_output_location}_${local.manifest_import_type}_${local.manifest_snapshot_type}/templates"
    }
  }

  tags = {
    Name = "glue_launcher"
  }
}

resource "aws_iam_role" "glue_launcher_lambda_role" {
  name               = "glue_launcher_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.glue_launcher_lambda_assume_role.json
  tags = {
    Name = "glue_launcher_lambda_role"
  }
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

resource "aws_iam_role_policy_attachment" "glue_launcher_iam_policy_attachment" {
  role       = aws_iam_role.glue_launcher_lambda_role.name
  policy_arn = aws_iam_policy.glue_launcher_lambda.arn
}

resource "aws_iam_policy" "glue_launcher_lambda" {
  name        = "GlueLauncherLambdaIAM"
  description = "Allow Glue Launcher Lambda to view Batch Jobs and kick off Glue jobs"
  policy      = data.aws_iam_policy_document.glue_launcher_lambda.json
}
