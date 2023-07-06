locals {
  kafka_reconciliation_active = {
    development = false
    qa          = false
    integration = false
    preprod     = false
    production  = true
  }
  
  common_tags = {
    DWX_Environment = local.environment
    DWX_Application = "dataworks-kafka-reconciliation-infrastructure"
  }

  common_config_bucket         = data.terraform_remote_state.common.outputs.config_bucket
  common_config_bucket_cmk_arn = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn

  ingest_internet_proxy  = data.terraform_remote_state.aws-ingestion.outputs.internet_proxy

  cw_kafka_recon_agent_namespace                 = "/app/kafka-reconciliation"
  cw_kafka_recon_agent_log_group_name            = "/app/kafka-reconciliation"  

  cw_agent_metrics_collection_interval                  = 60
  cw_agent_cpu_metrics_collection_interval              = 60
  cw_agent_disk_measurement_metrics_collection_interval = 60
  cw_agent_disk_io_metrics_collection_interval          = 60
  cw_agent_mem_metrics_collection_interval              = 60
  cw_agent_netstat_metrics_collection_interval          = 60

  manifest_bucket_id     = data.terraform_remote_state.aws-internal-compute.outputs.manifest_bucket.id
  manifest_bucket_arn    = data.terraform_remote_state.aws-internal-compute.outputs.manifest_bucket.arn
  manifest_bucket_cmk    = data.terraform_remote_state.aws-internal-compute.outputs.manifest_bucket_cmk.arn
  manifest_import_type   = "streaming_all"
  manifest_snapshot_type = "incremental"
  manifest_data_name     = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.database_name

  manifest_s3_input_parquet_location    = data.terraform_remote_state.aws-internal-compute.outputs.manifest_s3_prefixes.parquet
  manifest_s3_output_location           = "${local.manifest_s3_output_location_suffix}_${local.manifest_import_type}_${local.manifest_snapshot_type}"
  manifest_s3_output_templates_location = "s3://${local.manifest_bucket_id}/${local.manifest_s3_output_location}/templates"

  manifest_counts_parquet_table_name        = "${local.manifest_data_name}.${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.table_name_counts_parquet}_${local.manifest_import_type}_${local.manifest_snapshot_type}"
  manifest_mismatched_timestamps_table_name = "${local.manifest_data_name}.${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.table_name_mismatched_timestamps_parquet}_${local.manifest_import_type}_${local.manifest_snapshot_type}"
  missing_imports_parquet_table_name        = "${local.manifest_data_name}.${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.table_name_missing_imports_parquet}_${local.manifest_import_type}_${local.manifest_snapshot_type}"
  missing_exports_parquet_table_name        = "${local.manifest_data_name}.${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.table_name_missing_exports_parquet}_${local.manifest_import_type}_${local.manifest_snapshot_type}"

  manifest_report_count_of_ids = "10"

  manifest_s3_parquet_prefix              = "${local.manifest_s3_input_parquet_location}/${local.manifest_import_type}_${local.manifest_snapshot_type}"
  manifest_s3_input_parquet_location_base = "s3://${local.manifest_bucket_id}/${local.manifest_s3_parquet_prefix}"
  manifest_s3_output_location_suffix      = data.terraform_remote_state.aws-ingestion.outputs.manifest_comparison_parameters.query_output_s3_prefix

  manifest_etl_combined_name = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.job_name_combined

  batch_corporate_storage_coalescer              = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.batch_job_queues.batch_corporate_storage_coalescer.arn
  batch_corporate_storage_coalescer_long_running = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.batch_job_queues.batch_corporate_storage_coalescer_long_running.arn

  batch_corporate_storage_coalescer_name              = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.batch_job_queues.batch_corporate_storage_coalescer.name
  batch_corporate_storage_coalescer_long_running_name = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.batch_job_queues.batch_corporate_storage_coalescer_long_running.name

  ingest_subnets                 = data.terraform_remote_state.aws-ingestion.outputs.ingestion_subnets
  ingest_vpc_prefix_list_ids_s3  = data.terraform_remote_state.aws-ingestion.outputs.vpc.vpc.prefix_list_ids.s3
  ingest_vpc_ecr_dkr_domain_name = data.terraform_remote_state.aws-ingestion.outputs.vpc.vpc.ecr_dkr_domain_name


  tenable_install = {
    development    = "true"
    qa             = "true"
    integration    = "true"
    preprod        = "true"
    production     = "true"
    management-dev = "true"
    management     = "true"
  }

  trend_install = {
    development    = "true"
    qa             = "true"
    integration    = "true"
    preprod        = "true"
    production     = "true"
    management-dev = "true"
    management     = "true"
  }

  tanium_install = {
    development    = "true"
    qa             = "true"
    integration    = "true"
    preprod        = "true"
    production     = "true"
    management-dev = "true"
    management     = "true"
  }


  ## Tanium config
  ## Tanium Servers
  tanium1 = jsondecode(data.aws_secretsmanager_secret_version.terraform_secrets.secret_binary).tanium[local.environment].server_1
  tanium2 = jsondecode(data.aws_secretsmanager_secret_version.terraform_secrets.secret_binary).tanium[local.environment].server_2

  ## Tanium Env Config
  tanium_env = {
    development    = "pre-prod"
    qa             = "prod"
    integration    = "prod"
    preprod        = "prod"
    production     = "prod"
    management-dev = "pre-prod"
    management     = "prod"
  }

  ## Tanium prefix list for TGW for Security Group rules
  tanium_prefix = {
    development    = [data.aws_ec2_managed_prefix_list.list.id]
    qa             = [data.aws_ec2_managed_prefix_list.list.id]
    integration    = [data.aws_ec2_managed_prefix_list.list.id]
    preprod        = [data.aws_ec2_managed_prefix_list.list.id]
    production     = [data.aws_ec2_managed_prefix_list.list.id]
    management-dev = [data.aws_ec2_managed_prefix_list.list.id]
    management     = [data.aws_ec2_managed_prefix_list.list.id]
  }

  tanium_log_level = {
    development    = "41"
    qa             = "41"
    integration    = "41"
    preprod        = "41"
    production     = "41"
    management-dev = "41"
    management     = "41"
  }

  ## Trend config
  tenant   = jsondecode(data.aws_secretsmanager_secret_version.terraform_secrets.secret_binary).trend.tenant
  tenantid = jsondecode(data.aws_secretsmanager_secret_version.terraform_secrets.secret_binary).trend.tenantid
  token    = jsondecode(data.aws_secretsmanager_secret_version.terraform_secrets.secret_binary).trend.token

  policy_id = {
    development    = "1651"
    qa             = "1651"
    integration    = "1651"
    preprod        = "1717"
    production     = "1717"
    management-dev = "1651"
    management     = "1717"
  }

  kafka_reconciliation_compute_environment_max_cpus = {
    development = 24
    qa          = 24
    integration = 24
    preprod     = 24
    production  = 650
  }

  glue_job_max_daily_runs = {
    development = 1
    qa          = 1
    integration = 1
    preprod     = 1
    production  = 5
  }

  management_infra_account = {
    development    = "default"
    qa             = "default"
    integration    = "default"
    management-dev = "default"
    preprod        = "management"
    production     = "management"
    management     = "management"
  }

  kafka_recon_asg_autoshutdown = {
    development = "False"
    qa          = "False"
    integration = "False"
    preprod     = "False"
    production  = "False"
  }

  kafka_recon_asg_ssmenabled = {
    development = "True"
    qa          = "True"
    integration = "True"
    preprod     = "False"
    production  = "False"
  }
}
