################################################################################
# Amazon Q Developer - Complete Example
################################################################################

module "amazon_q_developer" {
  source = "../../"

  project_name    = "my-app-pipeline"
  repository_url  = "https://github.com/example-org/my-application"
  source_provider = "GitHub"
  branch_name     = "main"

  build_compute_type       = "BUILD_GENERAL1_MEDIUM"
  build_image              = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
  enable_code_review       = true
  enable_security_scanning = true

  codeartifact_domain = "my-org-artifacts"

  pipeline_stages = [
    {
      name = "Deploy-Staging"
      actions = [
        {
          name            = "DeployToStaging"
          category        = "Deploy"
          provider        = "CodeDeploy"
          input_artifacts = ["BuildOutput"]
          configuration = {
            ApplicationName     = "my-app"
            DeploymentGroupName = "staging"
          }
          run_order = 1
        }
      ]
    }
  ]

  notification_emails = ["devops-team@example.com"]

  tags = {
    Project     = "my-app-pipeline"
    Environment = "production"
    Team        = "platform-engineering"
  }
}
