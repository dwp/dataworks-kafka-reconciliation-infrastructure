# AWS Batch Instance IAM role & profile

resource "aws_batch_compute_environment" "kafka_reconciliation" {
  compute_environment_name_prefix = "kafka_reconciliation_"
  service_role                    = data.aws_iam_role.aws_batch_service_role.arn
  type                            = "MANAGED"

  compute_resources {
    image_id            = var.ecs_hardened_ami_id
    instance_role       = aws_iam_instance_profile.ecs_instance_role_kafka_reconciliation_batch.arn
    instance_type       = ["optimal"]
    allocation_strategy = "BEST_FIT_PROGRESSIVE"

    min_vcpus     = 0
    desired_vcpus = 0
    max_vcpus     = local.kafka_reconciliation_compute_environment_max_cpus[local.environment]

    security_group_ids = [data.terraform_remote_state.aws-ingestion.outputs.ingestion_vpc.vpce_security_groups.kafka_reconciliation_batch.id]
    subnets            = local.ingest_subnets.id
    type               = "EC2"

    tags = {
      Name         = "kafka_reconciliation",
      Persistence  = "Ignore",
      AutoShutdown = "False",
      SSMEnabled   = "True"
    }
  }

  lifecycle {
    ignore_changes        = [compute_resources.0.desired_vcpus]
    create_before_destroy = true
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

# Custom policy to allow use of default EBS encryption key by Batch instance role
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
