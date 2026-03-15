module "amazon_q_developer" {
  source = "../"

  project_name    = "test-q-project"
  repository_url  = "https://github.com/example-org/example-repo"
  source_provider = "GitHub"
  branch_name     = "main"

  build_compute_type      = "BUILD_GENERAL1_MEDIUM"
  build_image             = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
  enable_code_review      = false
  enable_security_scanning = true
  codeartifact_domain     = ""

  pipeline_stages     = []
  notification_emails = []
  encryption_key_arn  = ""

  tags = {
    Environment = "test"
    ManagedBy   = "terraform"
  }
}
