data "local_file" "batch_config_hcs" {
  filename = "files/batch/batch_config_hcs.sh"
}

resource "aws_s3_object" "batch_config_hcs" {
  bucket     = local.common_config_bucket.id
  key        = "component/kafka_recon/batch_config_hcs"
  content    = data.local_file.batch_config_hcs.content
  kms_key_id = local.common_config_bucket_cmk_arn

  tags = {
      Name = "batch-config-hcs"
    }
}

data "local_file" "batch_logrotate_script" {
  filename = "files/batch/batch.logrotate"
}

resource "aws_s3_object" "batch_logrotate_script" {
  bucket     = local.common_config_bucket.id
  key        = "component/kafka_recon/batch.logrotate"
  content    = data.local_file.batch_logrotate_script.content
  kms_key_id = local.common_config_bucket_cmk_arn

  tags ={
      Name = "batch-logrotate-script"
    }
}

data "local_file" "batch_cloudwatch_script" {
  filename = "files/batch/batch_cloudwatch.sh"
}

resource "aws_s3_object" "batch_cloudwatch_script" {
  bucket     = local.common_config_bucket.id
  key        = "component/kafka_recon/batch_cloudwatch.sh"
  content    = data.local_file.batch_cloudwatch_script.content
  kms_key_id = local.common_config_bucket_cmk_arn

  tags = {
      Name = "batch-cloudwatch-script"
    }
}

data "local_file" "batch_logging_script" {
  filename = "files/batch/batch_logging.sh"
}

resource "aws_s3_object" "batch_logging_script" {
  bucket     = local.common_config_bucket.id
  key        = "component/kafka_recon/batch_logging.sh"
  content    = data.local_file.batch_logging_script.content
  kms_key_id = local.common_config_bucket_cmk_arn

  tags = {
      Name = "batch-logging-script"
    }
}
