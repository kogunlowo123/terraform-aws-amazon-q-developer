output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project"
  value       = module.amazon_q_developer.codebuild_project_arn
}

output "codepipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = module.amazon_q_developer.codepipeline_arn
}

output "s3_artifact_bucket" {
  description = "Name of the S3 bucket used for pipeline artifacts"
  value       = module.amazon_q_developer.s3_artifact_bucket
}
