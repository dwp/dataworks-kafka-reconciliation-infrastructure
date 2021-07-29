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

  manifest_etl_combined_name = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.manifest_etl.job_name_combined

  batch_corporate_storage_coalescer              = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.batch_job_queues.batch_corporate_storage_coalescer.arn
  batch_corporate_storage_coalescer_long_running = data.terraform_remote_state.dataworks-aws-ingest-consumers.outputs.batch_job_queues.batch_corporate_storage_coalescer_long_running.arn
}
