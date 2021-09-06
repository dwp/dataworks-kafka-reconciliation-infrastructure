# dataworks-kafka-reconciliation-infrastructure

## Kafka Reconciliation Process
This repo contains the infrastructure for the three key lambdas, batch jobs and compute environment and an SNS topic that together create the Kafka Reconciliation Process.

### What & Why
We want to reconcile the messages received from UC over the Kafka Broker, ensuring our consumers have received all messages, placed them in Hbase and are retrievable from Hbase.
There is a chain of different products / applications which are used to validate the kafka input equals the Hbase output.

### How & When
The sequence of events which are chained, that create the 'Kafka Reconciliation Process'.
![kafka-reconciliation-process-diagram](kafka_reconciliation.png)

1. The batch job `batch_corporate_storage_coalescer` is started via Cloudwatch Rules located [here](https://github.com/dwp/dataworks-aws-ingest-consumers/blob/master/batch_coalescer_trigger_events.tf), which run in the early hours of the morning. 
   A detailed explanation of the tasks activity can be found on the [dataworks-corporate-storage-coalescence readme](https://github.com/dwp/dataworks-corporate-storage-coalescence)
1. Alternatively the manual way to trigger the `batch_corporate_storage_coalescer` is via the ConcourseCI Pipeline `corporate-storage-coalescer`.
1. Status updates for the `batch_corporate_storage_coalescer` & `batch_corporate_storage_coalescer` batch jobs invoke the `glue_launcher` lambda via a Cloudwatch event rule of the same name.
1. Upon ETL Glue job completion, the `manifest_glue_job_completed` Cloudwatch rule will fire. This rule will send an SNS message to `kafka_reconciliation` SNS topic.
1. The receipt of the SNS topic `kafka_reconciliation` is the `athena_reconciliation_launcher` lambda. This lambda will launch the `kafka-reconciliation` batch job.
1. The `kafka-reconciliation` batch job will run Athena queries - comparing data. Once finished, the batch job outputs results to S3 location `business-data/manifest/query-output_streaming_main_incremental/results/`
1. On the presence of objects in the S3 prefix `business-data/manifest/query-output_streaming_main_incremental/results/`, the `kafka_reconciliation_results_verifier` lambda is invoked.
1. The `kafka_reconciliation_results_verifier` lambda reviews the items in the S3 location, and alerts via Slack the counts for total and missing exports.
1. The Slack alerts are sent to `#dataworks-aws-production-notifications` if successful or `#dataworks-aws-critical-alerts` if unsuccessful.
