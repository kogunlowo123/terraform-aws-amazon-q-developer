output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project"
  value       = aws_codebuild_project.this.arn
}

output "codepipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = aws_codepipeline.this.arn
}

output "codeartifact_domain_arn" {
  description = "ARN of the CodeArtifact domain"
  value       = var.codeartifact_domain != "" ? aws_codeartifact_domain.this[0].arn : null
}

output "codeartifact_repository_arn" {
  description = "ARN of the CodeArtifact repository"
  value       = var.codeartifact_domain != "" ? aws_codeartifact_repository.this[0].arn : null
}

output "codeguru_association_arn" {
  description = "ARN of the CodeGuru Reviewer repository association"
  value       = var.enable_code_review ? aws_codegurureviewer_repository_association.this[0].arn : null
}

output "s3_artifact_bucket" {
  description = "Name of the S3 bucket used for pipeline artifacts"
  value       = aws_s3_bucket.artifacts.bucket
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for pipeline notifications"
  value       = aws_sns_topic.pipeline.arn
}

output "connection_arn" {
  description = "ARN of the CodeStar connection to the source provider"
  value       = aws_codestarconnections_connection.this.arn
}
