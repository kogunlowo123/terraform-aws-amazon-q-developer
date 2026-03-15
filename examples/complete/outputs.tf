output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project"
  value       = module.amazon_q_developer.codebuild_project_arn
}

output "codepipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = module.amazon_q_developer.codepipeline_arn
}

output "s3_artifact_bucket" {
  description = "Name of the S3 artifact bucket"
  value       = module.amazon_q_developer.s3_artifact_bucket
}

output "sns_topic_arn" {
  description = "ARN of the SNS notification topic"
  value       = module.amazon_q_developer.sns_topic_arn
}

output "connection_arn" {
  description = "ARN of the CodeStar connection"
  value       = module.amazon_q_developer.connection_arn
}

output "codeartifact_domain_arn" {
  description = "ARN of the CodeArtifact domain"
  value       = module.amazon_q_developer.codeartifact_domain_arn
}
