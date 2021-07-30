locals {
  manifest_comparison_image            = "${local.account.management}.${local.ingest_vpc_ecr_dkr_domain_name}/kafka-reconciliation:${var.image_version.kafka-reconciliation}"
  manifest_comparison_application_name = "corporate-storage-coalescer"
}



resource "aws_batch_job_queue" "manifest_comparison_long_running" {
  //  TODO: Move compute environment to fargate once Terraform supports it.
  compute_environments = [aws_batch_compute_environment.manifest_comparison.arn]
  name                 = "manifest_comparison_long_running"
  priority             = 5
  state                = "ENABLED"
}

resource "aws_batch_job_definition" "manifest_comparison_storage" {
  name = "manifest_comparison_job_storage"
  type = "container"

  container_properties = <<CONTAINER_PROPERTIES
  {
      "command": [
            "-b", "Ref::s3-bucket-id",
            "-p", "Ref::s3-prefix",
            "-n", "Ref::partition",
            "-t", "Ref::threads",
            "-f", "Ref::max-files",
            "-s", "Ref::max-size",
            "-d", "Ref::date-to-add",
            "-m"
          ],
      "image": "${local.manifest_comparison_image}",
      "jobRoleArn" : "${aws_iam_role.manifest_comparison.arn}",
      "memory": 32768,
      "vcpus": 5,
      "environment": [
          {"name": "LOG_LEVEL", "value": "INFO"},
          {"name": "AWS_DEFAULT_REGION", "value": "eu-west-2"},
          {"name": "DATA_BUCKET", "value": "${data.terraform_remote_state.common.outputs.published_bucket.id}"},
          {"name": "ENVIRONMENT", "value": "${local.environment}"},
          {"name": "APPLICATION", "value": "${local.manifest_comparison_application_name}"}
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

resource "aws_iam_role" "manifest_comparison" {
  name               = "manifest_comparison"
  assume_role_policy = data.aws_iam_policy_document.batch_assume_policy.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "manifest_comparison_config_bucket" {
  statement {
    sid    = "AllowS3GetConfigObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]

    resources = [
      "${data.terraform_remote_state.common.outputs.config_bucket.arn}/${local.config_prefix}/*",
    ]
  }

  statement {
    sid    = "AllowDecryptConfigBucketObjects"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]

    resources = [
      data.terraform_remote_state.common.outputs.config_bucket_cmk.arn,
    ]
  }
}

data "aws_iam_policy_document" "manifest_comparison_s3" {
  statement {
    sid    = "AllowS3ReadWrite"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject*",
      "s3:DeleteObject*"
    ]

    resources = [
      "${local.internal_compute_manifest_bucket.arn}/*",
      "${local.ingest_corporate_storage_bucket.arn}/*",
    ]
  }

  statement {
    sid    = "AllowS3ListObjects"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]

    resources = [
      local.internal_compute_manifest_bucket.arn,
      local.ingest_corporate_storage_bucket.arn,
    ]
  }

  statement {
    sid    = "AllowKMSEncryption"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]

    resources = [
      local.internal_compute_manifest_bucket_cmk.arn,
      local.ingest_input_bucket_cmk_arn
    ]
  }
}

resource "aws_iam_policy" "manifest_comparison_config" {
  name   = "manifest_comparison_config"
  policy = data.aws_iam_policy_document.manifest_comparison_config_bucket.json
}

resource "aws_iam_policy" "manifest_comparison_s3" {
  name   = "manifest_comparison_s3"
  policy = data.aws_iam_policy_document.manifest_comparison_s3.json
}

resource "aws_iam_role_policy_attachment" "manifest_comparison_config" {
  role       = aws_iam_role.manifest_comparison.name
  policy_arn = aws_iam_policy.manifest_comparison_config.arn
}

resource "aws_iam_role_policy_attachment" "manifest_comparison_s3" {
  role       = aws_iam_role.manifest_comparison.name
  policy_arn = aws_iam_policy.manifest_comparison_s3.arn
}




