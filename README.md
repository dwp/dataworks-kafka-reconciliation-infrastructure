# dataworks-kafka-reconciliation-infrastructure

## Kafka Reconciliation Process

### What and Why

### How
Corporate Storage Coalescer 'Success or Failure' status on Batch > Glue Launcher Lambda > 'ETL' Glue Job > Batch manifest comparison > Kafka reconciliation results verifier lambda

### When
Every day.

Schedule of corporate storage coalescer - which in turn kicks everything else off.
