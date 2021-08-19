locals {
  common_tags = {
    Environment  = local.environment
    Application  = "dataworks-kafka-reconciliation-infrastructure"
    CreatedBy    = "terraform"
    Owner        = "dataworks platform"
    Persistence  = "Ignore"
    AutoShutdown = "False"
  }

  manifest_bucket_id     = data.terraform_remote_state.aws-internal-compute.outputs.manifest_bucket.id
  manifest_bucket_arn    = data.terraform_remote_state.aws-internal-compute.outputs.manifest_bucket.arn
  manifest_bucket_cmk    = data.terraform_remote_state.aws-internal-compute.outputs.manifest_bucket_cmk.arn
  manifest_import_type   = "streaming_main"
  manifest_snapshot_type = "incremental"
  manifest_data_name     = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.database_name

  manifest_s3_input_parquet_location      = data.terraform_remote_state.aws-internal-compute.outputs.manifest_s3_prefixes.parquet
  manifest_s3_output_location             = "${local.manifest_s3_output_location_suffix}_${local.manifest_import_type}_${local.manifest_snapshot_type}"

  manifest_counts_parquet_table_name        = "${local.manifest_data_name}.${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.table_name_counts_parquet}_${local.manifest_import_type}_${local.manifest_snapshot_type}"
  manifest_mismatched_timestamps_table_name = "${local.manifest_data_name}.${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.table_name_mismatched_timestamps_parquet}_${local.manifest_import_type}_${local.manifest_snapshot_type}"
  missing_imports_parquet_table_name        = "${local.manifest_data_name}.${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.table_name_missing_imports_parquet}_${local.manifest_import_type}_${local.manifest_snapshot_type}"
  missing_exports_parquet_table_name        = "${local.manifest_data_name}.${data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.table_name_missing_exports_parquet}_${local.manifest_import_type}_${local.manifest_snapshot_type}"

  manifest_report_count_of_ids = "10"

  manifest_s3_input_parquet_location_base = "s3://${local.manifest_bucket_id}/${local.manifest_s3_input_parquet_location}/${local.manifest_import_type}_${local.manifest_snapshot_type}"
  manifest_s3_output_location_suffix      = data.terraform_remote_state.aws-ingestion.outputs.manifest_comparison_parameters.query_output_s3_prefix

  manifest_etl_combined_name = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.job_name_combined

  batch_corporate_storage_coalescer              = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.batch_job_queues.batch_corporate_storage_coalescer.arn
  batch_corporate_storage_coalescer_long_running = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.batch_job_queues.batch_corporate_storage_coalescer_long_running.arn

  batch_corporate_storage_coalescer_name              = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.batch_job_queues.batch_corporate_storage_coalescer.name
  batch_corporate_storage_coalescer_long_running_name = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.batch_job_queues.batch_corporate_storage_coalescer_long_running.name

  ingest_subnets                 = data.terraform_remote_state.aws-ingestion.outputs.ingestion_subnets
  ingest_vpc_prefix_list_ids_s3  = data.terraform_remote_state.aws-ingestion.outputs.vpc.vpc.prefix_list_ids.s3
  ingest_vpc_ecr_dkr_domain_name = data.terraform_remote_state.aws-ingestion.outputs.vpc.vpc.ecr_dkr_domain_name

  kafka_reconciliation_compute_environment_max_cpus = {
    development = 24
    qa          = 24
    integration = 24
    preprod     = 24
    production  = 650
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
}
