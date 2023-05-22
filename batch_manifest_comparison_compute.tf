# AWS Batch Instance IAM role & profile

resource "aws_batch_compute_environment" "kafka_reconciliation" {
  compute_environment_name_prefix = "kafka_reconciliation_"
  service_role                    = data.aws_iam_role.aws_batch_service_role.arn
  type                            = "MANAGED"

  compute_resources {
    instance_role       = aws_iam_instance_profile.ecs_instance_role_kafka_reconciliation_batch.arn
    instance_type       = ["optimal"]
    allocation_strategy = "BEST_FIT_PROGRESSIVE"

    min_vcpus     = 0
    desired_vcpus = 0
    max_vcpus     = local.kafka_reconciliation_compute_environment_max_cpus[local.environment]

    security_group_ids = [data.terraform_remote_state.aws-ingestion.outputs.ingestion_vpc.vpce_security_groups.kafka_reconciliation_batch.id]
    subnets            = local.ingest_subnets.id
    type               = "EC2"

    launch_template {
      launch_template_id      = aws_launch_template.kafka_reconciliation_ecs_cluster.id
      version                 = aws_launch_template.kafka_reconciliation_ecs_cluster.latest_version
    }

    tags = merge(
      local.common_tags,
      {
        Name         = "kafka_reconciliation"
      }
    )
  }

  lifecycle {
    ignore_changes        = [compute_resources.0.desired_vcpus]
    create_before_destroy = true
  }
}

resource "aws_launch_template" "kafka_reconciliation_ecs_cluster" {
  name     = "kafka-reconciliation"
  image_id = var.ecs_hardened_ami_id

  user_data = base64encode(templatefile("files/batch/userdata.tpl", {
    region                                           = var.region
    name                                             = "kafka-reconciliation"
    proxy_port                                       = var.proxy_port
    proxy_host                                       = local.ingest_internet_proxy.host
    hcs_environment                                  = local.hcs_environment[local.environment]
    s3_scripts_bucket                                = data.terraform_remote_state.common.outputs.config_bucket.id
    s3_script_logrotate                              = aws_s3_object.batch_logrotate_script.id
    s3_script_cloudwatch_shell                       = aws_s3_object.batch_cloudwatch_script.id
    s3_script_logging_shell                          = aws_s3_object.batch_logging_script.id
    s3_script_config_hcs_shell                       = aws_s3_object.batch_config_hcs.id
    cwa_namespace                                    = local.cw_kafka_recon_agent_namespace
    cwa_log_group_name                               = "${local.cw_kafka_recon_agent_namespace}-${local.environment}"
    cwa_metrics_collection_interval                  = local.cw_agent_metrics_collection_interval
    cwa_cpu_metrics_collection_interval              = local.cw_agent_cpu_metrics_collection_interval
    cwa_disk_measurement_metrics_collection_interval = local.cw_agent_disk_measurement_metrics_collection_interval
    cwa_disk_io_metrics_collection_interval          = local.cw_agent_disk_io_metrics_collection_interval
    cwa_mem_metrics_collection_interval              = local.cw_agent_mem_metrics_collection_interval
    cwa_netstat_metrics_collection_interval          = local.cw_agent_netstat_metrics_collection_interval

  }))

  instance_initiated_shutdown_behavior = "terminate"

  tags = merge(
    local.common_tags,
    {
      Name = "kafka-reconciliation"
    }
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      {
        Name                = "kafka-reconciliation",
        AutoShutdown        = local.kafka_recon_asg_autoshutdown[local.environment],
        SSMEnabled          = local.kafka_recon_asg_ssmenabled[local.environment],
        Persistence         = "Ignore",
        propagate_at_launch = true,
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
      {
        Name = "kafka-reconciliation",
      }
    )
  }
}

resource "aws_iam_role" "ecs_instance_role_kafka_reconciliation_batch" {
  name = "ecs_instance_role_kafka_reconciliation_batch"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        }
      }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_kafka_reconciliation_batch" {
  role       = aws_iam_role.ecs_instance_role_kafka_reconciliation_batch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_role_kafka_reconciliation_batch" {
  name = "ecs_instance_role_kafka_reconciliation_batch"
  role = aws_iam_role.ecs_instance_role_kafka_reconciliation_batch.name
}

# Custom policy to allow use of default EBS encryption key by Batch instance role and config bucket
data "aws_iam_policy_document" "ecs_instance_role_kafka_reconciliation_batch_ebs_cmk" {

  statement {
    sid    = "AllowUseDefaultEbsCmk"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = [data.terraform_remote_state.security-tools.outputs.ebs_cmk.arn]
  }


  statement {
    effect = "Allow"
    sid    = "AllowAccessToConfigBucket"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]

    resources = [data.terraform_remote_state.common.outputs.config_bucket.arn]
  }

  statement {
    effect = "Allow"
    sid    = "AllowAccessToConfigBucketObjects"

    actions = ["s3:GetObject"]

    resources = ["${data.terraform_remote_state.common.outputs.config_bucket.arn}/*"]
  }

  statement {
    sid    = "AllowKMSDecryptionOfS3ConfigBucketObj"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]

    resources = [data.terraform_remote_state.common.outputs.config_bucket_cmk.arn]
  }

  statement {
    sid    = "AllowAccessLogGroups"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = data.terraform_remote_state.common.outputs.ami_ecs_test_services ? [aws_cloudwatch_log_group.kafka_reconciliation_ecs_cluster.arn, data.terraform_remote_state.common.outputs.ami_ecs_test_log_group_arn] : [aws_cloudwatch_log_group.kafka_reconciliation_ecs_cluster.arn]
  }

  statement {
    sid    = "EnableEC2TaggingHost"
    effect = "Allow"

    actions = [
      "ec2:ModifyInstanceMetadataOptions",
      "ec2:*Tags",
    ]
    resources = ["arn:aws:ec2:${var.region}:${local.account[local.environment]}:instance/*"]
  }

  statement {
    sid    = "ECSListClusters"
    effect = "Allow"

    actions = [
      "ecs:ListClusters",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ssm:*",
    ]

    resources = [
      "*"
    ]
  }

}

resource "aws_iam_policy" "ecs_instance_role_kafka_reconciliation_batch_ebs_cmk" {
  name   = "ecs_instance_role_kafka_reconciliation_batch_ebs_cmk"
  policy = data.aws_iam_policy_document.ecs_instance_role_kafka_reconciliation_batch_ebs_cmk.json
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_kafka_reconciliation_batch_ebs_cmk" {
  role       = aws_iam_role.ecs_instance_role_kafka_reconciliation_batch.name
  policy_arn = aws_iam_policy.ecs_instance_role_kafka_reconciliation_batch_ebs_cmk.arn
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_kafka_reconciliation_batch_ecr" {
  role       = aws_iam_role.ecs_instance_role_kafka_reconciliation_batch.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_kafka_reconciliation_ecs_cwasp" {
  role       = aws_iam_role.ecs_instance_role_kafka_reconciliation_batch.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_kafka_reconciliation_ec2_for_ssm_attachment" {
  role       = aws_iam_role.ecs_instance_role_kafka_reconciliation_batch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_security_group_rule" "kafka_reconciliation_batch_to_s3" {
  description       = "Manifest Comparison Batch to S3"
  type              = "egress"
  prefix_list_ids   = [local.ingest_vpc_prefix_list_ids_s3]
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = data.terraform_remote_state.aws-ingestion.outputs.ingestion_vpc.vpce_security_groups.kafka_reconciliation_batch.id
}

resource "aws_security_group_rule" "kafka_reconciliation_batch_to_s3_http" {
  description       = "Manifest Comparison Batch to S3"
  type              = "egress"
  prefix_list_ids   = [local.ingest_vpc_prefix_list_ids_s3]
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  security_group_id = data.terraform_remote_state.aws-ingestion.outputs.ingestion_vpc.vpce_security_groups.kafka_reconciliation_batch.id
}

resource "aws_security_group_rule" "kafka_reconciliation_batch_egress_internet_proxy" {
  description              = "kafka recon batch to Internet Proxy (for hcs services)"
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 3128
  to_port                  = 3128
  source_security_group_id = local.ingest_internet_proxy.sg
  security_group_id        = data.terraform_remote_state.aws-ingestion.outputs.ingestion_vpc.vpce_security_groups.kafka_reconciliation_batch.id
}
resource "aws_security_group_rule" "kafka_reconciliation_batch_ingress_internet_proxy" {
  description              = "Allow proxy access from kafka recon batch"
  type                     = "ingress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = data.terraform_remote_state.aws-ingestion.outputs.ingestion_vpc.vpce_security_groups.kafka_reconciliation_batch.id
  security_group_id        = local.ingest_internet_proxy.sg
}
