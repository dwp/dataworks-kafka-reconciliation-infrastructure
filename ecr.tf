resource "aws_ecr_repository" "kafka_reconciliation" {
  name = "kafka-reconciliation"
  tags = merge(
    local.common_tags,
    { DockerHub : "dwpdigital/kafka-reconciliation" }
  )
}

resource "aws_ecr_repository_policy" "kafka-reconciliation" {
  repository = aws_ecr_repository.kafka_reconciliation.name
  policy     = data.terraform_remote_state.management.outputs.ecr_iam_policy_document
}

output "ecr_example_url" {
  value = aws_ecr_repository.kafka_reconciliation.repository_url
}
