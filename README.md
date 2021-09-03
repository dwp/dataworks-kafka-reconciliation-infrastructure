# dataworks-kafka-reconciliation-infrastructure

## Kafka Reconciliation Process

### What and Why


### How
Corporate Storage Coalescer 'Success or Failure' status on Batch > Glue Launcher Lambda > 'ETL' Glue Job > Batch manifest comparison > Kafka reconciliation results verifier lambda


SPELLED OUT STEPS --- REMOVE THIS LINE

1. Glue launcher >> Glue job
1. Upon ETL Glue job completion, the `manifest_glue_job_completed` Cloudwatch rule will fire. This rule will send an SNS message to `kafka_reconciliation` SNS topic.
1. The receipt of the SNS topic `kafka_reconciliation` is the `athena_reconciliation_launcher` lambda. This lambda will launch the `kafka-reconciliation` batch job.
1. The `kafka-reconciliation` batch job will run Athena queries - comparing data || once finished, outputs results to S3 location `business-data/manifest/query-output_streaming_main_incremental/results/`
1. On the presence of objects in the S3 prefix `business-data/manifest/query-output_streaming_main_incremental/results/`, the `kafka_reconciliation_results_verifier` lambda is invoked.
1. The `kafka_reconciliation_results_verifier` lambda DOES WHAT?!
1. Places a result of the verification into the Slack channel `#dataworks-aws-production-notifications` if successful or `#dataworks-aws-critical-alerts` if unsuccessful.

### When
Every day.

Schedule of corporate storage coalescer - which in turn kicks everything else off.
