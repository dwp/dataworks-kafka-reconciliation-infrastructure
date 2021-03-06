locals {
  kafka_reconciliation_image            = format("%s:%s", data.terraform_remote_state.management.outputs.ecr_kafka_reconciliation_url, var.image_version.kafka-reconciliation)
  kafka_reconciliation_application_name = "kafka-reconciliation"
}


resource "aws_batch_job_queue" "kafka_reconciliation" {
  //  TODO: Move compute environment to fargate once Terraform supports it.
  compute_environments = [aws_batch_compute_environment.kafka_reconciliation.arn]
  name                 = local.kafka_reconciliation_application_name
  priority             = 5
  state                = "ENABLED"
}

resource "aws_batch_job_definition" "kafka_reconciliation" {
  name = local.kafka_reconciliation_application_name
  type = "container"

  container_properties = <<CONTAINER_PROPERTIES
  {
      "command": [
            "-i", "Ref::manifest_missing_imports_table_name",
            "-e", "Ref::manifest_missing_exports_table_name",
            "-c", "Ref::manifest_counts_table_name",
            "-t", "Ref::manifest_mismatched_timestamps_table_name",
            "-r", "Ref::manifest_report_count_of_ids",
            "-p", "Ref::manifest_s3_prefix",
            "-b", "Ref::manifest_s3_bucket"
          ],
      "image": "${local.kafka_reconciliation_image}",
      "jobRoleArn" : "${aws_iam_role.kafka_reconciliation_batch.arn}",
      "memory": 32768,
      "vcpus": 5,
      "environment": [
          {"name": "LOG_LEVEL", "value": "INFO"},
          {"name": "AWS_DEFAULT_REGION", "value": "eu-west-2"},
          {"name": "ENVIRONMENT", "value": "${local.environment}"},
          {"name": "APPLICATION", "value": "${local.kafka_reconciliation_application_name}"}
      ],
      "ulimits": [
        {
          "hardLimit": 100000,
          "name": "nofile",
          "softLimit": 100000
        }
      ]
  }
  CONTAINER_PROPERTIES
}

resource "aws_iam_role" "kafka_reconciliation_batch" {
  name               = "kafka_reconciliation"
  assume_role_policy = data.aws_iam_policy_document.batch_assume_policy.json
}

data "aws_iam_policy_document" "kafka_reconciliation_ecs" {
  statement {
    sid    = "AllowS3ObjectInteractions"
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
      "${local.manifest_bucket_arn}/*",
    ]
  }

  statement {
    sid    = "AllowDecryptConfigBucketObjects"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = [
      local.manifest_bucket_cmk,
    ]
  }

  statement {
    sid    = "AllowAthenaAccess"
    effect = "Allow"
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResult*",
      "athena:GetWorkGroup",
      "athena:ListWorkGroups",
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
      "glue:Get*",
      "glue:GetDatabase*",
      "glue:GetPartition*",
      "glue:DeleteTable",
      "glue:DeletePartition*",
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "kafka_reconciliation" {
  name   = "kafka_reconciliation"
  policy = data.aws_iam_policy_document.kafka_reconciliation_ecs.json
}

resource "aws_iam_role_policy_attachment" "kafka_reconciliation" {
  role       = aws_iam_role.kafka_reconciliation_batch.name
  policy_arn = aws_iam_policy.kafka_reconciliation.arn
}

