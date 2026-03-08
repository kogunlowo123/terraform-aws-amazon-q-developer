variable "project_name" {
  description = "Name of the project, used as a prefix for all resources"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,48}$", var.project_name))
    error_message = "Project name must start with a letter, contain only alphanumeric characters and hyphens, and be 2-49 characters."
  }
}

variable "repository_url" {
  description = "URL of the source code repository"
  type        = string
}

variable "source_provider" {
  description = "Source code provider for the connection (GitHub, GitLab, Bitbucket)"
  type        = string
  default     = "GitHub"

  validation {
    condition     = contains(["GitHub", "GitLab", "Bitbucket", "GitHubEnterpriseServer"], var.source_provider)
    error_message = "Source provider must be GitHub, GitLab, Bitbucket, or GitHubEnterpriseServer."
  }
}

variable "branch_name" {
  description = "Branch name to build from"
  type        = string
  default     = "main"
}

variable "build_compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_MEDIUM"

  validation {
    condition     = contains(["BUILD_GENERAL1_SMALL", "BUILD_GENERAL1_MEDIUM", "BUILD_GENERAL1_LARGE", "BUILD_GENERAL1_2XLARGE"], var.build_compute_type)
    error_message = "Build compute type must be a valid CodeBuild compute type."
  }
}

variable "build_image" {
  description = "Docker image for the CodeBuild environment"
  type        = string
  default     = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
}

variable "enable_code_review" {
  description = "Enable Amazon CodeGuru Reviewer for automated code reviews"
  type        = bool
  default     = true
}

variable "enable_security_scanning" {
  description = "Enable security scanning in the build pipeline"
  type        = bool
  default     = true
}

variable "codeartifact_domain" {
  description = "Name of the CodeArtifact domain for package management"
  type        = string
  default     = ""
}

variable "pipeline_stages" {
  description = "Additional pipeline stages beyond Source and Build"
  type = list(object({
    name = string
    actions = list(object({
      name             = string
      category         = string
      provider         = string
      input_artifacts  = optional(list(string), [])
      output_artifacts = optional(list(string), [])
      configuration    = optional(map(string), {})
      run_order        = optional(number, 1)
    }))
  }))
  default = []
}

variable "notification_emails" {
  description = "Email addresses for pipeline notifications"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for email in var.notification_emails : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))])
    error_message = "All email addresses must be valid."
  }
}

variable "encryption_key_arn" {
  description = "ARN of an existing KMS key for encryption. If empty, a new key will be created."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
