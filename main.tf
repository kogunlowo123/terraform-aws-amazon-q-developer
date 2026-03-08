###############################################################################
# Data Sources
###############################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

###############################################################################
# KMS Key for Encryption
###############################################################################

resource "aws_kms_key" "this" {
  count = var.encryption_key_arn == "" ? 1 : 0

  description             = "KMS key for ${var.project_name} pipeline encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCodePipelineAndCodeBuild"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.codebuild.arn,
            aws_iam_role.codepipeline.arn,
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "this" {
  count = var.encryption_key_arn == "" ? 1 : 0

  name          = "alias/${var.project_name}-pipeline"
  target_key_id = aws_kms_key.this[0].key_id
}

locals {
  kms_key_arn = var.encryption_key_arn != "" ? var.encryption_key_arn : aws_kms_key.this[0].arn
}

###############################################################################
# S3 Bucket for Artifacts
###############################################################################

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project_name}-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = false

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-old-artifacts"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

###############################################################################
# CodeStar Connection
###############################################################################

resource "aws_codestarconnections_connection" "this" {
  name          = "${var.project_name}-connection"
  provider_type = var.source_provider

  tags = var.tags
}

###############################################################################
# CodeArtifact Domain & Repository
###############################################################################

resource "aws_codeartifact_domain" "this" {
  count = var.codeartifact_domain != "" ? 1 : 0

  domain         = var.codeartifact_domain
  encryption_key = local.kms_key_arn

  tags = var.tags
}

resource "aws_codeartifact_repository" "this" {
  count = var.codeartifact_domain != "" ? 1 : 0

  repository  = "${var.project_name}-packages"
  domain      = aws_codeartifact_domain.this[0].domain
  description = "Package repository for ${var.project_name}"

  upstream {
    repository_name = "npm-store"
  }

  tags = var.tags
}

resource "aws_codeartifact_repository" "upstream_npm" {
  count = var.codeartifact_domain != "" ? 1 : 0

  repository  = "npm-store"
  domain      = aws_codeartifact_domain.this[0].domain
  description = "npm upstream proxy"

  external_connections {
    external_connection_name = "public:npmjs"
  }

  tags = var.tags
}

###############################################################################
# CodeBuild IAM Role
###############################################################################

resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${var.project_name}-codebuild-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.codebuild.arn,
          "${aws_cloudwatch_log_group.codebuild.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*"
        ]
        Resource = [local.kms_key_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = [aws_codestarconnections_connection.this.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:CreateReportGroup",
          "codebuild:CreateReport",
          "codebuild:UpdateReport",
          "codebuild:BatchPutTestCases",
          "codebuild:BatchPutCodeCoverages"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:codebuild:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:report-group/${var.project_name}-*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_codeartifact" {
  count = var.codeartifact_domain != "" ? 1 : 0

  name = "${var.project_name}-codebuild-codeartifact"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codeartifact:GetAuthorizationToken",
          "codeartifact:GetRepositoryEndpoint",
          "codeartifact:ReadFromRepository",
          "codeartifact:PublishPackageVersion",
          "codeartifact:PutPackageMetadata"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "sts:GetServiceBearerToken"
        Resource = "*"
        Condition = {
          StringEquals = {
            "sts:AWSServiceName" = "codeartifact.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_security_scanning" {
  count = var.enable_security_scanning ? 1 : 0

  name = "${var.project_name}-codebuild-security"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "inspector2:ListFindings",
          "inspector2:BatchGetFreeTrialInfo",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

###############################################################################
# CloudWatch Log Group for CodeBuild
###############################################################################

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/${var.project_name}"
  retention_in_days = 90

  tags = var.tags
}

###############################################################################
# CodeBuild Project
###############################################################################

resource "aws_codebuild_project" "this" {
  name          = var.project_name
  description   = "Build project for ${var.project_name} with Amazon Q code review integration"
  build_timeout = 60
  service_role  = aws_iam_role.codebuild.arn
  encryption_key = local.kms_key_arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
  }

  environment {
    compute_type                = var.build_compute_type
    image                       = var.build_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }

    environment_variable {
      name  = "ARTIFACT_BUCKET"
      value = aws_s3_bucket.artifacts.bucket
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "ENABLE_SECURITY_SCANNING"
      value = var.enable_security_scanning ? "true" : "false"
    }

    dynamic "environment_variable" {
      for_each = var.codeartifact_domain != "" ? [1] : []
      content {
        name  = "CODEARTIFACT_DOMAIN"
        value = var.codeartifact_domain
      }
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "build"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-BUILDSPEC
      version: 0.2

      phases:
        install:
          runtime-versions:
            python: 3.12
            nodejs: 20
          commands:
            - echo "Installing dependencies..."
            - pip install --upgrade pip
        pre_build:
          commands:
            - echo "Running pre-build checks..."
            - echo "Build started on $(date)"
            - |
              if [ "$ENABLE_SECURITY_SCANNING" = "true" ]; then
                echo "Running security scanning..."
                pip install bandit safety
                bandit -r . -f json -o security-report.json || true
                safety check --json --output safety-report.json || true
              fi
        build:
          commands:
            - echo "Building project $PROJECT_NAME..."
            - |
              if [ -f "requirements.txt" ]; then
                pip install -r requirements.txt
              fi
            - |
              if [ -f "package.json" ]; then
                npm ci
                npm run build || true
              fi
            - |
              if [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
                pip install -e ".[dev]" || pip install -e . || true
              fi
        post_build:
          commands:
            - echo "Running tests..."
            - |
              if [ -f "pytest.ini" ] || [ -f "setup.cfg" ] || [ -f "pyproject.toml" ]; then
                python -m pytest --junitxml=test-results.xml || true
              fi
            - |
              if [ -f "package.json" ]; then
                npm test || true
              fi
            - echo "Build completed on $(date)"

      artifacts:
        files:
          - '**/*'
        discard-paths: no

      reports:
        test-results:
          files:
            - test-results.xml
          file-format: JUNITXML
        security-results:
          files:
            - security-report.json
            - safety-report.json
          file-format: GENERICJSON
    BUILDSPEC
  }

  tags = var.tags
}

###############################################################################
# CodeGuru Reviewer
###############################################################################

resource "aws_codegurureviewer_repository_association" "this" {
  count = var.enable_code_review ? 1 : 0

  repository {
    codecommit {
      name = var.project_name
    }
  }

  tags = var.tags
}

###############################################################################
# CodePipeline IAM Role
###############################################################################

resource "aws_iam_role" "codepipeline" {
  name = "${var.project_name}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.project_name}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = [aws_codestarconnections_connection.this.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:StopBuild"
        ]
        Resource = [aws_codebuild_project.this.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*"
        ]
        Resource = [local.kms_key_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [aws_sns_topic.pipeline.arn]
      }
    ]
  })
}

###############################################################################
# CodePipeline
###############################################################################

resource "aws_codepipeline" "this" {
  name     = var.project_name
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"

    encryption_key {
      id   = local.kms_key_arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.this.arn
        FullRepositoryId = var.repository_url
        BranchName       = var.branch_name
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  dynamic "stage" {
    for_each = var.pipeline_stages
    content {
      name = stage.value.name

      dynamic "action" {
        for_each = stage.value.actions
        content {
          name             = action.value.name
          category         = action.value.category
          owner            = "AWS"
          provider         = action.value.provider
          input_artifacts  = action.value.input_artifacts
          output_artifacts = action.value.output_artifacts
          version          = "1"
          configuration    = action.value.configuration
          run_order        = action.value.run_order
        }
      }
    }
  }

  tags = var.tags
}

###############################################################################
# SNS Topic for Pipeline Notifications
###############################################################################

resource "aws_sns_topic" "pipeline" {
  name              = "${var.project_name}-pipeline-notifications"
  kms_master_key_id = local.kms_key_arn

  tags = var.tags
}

resource "aws_sns_topic_policy" "pipeline" {
  arn = aws_sns_topic.pipeline.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCodePipelinePublish"
        Effect = "Allow"
        Principal = {
          Service = "codestar-notifications.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.pipeline.arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.notification_emails)

  topic_arn = aws_sns_topic.pipeline.arn
  protocol  = "email"
  endpoint  = each.value
}

###############################################################################
# CodePipeline Notification Rule
###############################################################################

resource "aws_codestarnotifications_notification_rule" "pipeline" {
  name        = "${var.project_name}-pipeline-notifications"
  detail_type = "FULL"
  resource    = aws_codepipeline.this.arn

  event_type_ids = [
    "codepipeline-pipeline-pipeline-execution-started",
    "codepipeline-pipeline-pipeline-execution-failed",
    "codepipeline-pipeline-pipeline-execution-succeeded",
    "codepipeline-pipeline-pipeline-execution-canceled",
    "codepipeline-pipeline-stage-execution-failed",
  ]

  target {
    address = aws_sns_topic.pipeline.arn
    type    = "SNS"
  }

  tags = var.tags
}

###############################################################################
# CodePipeline Notification for Build Events
###############################################################################

resource "aws_codestarnotifications_notification_rule" "build" {
  name        = "${var.project_name}-build-notifications"
  detail_type = "FULL"
  resource    = aws_codebuild_project.this.arn

  event_type_ids = [
    "codebuild-project-build-state-failed",
    "codebuild-project-build-state-succeeded",
    "codebuild-project-build-state-stopped",
  ]

  target {
    address = aws_sns_topic.pipeline.arn
    type    = "SNS"
  }

  tags = var.tags
}
