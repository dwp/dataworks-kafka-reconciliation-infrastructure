locals {
  common_tags = {
    Environment  = local.environment
    Application  = "dataworks-kafka-reconciliation-infrastructure"
    CreatedBy    = "terraform"
    Owner        = "dataworks platform"
    Persistence  = "Ignore"
    AutoShutdown = "False"
  }
}
