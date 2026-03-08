# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-15

### Added

- CodeBuild project with embedded buildspec supporting Python and Node.js builds
- CodePipeline with Source (CodeStar Connection) and Build stages plus dynamic additional stages
- CodeStar Connection for GitHub, GitLab, Bitbucket, and GitHub Enterprise Server integration
- CodeArtifact domain and repository with npm upstream proxy (optional)
- CodeGuru Reviewer repository association for automated code reviews (optional)
- S3 artifact bucket with versioning, KMS encryption, public access block, and lifecycle policies
- KMS key with key rotation for pipeline artifact encryption (or bring your own key)
- IAM roles and least-privilege policies for CodeBuild and CodePipeline
- CloudWatch Log Group for CodeBuild logs with 90-day retention
- SNS topic with KMS encryption for pipeline and build notifications
- Email subscriptions for notification alerts
- CodeStar notification rules for pipeline execution and build state events
- Security scanning integration with Bandit and Safety in the build pipeline (optional)
- CodeBuild report groups for test results (JUnit XML) and security findings
