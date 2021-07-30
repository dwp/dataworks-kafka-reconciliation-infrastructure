resource "aws_ecr_repository" "dataworks-batch-job-launcher" {
  name = "dataworks-batch-job-launcher"
  tags = merge(
    local.common_tags,
    { DockerHub : "dwpdigital/dataworks-batch-job-launcher" }
  )
}

resource "aws_ecr_repository_policy" "dataworks-batch-job-launcher" {
  repository = aws_ecr_repository.dataworks-batch-job-launcher.name
  policy     = data.terraform_remote_state.management.outputs.ecr_iam_policy_document
}

output "ecr_example_url" {
  value = aws_ecr_repository.dataworks-batch-job-launcher.repository_url
}
