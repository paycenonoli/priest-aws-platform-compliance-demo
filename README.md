
````markdown
<div align="center">

# AWS Terraform Platform Compliance Demo

### Production-Style Infrastructure Security, Compliance & CI/CD

![Terraform](https://img.shields.io/badge/Terraform-1.14+-623CE4?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazonaws&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-CI%2FCD-2088FF?logo=githubactions&logoColor=white)
![OIDC](https://img.shields.io/badge/GitHub%20OIDC-Keyless%20AWS%20Auth-FF9900?logo=amazonaws&logoColor=white)
![Checkov](https://img.shields.io/badge/Checkov-Security%20Scanning-blue)
![OPA](https://img.shields.io/badge/OPA%2FConftest-Policy%20as%20Code-purple)
![TFLint](https://img.shields.io/badge/TFLint-Terraform%20Linting-844FBA)

**A production-style DevSecOps pipeline for secure, compliant Terraform infrastructure on AWS.**

</div>

---

# 1. Project Overview

This project demonstrates how a Platform Engineering / DevOps team can build a secure Terraform delivery pipeline where infrastructure changes are:

- submitted through GitHub Pull Requests
- authenticated to AWS without long-lived credentials
- formatted and validated
- linted with TFLint
- security-scanned with Checkov
- converted into a Terraform execution plan
- evaluated against organizational policies using OPA / Conftest
- blocked when compliance requirements are violated
- merged only after the compliance gate passes
- automatically deployed to AWS after merge
- verified independently using the AWS CLI

The project intentionally includes real failure scenarios and troubleshooting rather than documenting only the successful path.

---

# 2. What This Project Demonstrates

The implementation combines:

- **Terraform** — Infrastructure as Code
- **GitHub Actions** — CI/CD orchestration
- **GitHub OIDC** — passwordless AWS authentication
- **AWS STS** — temporary security credentials
- **AWS IAM** — authentication and authorization
- **S3** — infrastructure deployed by Terraform
- **S3 remote backend** — centralized Terraform state
- **TFLint** — Terraform linting
- **Checkov** — Infrastructure-as-Code security scanning
- **Terraform Plan** — intended infrastructure change artifact
- **OPA / Conftest** — policy-as-code compliance
- **GitHub Pull Requests** — infrastructure review and approval
- **Automated Terraform Apply** — deployment after approved merge

The central engineering principle is:

> Infrastructure should be validated for security, compliance, and correctness before it is allowed to reach the deployment stage.

---

# 3. Architecture

## 3.1 Complete CI/CD and Compliance Architecture

```text
                         ┌─────────────────┐
                         │    Developer    │
                         └────────┬────────┘
                                  │
                                  │ Pull Request
                                  ▼
                         ┌─────────────────┐
                         │     GitHub      │
                         │       PR        │
                         └────────┬────────┘
                                  │
                                  ▼
                       ┌─────────────────────┐
                       │   GitHub Actions    │
                       │      Runner         │
                       └──────────┬──────────┘
                                  │
                   ┌──────────────┼──────────────┐
                   │              │              │
                   ▼              ▼              ▼
                Terraform       TFLint        Checkov
                fmt/validate    linting       security
                   │              │              │
                   └──────────────┼──────────────┘
                                  │
                                  ▼
                         Terraform Plan
                                  │
                                  ▼
                             tfplan.json
                                  │
                                  ▼
                         OPA / Conftest
                                  │
                                  ▼
                        ┌──────────────────┐
                        │ COMPLIANCE GATE  │
                        └────────┬─────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    ▼                         ▼
                  PASS                      FAIL
                    │                         │
                    ▼                         ▼
              Pull Request               Pull Request
                 passes                    blocked
                    │
                    ▼
                  MERGE
````

---

# 4. AWS Authentication Architecture

The pipeline does **not** store permanent AWS access keys in GitHub Secrets.

Instead, GitHub Actions obtains a short-lived OIDC identity token and exchanges it with AWS STS for temporary credentials.

```text
                         ┌─────────────────────┐
                         │   GitHub Actions    │
                         │       Runner        │
                         └──────────┬──────────┘
                                    │
                                    │ OIDC Token
                                    ▼
                         ┌─────────────────────┐
                         │    GitHub OIDC      │
                         │     Provider        │
                         └──────────┬──────────┘
                                    │
                                    │ Identity Token
                                    ▼
                         ┌─────────────────────┐
                         │      AWS STS        │
                         │ AssumeRoleWith      │
                         │   WebIdentity       │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │      IAM Role       │
                         │                     │
                         │   Trust Policy      │
                         │        +            │
                         │ Permission Policy   │
                         └──────────┬──────────┘
                                    │
                                    │ Temporary
                                    │ Credentials
                                    ▼
                         ┌─────────────────────┐
                         │        AWS          │
                         │   S3 / AWS APIs     │
                         └─────────────────────┘
```

## Why OIDC?

Traditional CI/CD authentication often uses:

```text
GitHub Secrets
      │
      ▼
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
      │
      ▼
AWS
```

This creates long-lived credentials that must be protected, rotated, and eventually revoked.

This project instead uses:

```text
GitHub OIDC
      │
      ▼
AWS STS
      │
      ▼
Temporary Credentials
      │
      ▼
AWS
```

The GitHub Actions runner receives temporary credentials for the duration of the workflow.

---

# 5. OIDC Trust Policy

The IAM role trusts the GitHub Actions OIDC provider.

The trust relationship restricts which GitHub identity is allowed to assume the role.

Conceptually:

```text
GitHub Repository
       │
       │ OIDC identity
       ▼
AWS IAM OIDC Provider
       │
       │ Trust Policy
       ▼
GitHubActions-PlatformCompliance
       │
       ▼
Temporary AWS Credentials
```

The trust policy contains conditions similar to:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:<OWNER>/<REPOSITORY>:<REF>"
        }
      }
    }
  ]
}
```

The exact `sub` claim must match the identity presented by GitHub Actions.

---

# 6. IAM Authorization

Authentication answers:

> Who are you?

Authorization answers:

> What are you allowed to do?

The IAM role therefore has two important components.

```text
                    IAM ROLE
                       │
             ┌─────────┴─────────┐
             │                   │
             ▼                   ▼
       Trust Policy        Permission Policy
             │                   │
             │                   │
       Who can assume       What can the
          the role?         role actually do?
```

For example:

```text
Trust Policy
     │
     └── GitHub Actions may assume the role

Permission Policy
     │
     └── Role may manage the required S3 resources
```

This separation became especially important during troubleshooting.

---

# 7. Terraform Infrastructure

The Terraform portion of the project provisions an S3 bucket with security controls.

The infrastructure includes:

```text
                  AWS S3 Bucket
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
   Versioning     Encryption     Public Access
     Enabled       AWS KMS           Blocked
```

The Terraform configuration manages:

* S3 bucket
* S3 versioning
* S3 server-side encryption
* S3 public-access blocking
* resource tags

Example:

```hcl
resource "aws_s3_bucket" "compliance_demo" {
  bucket = "priest-platform-compliance-demo-417521971848"

  tags = {
    Name        = "platform-compliance-demo"
    Environment = "dev"
    Owner       = "Platform-Team"
  }
}
```

---

# 8. Terraform Remote State

Terraform state is not stored locally as the authoritative state.

The project uses an S3 backend:

```text
Developer / GitHub Actions
          │
          ▼
       Terraform
          │
          ▼
     S3 Backend
          │
          ▼
terraform.tfstate
```

The backend bucket is separate from the infrastructure bucket.

Example architecture:

```text
┌─────────────────────────────────────┐
│ Terraform State Bucket              │
│                                     │
│ priest-platform-compliance-tfstate  │
│                                     │
│ platform-compliance/                │
│     └── terraform.tfstate           │
└─────────────────────────────────────┘


┌─────────────────────────────────────┐
│ Application / Demo Bucket           │
│                                     │
│ priest-platform-compliance-demo     │
│                                     │
│ Versioning                          │
│ Encryption                          │
│ Public Access Blocking              │
└─────────────────────────────────────┘
```

This separation is important because Terraform's state backend and the infrastructure being managed serve different purposes.

---

# 9. Terraform State and Team Collaboration

Without a remote backend:

```text
Developer A
     │
     ▼
local terraform.tfstate

Developer B
     │
     ▼
different terraform.tfstate
```

This can result in inconsistent state.

With a shared backend:

```text
Developer A ─────┐
                 │
Developer B ─────┼──► S3 Remote State
                 │
GitHub Actions ──┘
```

Everyone works against the same authoritative Terraform state.

---

# 10. CI Workflow

The Pull Request workflow performs the following sequence:

```text
Pull Request
     │
     ▼
Checkout Repository
     │
     ▼
Configure AWS Credentials
     │
     ▼
Verify AWS Identity
     │
     ▼
Terraform Setup
     │
     ▼
Terraform fmt
     │
     ▼
Terraform validate
     │
     ▼
TFLint
     │
     ▼
Checkov
     │
     ▼
Terraform init
     │
     ▼
Terraform plan
     │
     ▼
tfplan
     │
     ▼
Convert Plan → JSON
     │
     ▼
OPA / Conftest
     │
     ▼
Compliance Gate
```

---

# 11. Why OPA Runs After Terraform Plan

OPA / Conftest is checking the **actual Terraform change that is about to be applied**.

Therefore:

```text
Terraform Configuration
          │
          ▼
    Terraform Plan
          │
          ▼
       tfplan
          │
          ▼
     tfplan.json
          │
          ▼
    OPA / Conftest
          │
          ▼
   Compliance Decision
```

This is important.

Terraform configuration describes what the developer requested.

Terraform plan describes what Terraform intends to do.

OPA / Conftest can therefore evaluate the resulting infrastructure change rather than only inspecting source files.

---

# 12. Security Scanning vs Compliance Policy

These tools serve different purposes.

## TFLint

TFLint focuses primarily on Terraform-specific linting and potential configuration problems.

```text
Terraform Code
      │
      ▼
    TFLint
      │
      ▼
Linting Result
```

---

## Checkov

Checkov performs security-oriented Infrastructure-as-Code scanning.

Example:

```text
Terraform Code
      │
      ▼
    Checkov
      │
      ▼
Security Findings
```

It can detect insecure configurations such as public S3 access or missing encryption controls.

---

## OPA / Conftest

OPA / Conftest enforces **organization-specific policies**.

For example:

```text
Every S3 bucket must have:

Owner
Environment
Name
```

or:

```text
Production resources
must not be publicly accessible.
```

This allows the platform team to define organizational rules independently from Terraform.

---

# 13. Compliance Gate

The compliance gate is the point where the workflow makes a deployment decision.

```text
                         OPA / Conftest
                                │
                                ▼
                       ┌──────────────────┐
                       │ COMPLIANCE GATE  │
                       └────────┬─────────┘
                                │
                   ┌────────────┴────────────┐
                   │                         │
                   ▼                         ▼
                 PASS                      FAIL
                   │                         │
                   ▼                         ▼
              PR allowed                 PR blocked
                   │
                   ▼
                 MERGE
```

A policy failure causes Conftest to return a non-zero exit code.

GitHub Actions interprets that as a failed step.

Therefore the Pull Request cannot proceed through the compliance workflow.

---

# 14. Intentional Compliance Failure

One of the demonstrations intentionally removed the required `Owner` tag.

The policy expected:

```text
Owner
Environment
Name
```

The failing workflow produced:

```text
FAIL - tfplan.json - terraform -
Resource aws_s3_bucket.compliance_demo must have an Owner tag
```

This demonstrated that the compliance gate was actually enforcing policy.

The important point was not simply:

> "The pipeline succeeded."

It was:

> "The pipeline correctly failed when infrastructure violated organizational policy."

After restoring the required tag:

```text
Owner = "Platform-Team"
```

the compliance tests passed.

---

# 15. Real Troubleshooting: OIDC Trust Policy

During deployment we encountered:

```text
Could not assume role with OIDC:

Not authorized to perform:
sts:AssumeRoleWithWebIdentity
```

The workflow could not obtain AWS credentials.

The problem was not Terraform.

The problem was AWS IAM trust configuration.

The authentication flow was:

```text
GitHub Actions
      │
      │ OIDC Token
      ▼
AWS STS
      │
      │ AssumeRoleWithWebIdentity
      ▼
IAM Role
      │
      X
   DENIED
```

The IAM trust relationship did not correctly match the identity being presented by GitHub Actions.

After correcting the trust relationship, the workflow successfully assumed:

```text
GitHubActions-PlatformCompliance
```

and AWS identity verification succeeded.

---

# 16. Real Troubleshooting: IAM Permission Failure

After OIDC authentication was working, Terraform reached AWS but failed during deployment.

Example:

```text
AccessDenied:

User:
arn:aws:sts::<ACCOUNT_ID>:assumed-role/
GitHubActions-PlatformCompliance/GitHubActions

is not authorized to perform:

s3:CreateBucket
```

This was an important distinction.

OIDC authentication was working.

AWS knew who the workflow was.

The problem was authorization.

```text
OIDC Authentication
        │
        ▼
IAM Role Assumed
        │
        ▼
Permission Policy
        │
        X
   Missing Permission
```

We therefore added the required S3 permissions to the IAM role.

---

# 17. Real Troubleshooting: Terraform State Access

The pipeline also encountered:

```text
Error refreshing state:

Unable to access object
"platform-compliance/terraform.tfstate"

StatusCode: 403
```

The workflow could authenticate to AWS, but the IAM role did not have sufficient permissions to access the Terraform backend state.

This demonstrated another important DevOps principle:

> Access to AWS is not the same thing as access to every AWS resource.

The workflow required permissions for both:

```text
Terraform Backend
        +
Terraform Managed Resources
```

Conceptually:

```text
                 GitHub Actions
                       │
                       ▼
                    IAM Role
                       │
              ┌────────┴────────┐
              │                 │
              ▼                 ▼
        Terraform State     Managed AWS
             S3              Resources
```

---

# 18. Real Troubleshooting: Terraform Import

During the troubleshooting process, the S3 infrastructure already existed in AWS while Terraform state did not contain all corresponding resources.

We verified the existing bucket:

```bash
aws s3api head-bucket \
  --bucket priest-platform-compliance-demo-417521971848
```

Terraform initially did not know about the existing bucket.

We imported it:

```bash
terraform import aws_s3_bucket.compliance_demo \
  priest-platform-compliance-demo-417521971848
```

Then verified:

```bash
terraform state list
```

which showed:

```text
aws_s3_bucket.compliance_demo
```

This is an important Terraform concept:

> `terraform import` brings an existing real-world resource under Terraform management by adding it to Terraform state.

---

# 19. Real Troubleshooting: Terraform State Verification

We verified that the remote backend contained the state:

```bash
terraform state pull | head -c 500
```

We also verified the backend object directly:

```bash
aws s3api list-objects-v2 \
  --bucket priest-platform-compliance-tfstate-417521971848 \
  --prefix platform-compliance/
```

The backend contained:

```text
platform-compliance/terraform.tfstate
```

This confirmed that remote state was actually being stored in S3.

---

# 20. Real Troubleshooting: Terraform Refresh Permissions

Terraform refreshes managed resources during `terraform plan`.

Because the Terraform resource was an S3 bucket, Terraform needed to read multiple aspects of the bucket.

The IAM role initially lacked several read permissions.

We encountered errors involving permissions such as:

```text
s3:GetBucketPolicy
s3:GetBucketCORS
s3:GetBucketWebsite
s3:GetAccelerateConfiguration
s3:GetBucketRequestPayment
s3:GetBucketLogging
s3:GetLifecycleConfiguration
s3:GetReplicationConfiguration
s3:GetObjectLockConfiguration
```

The lesson was extremely important:

> Terraform does not only need permission to create a resource. It also needs permission to read and manage the resource during refresh and planning.

The final IAM permission policy was expanded to support the Terraform resource lifecycle.

---

# 21. Why Terraform Plan Needed More Permissions

The following sequence occurs during a Terraform plan:

```text
terraform plan
      │
      ▼
Refresh Terraform State
      │
      ▼
Query AWS
      │
      ├── Bucket metadata
      ├── Bucket policy
      ├── CORS
      ├── Website configuration
      ├── Logging
      ├── Lifecycle
      ├── Replication
      ├── Encryption
      ├── Versioning
      └── Other configuration
      │
      ▼
Compare AWS State
with
Terraform Configuration
      │
      ▼
Generate Plan
```

Therefore, least-privilege IAM must account for the operations Terraform performs during both:

* refresh
* plan
* apply

---

# 22. Final IAM Permission Model

The final model is:

```text
                 GitHub Actions
                       │
                       │ OIDC
                       ▼
                    AWS STS
                       │
                       ▼
        ┌─────────────────────────────┐
        │ GitHubActions-Platform      │
        │ Compliance IAM Role         │
        └──────────────┬──────────────┘
                       │
              ┌────────┴─────────┐
              │                  │
              ▼                  ▼
       Backend Permissions   Infrastructure
              │              Permissions
              │                  │
              ▼                  ▼
        Terraform State       S3 Bucket
              S3                  │
                                  ├── Create
                                  ├── Read
                                  ├── Versioning
                                  ├── Encryption
                                  ├── Public Access
                                  └── Tags
```

The permissions should remain as narrow as practical.

---

# 23. Production-Style Deployment Flow

After the compliance workflow passes, the Pull Request can be merged.

The deployment workflow then executes.

```text
                         ┌─────────────────┐
                         │   Pull Request  │
                         │      PASS       │
                         └────────┬────────┘
                                  │
                                  ▼
                              ┌───────┐
                              │ MERGE │
                              └───┬───┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │      main       │
                         └────────┬────────┘
                                  │
                                  ▼
                       ┌─────────────────────┐
                       │   GitHub Actions    │
                       │   Deploy Workflow   │
                       └──────────┬──────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ Terraform Plan  │
                         └────────┬────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ Terraform Apply │
                         └────────┬────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │       AWS       │
                         │   S3 Bucket     │
                         └─────────────────┘
```

This creates the production-style lifecycle:

```text
Code
 │
 ▼
Pull Request
 │
 ▼
Security Checks
 │
 ▼
Compliance
 │
 ▼
Approval
 │
 ▼
Merge
 │
 ▼
Deployment
 │
 ▼
AWS
```

---

# 24. Final Deployment Verification

After deployment, the infrastructure was independently verified using the AWS CLI.

## Verify bucket exists

```bash
aws s3api head-bucket \
  --bucket priest-platform-compliance-demo-417521971848
```

Expected result:

```json
{
    "BucketArn": "arn:aws:s3:::priest-platform-compliance-demo-417521971848",
    "BucketRegion": "us-east-1",
    "AccessPointAlias": false
}
```

---

## Verify versioning

```bash
aws s3api get-bucket-versioning \
  --bucket priest-platform-compliance-demo-417521971848
```

Expected:

```json
{
    "Status": "Enabled"
}
```

---

## Verify public access blocking

```bash
aws s3api get-public-access-block \
  --bucket priest-platform-compliance-demo-417521971848
```

Expected:

```json
{
    "PublicAccessBlockConfiguration": {
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }
}
```

---

## Verify encryption

```bash
aws s3api get-bucket-encryption \
  --bucket priest-platform-compliance-demo-417521971848
```

The deployed bucket uses:

```text
SSEAlgorithm = aws:kms
```

This independently confirms that the security controls defined in Terraform were actually deployed to AWS.

---

# 25. End-to-End Production Flow

The complete system can now be represented as:

```text
                         ┌─────────────────┐
                         │    Developer    │
                         └────────┬────────┘
                                  │
                                  │ Pull Request
                                  ▼
                         ┌─────────────────┐
                         │     GitHub      │
                         │       PR        │
                         └────────┬────────┘
                                  │
                                  ▼
                       ┌─────────────────────┐
                       │   GitHub Actions    │
                       └──────────┬──────────┘
                                  │
                                  ▼
                         GitHub OIDC Token
                                  │
                                  ▼
                             AWS STS
                                  │
                                  ▼
                              IAM Role
                                  │
                                  ▼
                         Temporary Credentials
                                  │
                                  ▼
              ┌───────────────────────────────────┐
              │         CI SECURITY GATES         │
              │                                   │
              │ Terraform fmt                     │
              │ Terraform validate                │
              │ TFLint                            │
              │ Checkov                           │
              │ Terraform plan                    │
              │ OPA / Conftest                    │
              └─────────────────┬─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │ COMPLIANCE GATE  │
                       └────────┬─────────┘
                                │
                   ┌────────────┴────────────┐
                   │                         │
                   ▼                         ▼
                 PASS                      FAIL
                   │                         │
                   ▼                         ▼
              PR Approved               PR Blocked
                   │
                   ▼
                 MERGE
                   │
                   ▼
              ┌──────────┐
              │   main   │
              └────┬─────┘
                   │
                   ▼
          GitHub Actions Deploy
                   │
                   ▼
           Terraform Apply
                   │
                   ▼
                 AWS
                   │
                   ▼
              S3 Resource
```

---

# 26. Repository Structure

A simplified repository structure:

```text
priest-aws-platform-compliance-demo/
│
├── .github/
│   └── workflows/
│       ├── terraform-pr.yml
│       └── terraform-apply.yml
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── backend.tf
│   ├── terraform.tfvars
│   └── .terraform.lock.hcl
│
├── policies/
│   └── terraform/
│       └── ...
│
├── README.md
│
└── ...
```

---

# 27. Important Workflow Separation

The project uses two conceptual workflows.

## Pull Request Workflow

Purpose:

> Decide whether infrastructure is safe and compliant enough to merge.

```text
PR
 │
 ├── fmt
 ├── validate
 ├── TFLint
 ├── Checkov
 ├── plan
 └── OPA / Conftest
          │
          ▼
     Compliance Gate
```

It should **not deploy production infrastructure**.

---

## Deployment Workflow

Purpose:

> Deploy the already-approved infrastructure change.

```text
main
 │
 ▼
Terraform Init
 │
 ▼
Terraform Plan
 │
 ▼
Terraform Apply
 │
 ▼
AWS
```

This separation is important in production because code review and deployment are different responsibilities.

---

# 28. Security Model

The project intentionally avoids long-lived AWS credentials.

```text
                 ❌ NOT USED
       AWS Access Key Secrets
                  │
                  X


                 ✅ USED
            GitHub OIDC
                  │
                  ▼
             AWS STS
                  │
                  ▼
        Temporary Credentials
                  │
                  ▼
              IAM Role
                  │
                  ▼
                 AWS
```

Benefits include:

* no permanent AWS access keys stored in GitHub
* short-lived credentials
* IAM-controlled authorization
* repository/branch/PR identity restrictions
* centralized auditability through AWS
* reduced credential exposure

---

# 29. Compliance Model

The compliance model is:

```text
                    Terraform Code
                         │
                         ▼
                 Security Scanning
                    Checkov
                         │
                         ▼
                  Terraform Plan
                         │
                         ▼
                    tfplan.json
                         │
                         ▼
                   OPA / Conftest
                         │
                         ▼
                 Organizational Policy
                         │
                         ▼
                  Compliance Decision
```

This is an example of **Policy as Code**.

Instead of relying on a human reviewer to remember every organizational requirement, policies become executable rules.

---

# 30. Why This Is a Platform Engineering Pattern

A Platform Engineering team can provide a standardized infrastructure delivery path:

```text
Developer
    │
    │ Terraform
    ▼
Platform CI/CD
    │
    ├── Security
    ├── Compliance
    ├── Policy
    ├── Authentication
    └── Deployment
    │
    ▼
Approved AWS Infrastructure
```

The developer does not need to manually:

* create AWS credentials
* configure AWS authentication
* run Checkov
* run TFLint
* run OPA
* manually inspect every compliance requirement
* manually deploy the infrastructure

The platform provides the paved road.

---

# 31. Challenges Encountered

This project intentionally documents the problems encountered while building the implementation.

## Challenge 1 — OIDC AssumeRole Failure

### Symptom

```text
Not authorized to perform:
sts:AssumeRoleWithWebIdentity
```

### Cause

The IAM role trust relationship did not correctly match the GitHub Actions identity.

### Resolution

The OIDC trust relationship was corrected so that the GitHub Actions identity matched the expected repository/ref conditions.

### Lesson

OIDC requires both:

```text
Correct OIDC Provider
        +
Correct Trust Policy
```

---

# 32. Challenge 2 — S3 CreateBucket AccessDenied

### Symptom

```text
not authorized to perform:
s3:CreateBucket
```

### Cause

The IAM role could be assumed successfully, but its permission policy did not allow S3 bucket creation.

### Resolution

Added the required S3 permission:

```text
s3:CreateBucket
```

### Lesson

Successful authentication does not automatically provide authorization.

---

# 33. Challenge 3 — Terraform Backend 403

### Symptom

```text
Unable to access object
"platform-compliance/terraform.tfstate"

StatusCode: 403
```

### Cause

The GitHub Actions IAM role did not have sufficient access to the S3 Terraform state backend.

### Resolution

Added the necessary permissions for Terraform to access its remote state.

### Lesson

Terraform needs access to:

```text
Remote State
     +
Managed Infrastructure
```

---

# 34. Challenge 4 — Terraform Plan Read Permissions

### Symptom

Terraform plan repeatedly failed with errors such as:

```text
s3:GetBucketPolicy
s3:GetBucketCORS
s3:GetBucketWebsite
s3:GetAccelerateConfiguration
s3:GetBucketRequestPayment
s3:GetBucketLogging
s3:GetLifecycleConfiguration
s3:GetReplicationConfiguration
s3:GetObjectLockConfiguration
```

### Cause

Terraform was refreshing the existing S3 resource and attempting to read configuration that the IAM role was not yet allowed to access.

### Resolution

The IAM policy was incrementally expanded with the required read permissions.

### Lesson

Terraform permissions must support the entire resource lifecycle:

```text
Create
  │
  ▼
Read / Refresh
  │
  ▼
Plan
  │
  ▼
Update
  │
  ▼
Destroy
```

Least privilege should be designed around the actual Terraform operations rather than only the initial `Create` action.

---

# 35. Challenge 5 — Existing Resource / Terraform State

The S3 bucket existed in AWS but was not initially represented in the Terraform state.

We verified the resource:

```bash
aws s3api head-bucket \
  --bucket priest-platform-compliance-demo-417521971848
```

Then imported it:

```bash
terraform import aws_s3_bucket.compliance_demo \
  priest-platform-compliance-demo-417521971848
```

We verified Terraform state:

```bash
terraform state list
```

Result:

```text
aws_s3_bucket.compliance_demo
```

### Lesson

Terraform state represents Terraform's knowledge of infrastructure.

A resource existing in AWS does not automatically mean Terraform manages it.

---

# 36. Challenge 6 — Compliance Policy Failure

The OPA policy intentionally detected a missing `Owner` tag.

```text
Resource aws_s3_bucket.compliance_demo
must have an Owner tag
```

The workflow failed.

After restoring:

```hcl
Owner = "Platform-Team"
```

the compliance tests returned:

```text
2 tests, 2 passed, 0 warnings, 0 failures, 0 exceptions
```

### Lesson

A failed compliance pipeline is not necessarily a bad outcome.

A properly designed compliance pipeline should fail when policy is violated.

---

# 37. Final Successful State

The final implementation successfully demonstrated:

```text
                    GitHub PR
                       │
                       ▼
                 GitHub Actions
                       │
                       ▼
                  GitHub OIDC
                       │
                       ▼
                    AWS STS
                       │
                       ▼
                    IAM Role
                       │
                       ▼
              Temporary Credentials
                       │
                       ▼
             ┌───────────────────┐
             │ Security Pipeline │
             └─────────┬─────────┘
                       │
             ┌─────────┼─────────┐
             │         │         │
             ▼         ▼         ▼
          TFLint    Checkov    Terraform
                                Plan
                                  │
                                  ▼
                              OPA/Conftest
                                  │
                                  ▼
                           Compliance Gate
                                  │
                                  ▼
                                PASS
                                  │
                                  ▼
                                MERGE
                                  │
                                  ▼
                           Terraform Apply
                                  │
                                  ▼
                                AWS
```

The infrastructure was independently verified using the AWS CLI.

---

# 38. AWS Verification

The final S3 bucket was confirmed to have:

```text
✓ Bucket exists
✓ Versioning enabled
✓ Public access blocked
✓ Server-side encryption enabled
✓ Terraform-managed configuration
✓ Successfully deployed through GitHub Actions
```

Example verification commands:

```bash
aws s3api head-bucket \
  --bucket priest-platform-compliance-demo-417521971848
```

```bash
aws s3api get-bucket-versioning \
  --bucket priest-platform-compliance-demo-417521971848
```

```bash
aws s3api get-public-access-block \
  --bucket priest-platform-compliance-demo-417521971848
```

```bash
aws s3api get-bucket-encryption \
  --bucket priest-platform-compliance-demo-417521971848
```

---

# 39. Key Concepts to Understand

Someone reviewing this project should understand the following concepts.

### Terraform

* Infrastructure as Code
* Terraform state
* Remote backend
* Terraform plan
* Terraform apply
* Resource lifecycle
* Import
* Provider
* Dependency lock file

### AWS

* IAM
* IAM roles
* IAM trust policies
* IAM permission policies
* STS
* OIDC
* S3
* S3 encryption
* S3 versioning
* S3 public access blocking

### GitHub

* Pull Requests
* Branches
* GitHub Actions
* Workflow jobs
* GitHub-hosted runners
* OIDC tokens
* Repository/ref claims

### DevSecOps

* Shift-left security
* Infrastructure security scanning
* Policy as Code
* Compliance gates
* Least privilege
* Temporary credentials
* Automated deployment

### Tools

* TFLint
* Checkov
* OPA
* Conftest

---

# 40. Commands Used During the Project

## Terraform

```bash
terraform fmt
```

```bash
terraform validate
```

```bash
terraform init
```

```bash
terraform plan
```

```bash
terraform plan -out=tfplan
```

```bash
terraform apply -auto-approve tfplan
```

```bash
terraform state list
```

```bash
terraform state pull
```

```bash
terraform import \
  aws_s3_bucket.compliance_demo \
  priest-platform-compliance-demo-417521971848
```

---

## AWS

Verify bucket:

```bash
aws s3api head-bucket \
  --bucket priest-platform-compliance-demo-417521971848
```

Verify versioning:

```bash
aws s3api get-bucket-versioning \
  --bucket priest-platform-compliance-demo-417521971848
```

Verify public access:

```bash
aws s3api get-public-access-block \
  --bucket priest-platform-compliance-demo-417521971848
```

Verify encryption:

```bash
aws s3api get-bucket-encryption \
  --bucket priest-platform-compliance-demo-417521971848
```

Verify Terraform state:

```bash
aws s3api list-objects-v2 \
  --bucket priest-platform-compliance-tfstate-417521971848 \
  --prefix platform-compliance/
```

---

# 41. What Happens When a Developer Makes a Bad Change?

Suppose a developer changes:

```hcl
tags = {
  Name        = "platform-compliance-demo"
  Environment = "dev"
}
```

and removes:

```hcl
Owner = "Platform-Team"
```

The pipeline becomes:

```text
Developer
    │
    ▼
Pull Request
    │
    ▼
Terraform Plan
    │
    ▼
tfplan.json
    │
    ▼
OPA / Conftest
    │
    ▼
Policy Violation
    │
    ▼
FAIL
    │
    ▼
Pull Request BLOCKED
```

The infrastructure never reaches the deployment workflow.

That is the purpose of the compliance gate.

---

# 42. What Happens When the Change Is Correct?

```text
Developer
    │
    ▼
Pull Request
    │
    ▼
Terraform Checks
    │
    ▼
Security Checks
    │
    ▼
Terraform Plan
    │
    ▼
OPA / Conftest
    │
    ▼
COMPLIANCE GATE
    │
    ▼
PASS
    │
    ▼
Pull Request Approved
    │
    ▼
MERGE
    │
    ▼
Terraform Apply
    │
    ▼
AWS
```

This is the desired path.

---

# 43. Why This Is Better Than Manual Infrastructure Deployment

Manual:

```text
Developer
    │
    ▼
AWS Console / CLI
    │
    ▼
Create Infrastructure
    │
    ▼
Hope Configuration Is Secure
```

Automated:

```text
Developer
    │
    ▼
Terraform
    │
    ▼
Pull Request
    │
    ▼
Security
    │
    ▼
Compliance
    │
    ▼
Review
    │
    ▼
Merge
    │
    ▼
Automated Deployment
```

The second approach provides:

* repeatability
* auditability
* security controls
* policy enforcement
* peer review
* version control
* consistent deployments
* reduced human error

---

# 44. Production Considerations

This demo intentionally uses a relatively small infrastructure footprint.

A larger production implementation could add:

```text
                    Production Platform
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
   Multiple AWS       Multiple Envs       Multiple
    Accounts          dev/stage/prod       Regions
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                           ▼
                    Centralized CI/CD
                           │
                           ▼
                     Policy Engine
                           │
                           ▼
                       Deployment
```

Additional production capabilities could include:

* AWS Organizations
* separate AWS accounts
* environment-specific IAM roles
* GitHub Environments
* protected branches
* required reviewers
* Terraform modules
* state locking
* centralized policy repositories
* drift detection
* artifact retention
* security dashboards
* CloudTrail monitoring
* centralized logging
* approval gates
* automated rollback strategies

---

# 45. Jenkins Implementation — Next Phase

The GitHub Actions implementation is the first version of the platform compliance pipeline.

The next phase is to reproduce the same architecture using Jenkins.

The objective is to demonstrate that the **engineering pattern is independent of the CI/CD platform**.

```text
                 SAME TERRAFORM CODE
                         │
              ┌──────────┴──────────┐
              │                     │
              ▼                     ▼
       GitHub Actions             Jenkins
              │                     │
              ├── TFLint            ├── TFLint
              ├── Checkov           ├── Checkov
              ├── Terraform Plan    ├── Terraform Plan
              └── OPA/Conftest      └── OPA/Conftest
              │                     │
              └──────────┬──────────┘
                         │
                         ▼
                    AWS Infrastructure
```

The Jenkins version will allow comparison of:

* GitHub Actions OIDC
* Jenkins AWS authentication
* credentials management
* pipeline syntax
* security gates
* Terraform execution
* deployment controls

---

# 46. Project Milestones

## Phase 1 — Terraform

```text
✓ Terraform configuration
✓ AWS S3 infrastructure
✓ Terraform state
```

## Phase 2 — Security & Compliance

```text
✓ TFLint
✓ Checkov
✓ OPA / Conftest
✓ Compliance policy
✓ Compliance failure demonstration
```

## Phase 3 — GitHub Actions

```text
✓ PR workflow
✓ Terraform validation
✓ Security scanning
✓ Terraform plan
✓ Compliance gate
```

## Phase 4 — AWS OIDC

```text
✓ GitHub OIDC provider
✓ IAM trust relationship
✓ AWS STS
✓ Temporary credentials
✓ IAM permission policy
```

## Phase 5 — Deployment

```text
✓ Merge to main
✓ Terraform Apply
✓ AWS deployment
✓ AWS CLI verification
```

## Phase 6 — Jenkins

```text
→ Duplicate implementation
→ Jenkins pipeline
→ AWS authentication
→ Security checks
→ Compliance gate
→ Terraform deployment
```

---

# 47. Interview Explanation

A concise way to explain this project in an interview:

> "I built a Terraform-based AWS platform compliance pipeline using GitHub Actions. Pull requests trigger Terraform formatting and validation, TFLint, Checkov, and a Terraform plan. The resulting plan is converted to JSON and evaluated using OPA and Conftest against organizational policies. GitHub Actions authenticates to AWS using GitHub OIDC and AWS STS, so there are no long-lived AWS access keys stored in the CI system. If the compliance gate fails, the Pull Request is blocked. Once the change is approved and merged, a deployment workflow assumes the same type of IAM role and runs Terraform Apply. Terraform state is stored remotely in S3. I also intentionally introduced policy and IAM failures to validate that the security and compliance controls actually worked."

---

# 48. Lessons Learned

The most important lessons from this implementation were:

### 1. Authentication and authorization are different

Successfully assuming an IAM role does not mean that the role has permission to perform the required AWS actions.

### 2. Terraform needs read permissions

Terraform does not simply create resources.

It continuously refreshes infrastructure state and therefore needs appropriate read permissions.

### 3. Compliance should be executable

OPA / Conftest turns organizational requirements into automated policy.

### 4. A failed pipeline can be a successful test

The intentional `Owner` tag failure proved that the compliance gate was functioning.

### 5. Remote state is part of the security model

Terraform's backend requires its own access controls.

### 6. CI/CD credentials should be short-lived

OIDC + STS removes the need for long-lived AWS access keys.

### 7. Infrastructure changes should be reviewed like application code

Pull Requests provide:

* visibility
* review
* audit history
* automated validation
* compliance enforcement

---

# 49. Final Architecture Summary

```text
                         DEVELOPER
                             │
                             ▼
                       GitHub Pull Request
                             │
                             ▼
                    ┌───────────────────┐
                    │   GitHub Actions  │
                    └─────────┬─────────┘
                              │
                              │ OIDC
                              ▼
                         AWS STS
                              │
                              ▼
                          IAM ROLE
                              │
                              ▼
                    Temporary Credentials
                              │
                              ▼
              ┌──────────────────────────────┐
              │       SECURITY PIPELINE      │
              │                              │
              │ Terraform fmt                │
              │ Terraform validate           │
              │ TFLint                       │
              │ Checkov                      │
              │ Terraform plan               │
              │ OPA / Conftest               │
              └──────────────┬───────────────┘
                             │
                             ▼
                    COMPLIANCE GATE
                       /          \
                    PASS          FAIL
                     │              │
                     ▼              ▼
                   MERGE          BLOCK
                     │
                     ▼
                  main branch
                     │
                     ▼
              Terraform Apply
                     │
                     ▼
                    AWS
                     │
                     ▼
              ┌───────────────┐
              │   S3 Bucket   │
              │               │
              │ Encryption    │
              │ Versioning    │
              │ Public Block  │
              │ Tags          │
              └───────────────┘
```

---

# 50. Current Project Status

### GitHub Actions Implementation

**Completed**

```text
✓ Terraform Infrastructure
✓ S3 Remote State
✓ GitHub Actions CI
✓ GitHub OIDC Authentication
✓ AWS STS
✓ IAM Role
✓ IAM Trust Policy
✓ IAM Permission Policy
✓ Terraform fmt
✓ Terraform validate
✓ TFLint
✓ Checkov
✓ Terraform Plan
✓ tfplan artifact
✓ OPA / Conftest
✓ Compliance Gate
✓ Intentional Compliance Failure
✓ Pull Request Review
✓ Merge
✓ Terraform Apply
✓ AWS Deployment
✓ AWS CLI Verification
✓ Troubleshooting Documentation
```

### Jenkins Implementation

**Next Phase**

```text
→ Duplicate the project for Jenkins
→ Implement equivalent CI/CD pipeline
→ Configure Jenkins AWS authentication
→ Implement Terraform security gates
→ Implement OPA / Conftest
→ Implement deployment
→ Compare Jenkins vs GitHub Actions
```

---

# 51. Final Takeaway

This project demonstrates a complete DevSecOps infrastructure delivery lifecycle:

```text
CODE
  │
  ▼
PULL REQUEST
  │
  ▼
AUTHENTICATE SECURELY
  │
  ▼
VALIDATE
  │
  ▼
SCAN
  │
  ▼
PLAN
  │
  ▼
CHECK POLICY
  │
  ▼
COMPLIANCE GATE
  │
  ├───────────────┐
  │               │
  ▼               ▼
PASS             FAIL
  │               │
  ▼               ▼
MERGE           BLOCK
  │
  ▼
DEPLOY
  │
  ▼
AWS
  │
  ▼
VERIFY
```

The goal is not simply to automate Terraform.

The goal is to create a **controlled infrastructure delivery platform** where security, compliance, review, authentication, authorization, and deployment are integrated into the engineering workflow.

---

<div align="center">

## 🚀 GitHub Actions Implementation Complete

**Next Phase: Jenkins Implementation**

</div>
```

