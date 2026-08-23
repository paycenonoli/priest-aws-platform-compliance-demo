
````markdown
# AWS Platform Compliance CI/CD Demo

A production-inspired DevSecOps / Platform Engineering demonstration showing how to integrate:

- GitHub Pull Requests
- GitHub Actions
- GitHub OIDC authentication
- AWS IAM
- AWS STS
- Terraform
- TFLint
- Checkov
- OPA / Conftest
- Policy-as-Code
- Terraform Plan
- CI/CD compliance gates

The purpose of this project is to demonstrate how a Platform Engineer can enforce infrastructure security and organizational compliance **before infrastructure changes are merged**.

---

# 1. Project Objective

This project demonstrates the following workflow:

```text
Developer
    │
    ▼
GitHub Pull Request
    │
    ▼
GitHub Actions
    │
    ├── OIDC Authentication
    │       │
    │       ▼
    │   AWS STS
    │       │
    │       ▼
    │   IAM Role
    │       │
    │       ▼
    │ Temporary Credentials
    │
    ├── Terraform fmt
    ├── Terraform validate
    ├── TFLint
    ├── Checkov
    ├── Terraform plan
    │       │
    │       ▼
    │   tfplan.json
    │       │
    │       ▼
    └── OPA / Conftest
            │
            ▼
      COMPLIANCE GATE
         /       \
      PASS       FAIL
       │           │
       ▼           ▼
     Merge       Block
````

The central idea is:

> **Infrastructure changes should be automatically validated for security and organizational compliance before they are allowed to merge.**

---

# 2. Why This Project Matters

This architecture represents a common enterprise Platform Engineering / DevSecOps pattern.

A developer should not be able to submit arbitrary infrastructure such as:

```hcl
resource "aws_s3_bucket" "example" {
  bucket = "example"
}
```

and immediately deploy it.

Instead, the CI/CD platform should automatically verify:

```text
Is the Terraform valid?
        ↓
Are there Terraform/provider issues?
        ↓
Does the infrastructure violate security best practices?
        ↓
Does it violate organizational policies?
        ↓
If compliant → allow merge
If non-compliant → block merge
```

This is an example of:

* Shift-left security
* Shift-left compliance
* Infrastructure as Code governance
* Policy-as-Code
* DevSecOps
* Continuous compliance
* CI/CD enforcement

---

# 3. Technologies Used

| Technology     | Purpose                                                     |
| -------------- | ----------------------------------------------------------- |
| GitHub         | Source control and Pull Requests                            |
| GitHub Actions | CI/CD automation                                            |
| GitHub OIDC    | Passwordless authentication to AWS                          |
| AWS IAM        | Identity and authorization                                  |
| AWS STS        | Issues temporary AWS credentials                            |
| Terraform      | Infrastructure as Code                                      |
| TFLint         | Terraform linting                                           |
| Checkov        | Infrastructure security scanning                            |
| OPA            | Policy engine                                               |
| Conftest       | Executes OPA policies against configuration/data            |
| AWS S3         | Example infrastructure resource                             |
| KIND           | Optional local Kubernetes environment for future extensions |

---

# 4. High-Level Architecture

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
                   │              │              │
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
```

---

# 5. GitHub → AWS Authentication Architecture

This project deliberately avoids storing long-lived AWS access keys in GitHub.

Instead, GitHub Actions uses OpenID Connect (OIDC).

```text
                       GitHub Actions
                             │
                             │ 1. Request OIDC token
                             ▼
                  GitHub OIDC Provider
                             │
                             │ 2. JWT/OIDC token
                             ▼
                        AWS STS
                             │
                             │ 3. AssumeRoleWithWebIdentity
                             ▼
                      IAM Trust Policy
                             │
                             │ Validate claims
                             │
                             │ ✓ Issuer
                             │ ✓ Audience
                             │ ✓ Repository
                             │ ✓ Repository ID
                             │ ✓ Workflow context
                             ▼
                         IAM Role
                             │
                             ▼
                  Temporary AWS Credentials
                             │
                             ▼
                         Terraform
                             │
                             ▼
                            AWS
```

---

# 6. Why OIDC Instead of AWS Access Keys?

A traditional approach would be:

```text
GitHub Actions
      │
      ▼
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
      │
      ▼
AWS
```

This requires storing long-lived credentials.

The OIDC approach is:

```text
GitHub Actions
      │
      ▼
OIDC token
      │
      ▼
AWS STS
      │
      ▼
Temporary credentials
      │
      ▼
AWS
```

Advantages:

* No long-lived AWS secret stored in GitHub
* Credentials are temporary
* IAM controls exactly who can assume the role
* Trust can be restricted to a specific repository
* Trust can be restricted to specific workflow contexts
* Better security posture
* Easier credential rotation because there are no permanent CI credentials to rotate

---

# 7. AWS OIDC Identity Provider

The AWS IAM OIDC provider was created using:

```text
Provider type:
OpenID Connect

Provider URL:
https://token.actions.githubusercontent.com

Audience:
sts.amazonaws.com
```

Conceptually:

```text
AWS IAM
   │
   └── Identity Provider
          │
          └── token.actions.githubusercontent.com
```

The OIDC provider tells AWS:

> "GitHub is an identity provider whose tokens AWS can validate."

The provider itself does NOT grant GitHub permissions.

It establishes the identity federation relationship.

---

# 8. IAM Role

The project uses an IAM role similar to:

```text
GitHubActions-PlatformCompliance
```

The role has two important components:

```text
IAM Role
   │
   ├── Trust Policy
   │
   └── Permissions Policy
```

These solve two different problems.

## Trust Policy

Answers:

> Who is allowed to assume this role?

## Permissions Policy

Answers:

> What can the assumed role do?

This distinction is extremely important.

---

# 9. IAM Trust Policy

The role's trust policy allows GitHub's OIDC identity to assume the role through:

```text
sts:AssumeRoleWithWebIdentity
```

Example structure:

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
          "token.actions.githubusercontent.com:sub": "<EXPECTED_GITHUB_SUBJECT>"
        }
      }
    }
  ]
}
```

The important condition is:

```text
aud = sts.amazonaws.com
```

and the repository-specific:

```text
sub = expected GitHub identity
```

---

# 10. Important GitHub OIDC `sub` Discovery

During this project, the initial trust policy failed.

The error was:

```text
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

Instead of blindly changing permissions, the GitHub OIDC claims were inspected.

The actual token contained a subject similar to:

```text
repo:paycenonoli@<OWNER_ID>/priest-aws-platform-compliance-demo@<REPOSITORY_ID>:pull_request
```

This is important because GitHub has introduced immutable subject formats for newer repositories.

Therefore:

> **Do not blindly assume that the OIDC `sub` will always look like the older `repo:OWNER/REPOSITORY:pull_request` format.**

Always verify the actual claims when troubleshooting OIDC.

---

# 11. Troubleshooting OIDC Authentication

If GitHub reports:

```text
Could not assume role with OIDC:
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

check these in order:

```text
1. Does the IAM OIDC provider exist?
            ↓
2. Is the provider URL correct?
            ↓
3. Is the audience sts.amazonaws.com?
            ↓
4. Does the GitHub workflow have:
       id-token: write
            ↓
5. Is the role ARN correct?
            ↓
6. What is the actual OIDC `sub` claim?
            ↓
7. Does the IAM trust policy match the `sub`?
            ↓
8. Does the trust policy allow:
       sts:AssumeRoleWithWebIdentity?
```

Do not immediately attach `AdministratorAccess`.

Authentication and authorization are separate problems.

---

# 12. GitHub Actions OIDC Configuration

The workflow needs:

```yaml
permissions:
  contents: read
  id-token: write
```

The important permission is:

```yaml
id-token: write
```

This allows GitHub Actions to request an OIDC token.

It does NOT itself grant AWS permissions.

---

# 13. AWS Credentials Action

The workflow uses:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v6
  with:
    role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/GitHubActions-PlatformCompliance
    aws-region: us-east-1
```

This action handles the OIDC → STS exchange.

Conceptually:

```text
GitHub OIDC token
       │
       ▼
configure-aws-credentials
       │
       ▼
AWS STS
       │
       ▼
AssumeRoleWithWebIdentity
       │
       ▼
Temporary credentials
```

---

# 14. Verifying the AWS Identity

The workflow uses:

```yaml
- name: Verify AWS identity
  run: aws sts get-caller-identity
```

A successful result should resemble:

```json
{
  "Account": "<ACCOUNT_ID>",
  "Arn": "arn:aws:sts::<ACCOUNT_ID>:assumed-role/GitHubActions-PlatformCompliance/..."
}
```

This proves the workflow is using an assumed role rather than a long-lived IAM user.

---

# 15. Project Structure

The project is organized approximately as follows:

```text
priest-aws-platform-compliance-demo/
│
├── .github/
│   └── workflows/
│       └── terraform-pr.yml
│
├── policies/
│   └── terraform.rego
│
├── scripts/
│   └── ...
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── s3-security.tf
│   ├── .tflint.hcl
│   └── ...
│
├── .checkov.yaml
├── .gitignore
├── Jenkinsfile
└── README.md
```

---

# 16. Terraform

The Terraform configuration creates a demonstration S3 bucket.

Example:

```hcl
resource "aws_s3_bucket" "compliance_demo" {
  bucket = "..."

  tags = {
    Name        = "platform-compliance-demo"
    Environment = var.environment
    Owner       = "Platform-Team"
  }
}
```

Security configuration includes controls such as:

* Public access blocking
* Encryption
* Versioning
* Required tags
* Other security/compliance controls

The purpose of the bucket is not the infrastructure itself.

The bucket is simply a convenient resource against which the compliance controls can be demonstrated.

---

# 17. Terraform Workflow

Terraform's role in the pipeline is:

```text
Terraform configuration
        │
        ▼
terraform fmt
        │
        ▼
terraform validate
        │
        ▼
terraform init
        │
        ▼
terraform plan
        │
        ▼
tfplan
        │
        ▼
terraform show -json
        │
        ▼
tfplan.json
```

The plan is important because it represents the infrastructure Terraform actually intends to create or modify.

---

# 18. Terraform Plan

The workflow generates a plan using:

```bash
terraform plan -out=tfplan
```

Then converts it to JSON:

```bash
terraform show -json tfplan > tfplan.json
```

This gives OPA a structured representation of the proposed infrastructure.

---

# 19. Why OPA Runs After Terraform Plan

OPA can evaluate source configuration, but this project deliberately evaluates the **Terraform plan**.

The difference is:

```text
Terraform source
      │
      ▼
Terraform Plan
      │
      │ Resolves:
      │
      ├── Variables
      ├── Expressions
      ├── Modules
      ├── Conditionals
      ├── for_each
      └── Resource arguments
      │
      ▼
Actual proposed infrastructure
      │
      ▼
OPA
```

Therefore, plan-based policy evaluation asks:

> "Does the infrastructure Terraform actually intends to provision comply with organizational policy?"

---

# 20. TFLint

TFLint is primarily a Terraform linter.

Run locally:

```bash
tflint --version
```

Initialize plugins:

```bash
tflint --init
```

Run:

```bash
tflint
```

TFLint helps identify:

* Terraform configuration problems
* Provider-specific issues
* Deprecated or problematic patterns
* Terraform best-practice violations

Think:

```text
TFLint =
"Is this Terraform written correctly?"
```

---

# 21. Checkov

Checkov scans Infrastructure as Code for security/compliance problems.

Run:

```bash
checkov -d .
```

The project intentionally demonstrated Checkov failures.

For example, Checkov identified controls related to:

```text
S3 public access
S3 encryption
S3 versioning
S3 logging
S3 lifecycle
S3 replication
```

Checkov represents:

```text
Known security best practices
```

Think:

```text
Checkov =
"Does this infrastructure violate known security controls?"
```

---

# 22. `.checkov.yaml`

The repository contains:

```text
.checkov.yaml
```

This file can be used to configure Checkov behavior, such as:

* Frameworks
* Skips
* Configuration
* Output behavior
* Organization-specific scanning requirements

Avoid using skip rules simply to make a pipeline green.

A skipped security control should have a documented business/technical reason.

---

# 23. OPA and Conftest

OPA stands for:

```text
Open Policy Agent
```

OPA is a general-purpose policy engine.

Conftest provides a convenient way to use OPA policies to test configuration/data.

The relationship is:

```text
             OPA
              │
              │ Policy Engine
              ▼
          Rego Policy
              │
              ▼
          Conftest
              │
              ▼
     Test configuration/data
```

---

# 24. Rego Policy

The project's policy is stored under:

```text
policies/
```

Example policy concept:

```text
Every resource must have:

Environment
Owner
```

This is an organizational policy.

Unlike Checkov's AWS security controls, this is a rule created specifically for the organization.

Think:

```text
Checkov
   ↓
Security best practices

OPA
   ↓
Organization-specific governance
```

---

# 25. Running Conftest Locally

Generate a Terraform plan:

```bash
terraform plan -out=tfplan
```

Convert it to JSON:

```bash
terraform show -json tfplan > tfplan.json
```

Run Conftest:

```bash
conftest test tfplan.json \
  --policy ../policies \
  --namespace terraform
```

A passing result:

```text
2 tests, 2 passed, 0 warnings, 0 failures, 0 exceptions
```

A failing result might look like:

```text
FAIL - tfplan.json - terraform -
Resource aws_s3_bucket.compliance_demo must have an Owner tag

2 tests, 1 passed, 0 warnings, 1 failure
```

---

# 26. The Compliance Gate

The GitHub Actions step is:

```yaml
- name: Compliance Gate
  working-directory: terraform
  run: |
    conftest test tfplan.json \
      --policy ../policies \
      --namespace terraform
```

The important behavior is the exit code.

```text
Policy passes
     ↓
exit code 0
     ↓
GitHub Actions step passes
```

Whereas:

```text
Policy fails
     ↓
exit code 1
     ↓
GitHub Actions step fails
     ↓
Job fails
     ↓
PR check fails
     ↓
Merge blocked
```

Therefore, the Conftest step is the actual **compliance gate**.

There does not need to be a separate magical GitHub feature called "Compliance Gate."

---

# 27. Compliance Gate Architecture

```text
Terraform Plan
      │
      ▼
tfplan.json
      │
      ▼
OPA / Conftest
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
exit 0             exit 1
      │               │
      ▼               ▼
GitHub job        GitHub job
passes             fails
      │               │
      ▼               ▼
PR can merge      PR blocked
```

---

# 28. Intentional Compliance Failure Demonstration

One of the most important demonstrations in this project was intentionally breaking the compliance policy.

The policy required an `Owner` tag.

The compliant Terraform contained:

```hcl
tags = {
  Name        = "platform-compliance-demo"
  Environment = var.environment
  Owner       = "Platform-Team"
}
```

The test removed the Owner tag:

```hcl
tags = {
  Name        = "platform-compliance-demo"
  Environment = var.environment
  # Owner     = "Platform-Team"
}
```

The pipeline then reported:

```text
Resource aws_s3_bucket.compliance_demo must have an Owner tag
```

and:

```text
Process completed with exit code 1
```

The PR therefore failed the compliance check.

---

# 29. Restoring Compliance

The tag was restored:

```hcl
Owner = "Platform-Team"
```

The pipeline then reported:

```text
2 tests, 2 passed, 0 warnings, 0 failures
```

The GitHub Actions job passed.

This demonstrated both sides of the control:

```text
Non-compliant
     ↓
OPA failure
     ↓
Pipeline failure
     ↓
PR blocked


Compliant
     ↓
OPA success
     ↓
Pipeline success
     ↓
PR can merge
```

---

# 30. Complete CI/CD Flow

The final workflow is:

```text
Developer
    │
    │ git push
    ▼
Feature Branch
    │
    ▼
Pull Request
    │
    ▼
GitHub Actions
    │
    ├──────────────────────────────────┐
    │                                  │
    ▼                                  ▼
GitHub OIDC                        CI Checks
    │                                  │
    ▼                                  ├── Terraform fmt
AWS STS                               ├── Terraform validate
    │                                  ├── TFLint
    ▼                                  ├── Checkov
IAM Role                              └── Terraform Plan
    │                                         │
    ▼                                         ▼
Temporary credentials                    tfplan.json
    │                                         │
    └──────────────────────┬──────────────────┘
                           │
                           ▼
                    OPA / Conftest
                           │
                           ▼
                    COMPLIANCE GATE
                       /        \
                    PASS        FAIL
                     │            │
                     ▼            ▼
                   Merge        Block
                     │
                     ▼
              Deployment Pipeline
```

---

# 31. Pull Request Lifecycle

The intended development workflow is:

```bash
git checkout -b feature/my-change
```

Make changes:

```bash
vim terraform/main.tf
```

Format:

```bash
terraform fmt
```

Validate:

```bash
terraform validate
```

Run TFLint:

```bash
tflint
```

Run Checkov:

```bash
checkov -d .
```

Generate plan:

```bash
terraform plan -out=tfplan
```

Convert plan:

```bash
terraform show -json tfplan > tfplan.json
```

Run policy:

```bash
conftest test tfplan.json \
  --policy ../policies \
  --namespace terraform
```

Commit:

```bash
git add .
git commit -m "Describe the change"
```

Push:

```bash
git push -u origin feature/my-change
```

Create a Pull Request.

GitHub Actions automatically runs the compliance pipeline.

---

# 32. Existing Pull Requests and New Commits

A Pull Request is associated with a branch.

Once a PR exists:

```text
feature/compliance
        │
        ▼
       PR
```

You do NOT need to create another PR every time you push.

For example:

```bash
git commit -m "Fix compliance policy"
git push
```

updates the existing PR.

GitHub Actions runs again.

Only create a new PR when creating a new branch/change stream.

---

# 33. Merge Behavior

The PR should only be merged when the required checks pass.

Conceptually:

```text
PR
 │
 ▼
GitHub Actions
 │
 ├── Terraform checks
 ├── TFLint
 ├── Checkov
 └── OPA Compliance Gate
           │
           ▼
        PASS?
       /      \
     YES       NO
      │         │
      ▼         ▼
   Merge      Block
```

In a production repository, configure GitHub branch protection / rulesets so required CI checks must pass before merging.

---

# 34. Why Terraform Apply Is Not in the PR Pipeline

This project intentionally does NOT perform:

```bash
terraform apply
```

from the Pull Request compliance workflow.

The PR pipeline's purpose is:

```text
Validate
Scan
Plan
Evaluate
Approve/Reject
```

A separate deployment workflow can perform:

```text
main branch
     │
     ▼
Terraform Plan
     │
     ▼
Approval
     │
     ▼
Terraform Apply
```

This separation reduces deployment risk.

---

# 35. Recommended Production Architecture

A mature implementation could separate the roles:

```text
                         AWS
                          │
              ┌───────────┴───────────┐
              │                       │
              ▼                       ▼
       PR Validation Role       Deployment Role
              │                       │
              ▼                       ▼
       Plan / Read access       Apply permissions
              │                       │
              ▼                       ▼
       Pull Requests              main/prod
```

The PR role should have only the permissions necessary for validation/plan.

The deployment role should have the permissions necessary to perform deployment.

This follows the principle of:

> **Least privilege**

---

# 36. Security Principles Demonstrated

This project demonstrates several important Platform Engineering security principles.

## No Long-Lived CI Credentials

GitHub uses OIDC instead of stored AWS access keys.

## Least Privilege

The CI role should receive only the permissions required for its job.

## Shift-Left Security

Security checks occur during the Pull Request.

## Policy-as-Code

Organizational requirements are expressed as code.

## Automated Enforcement

Policy violations cause the pipeline to fail.

## Separation of Duties

PR validation and deployment can use separate IAM roles/workflows.

## Traceability

Git commits, Pull Requests, CI results, Terraform plans, and policy results provide an audit trail.

---

# 37. Authentication vs Authorization

One of the most important concepts demonstrated here:

```text
Authentication
     │
     ▼
"Who are you?"
```

OIDC + STS + IAM trust policy establishes the identity relationship.

Then:

```text
Authorization
     │
     ▼
"What are you allowed to do?"
```

IAM permissions determine what the assumed role can do.

Therefore:

```text
GitHub OIDC
     ↓
Authentication / Federation
     ↓
Assume IAM Role
     ↓
Temporary Credentials
     ↓
Authorization through IAM permissions
```

A role can be successfully assumed but still fail because it lacks permissions.

---

# 38. Troubleshooting Guide

## OIDC: `Not authorized to perform sts:AssumeRoleWithWebIdentity`

Check:

```text
OIDC provider
Trust policy
aud claim
sub claim
id-token: write
Role ARN
```

Do not immediately add broad IAM permissions.

---

## Terraform AccessDenied

If:

```text
Configure AWS credentials ✓
```

but:

```text
Terraform Plan ✗
```

then authentication probably succeeded but the IAM role lacks required AWS permissions.

Think:

```text
Authentication ✓
Authorization ✗
```

---

## Checkov Fails

Read the failed control.

Example:

```text
CKV_AWS_21
S3 versioning
```

Fix the infrastructure or document an approved exception.

Do not blindly suppress the check.

---

## OPA/Conftest Fails

Example:

```text
Resource ... must have an Owner tag
```

Inspect:

```text
policies/terraform.rego
```

and the Terraform plan:

```text
terraform/tfplan.json
```

Determine whether:

1. The Terraform configuration violates the policy
2. The policy is incorrect
3. The policy needs an approved exception

---

# 39. Useful Local Commands

Check versions:

```bash
terraform version
git --version
docker --version
aws --version
kubectl version --client
python3 --version
tflint --version
checkov --version
conftest --version
```

Check AWS identity:

```bash
aws sts get-caller-identity
```

Initialize Terraform:

```bash
cd terraform
terraform init
```

Format:

```bash
terraform fmt
```

Validate:

```bash
terraform validate
```

Plan:

```bash
terraform plan -out=tfplan
```

Convert plan to JSON:

```bash
terraform show -json tfplan > tfplan.json
```

TFLint:

```bash
tflint --init
tflint
```

Checkov:

```bash
checkov -d .
```

Conftest:

```bash
conftest test tfplan.json \
  --policy ../policies \
  --namespace terraform
```

---

# 40. Important Files

## `.github/workflows/terraform-pr.yml`

Defines the GitHub Actions CI/CD workflow.

Responsibilities include:

* Checkout
* AWS OIDC authentication
* Terraform setup
* Terraform validation
* TFLint
* Checkov
* Terraform Plan
* Plan JSON generation
* Conftest compliance gate

---

## `terraform/`

Contains the Infrastructure as Code.

---

## `policies/terraform.rego`

Contains organization-specific OPA policies.

---

## `.checkov.yaml`

Contains Checkov configuration.

---

## `Jenkinsfile`

Can be used as a reference for implementing the same concepts with Jenkins.

The concepts remain the same:

```text
CI/CD
  ↓
AWS Authentication
  ↓
Terraform
  ↓
Security Scanning
  ↓
Policy Enforcement
```

The CI platform changes, but the architecture does not fundamentally change.

---

# 41. Jenkins Equivalent

The same design can be implemented with Jenkins.

Conceptually:

```text
Jenkins
   │
   ▼
AWS Authentication
   │
   ▼
Terraform
   │
   ├── TFLint
   ├── Checkov
   ├── Terraform Plan
   └── OPA/Conftest
            │
            ▼
      Compliance Gate
```

For Jenkins, authentication options may include:

* EC2 Instance Profile
* IAM Roles for Service Accounts
* OIDC federation
* Jenkins/AWS integrations
* Short-lived credentials

The authentication mechanism changes depending on where Jenkins runs.

---

# 42. Interview Questions This Project Helps Answer

This project provides hands-on examples for questions such as:

### AWS / IAM

* How does GitHub Actions authenticate to AWS?
* What is OIDC?
* What is AWS STS?
* What is `AssumeRoleWithWebIdentity`?
* What is the difference between a trust policy and permissions policy?
* Why use temporary credentials?
* How do you implement least privilege?
* How would you troubleshoot an STS authorization failure?

### Terraform

* How do you validate Terraform?
* What does `terraform plan` do?
* Why convert a plan to JSON?
* How do you enforce Terraform standards?
* How do you manage Terraform in CI/CD?

### DevSecOps

* How do you shift security left?
* How do you scan Infrastructure as Code?
* How do you enforce compliance before deployment?
* How do you prevent non-compliant infrastructure from reaching production?

### Policy-as-Code

* What is OPA?
* What is Rego?
* What is Conftest?
* Why use OPA instead of only Checkov?
* What is the difference between security scanning and organizational policy enforcement?

### CI/CD

* How do you implement a compliance gate?
* How do you block a Pull Request?
* What happens when a CI step returns exit code 1?
* Why should Terraform Apply be separated from PR validation?

---

# 43. Key Interview Explanation

A concise explanation of this project is:

> "I built a PR-based Terraform compliance pipeline using GitHub Actions. GitHub authenticates to AWS using OIDC rather than long-lived AWS credentials. AWS STS validates the GitHub OIDC token against an IAM role trust policy and issues temporary credentials. The pipeline then runs Terraform validation, TFLint, Checkov, and Terraform Plan. The Terraform plan is converted to JSON and evaluated with OPA/Conftest against organization-specific policies. A policy violation returns a non-zero exit code, causing the compliance gate to fail and preventing the Pull Request from being merged."

---

# 44. What This Demonstrates as a Platform Engineer

This project demonstrates the ability to:

```text
Design
   ↓
Automate
   ↓
Secure
   ↓
Govern
   ↓
Enforce
   ↓
Troubleshoot
```

Rather than manually checking infrastructure, the Platform Engineering team provides a reusable platform capability where developers receive automated feedback through the normal Pull Request workflow.

This is an example of treating **security and compliance as platform capabilities** rather than manual operational tasks.

---

# 45. Future Enhancements

Possible production extensions include:

* GitHub branch protection/rulesets
* Separate PR and deployment IAM roles
* Terraform remote state in S3
* DynamoDB state locking where applicable
* Multi-account AWS architecture
* AWS Organizations / SCP integration
* AWS Config
* Security Hub
* CloudTrail
* Centralized compliance reporting
* Terraform modules
* Reusable GitHub Actions workflows
* Reusable OPA policies
* Policy exceptions with approval
* Container image scanning with Trivy
* Kubernetes admission control with OPA Gatekeeper/Kyverno
* Kubernetes deployment compliance
* Argo CD integration
* Jenkins implementation
* Multi-cloud policy enforcement

---

# 46. Final Architecture

```text
                              Developer
                                  │
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ GitHub Pull     │
                         │ Request         │
                         └────────┬────────┘
                                  │
                                  ▼
                       ┌──────────────────────┐
                       │   GitHub Actions     │
                       └──────────┬───────────┘
                                  │
             ┌────────────────────┼────────────────────┐
             │                    │                    │
             ▼                    ▼                    ▼
       GitHub OIDC           Terraform             Security
             │                    │                    │
             ▼                    │             ┌──────┴──────┐
          AWS STS                 │             │             │
             │                    │           TFLint       Checkov
             ▼                    │             │             │
          IAM Role                │             └──────┬──────┘
             │                    │                    │
             ▼                    ▼                    │
     Temporary Credentials   Terraform Plan            │
             │                    │                    │
             │                    ▼                    │
             │                tfplan.json              │
             │                    │                    │
             │                    ▼                    │
             │              OPA / Conftest ◄──────────┘
             │                    │
             │                    ▼
             │             COMPLIANCE GATE
             │                /        \
             │              PASS        FAIL
             │               │            │
             │               ▼            ▼
             │             MERGE        BLOCK
             │
             └──────────────► AWS
```

---

# 47. Final Takeaway

The central principle of this project is:

> **Infrastructure should be automatically validated, secured, and governed before it is allowed to become infrastructure.**

The pipeline provides:

```text
GitHub
  ↓
OIDC Authentication
  ↓
AWS STS
  ↓
Temporary IAM Credentials
  ↓
Terraform
  ↓
Security Scanning
  ↓
Terraform Plan
  ↓
Policy-as-Code
  ↓
Compliance Gate
  ↓
Merge or Block
```

This creates a repeatable, automated and auditable control for Infrastructure as Code.

---

## Demo Status

**Completed**

* [x] GitHub repository
* [x] Terraform infrastructure
* [x] TFLint
* [x] Checkov
* [x] OPA/Conftest
* [x] GitHub Actions
* [x] AWS OIDC Identity Provider
* [x] IAM role
* [x] STS AssumeRoleWithWebIdentity
* [x] Temporary AWS credentials
* [x] Terraform Plan in CI
* [x] Plan JSON
* [x] OPA compliance gate
* [x] Intentional compliance failure
* [x] PR blocking demonstration
* [x] Compliance restoration
* [x] Successful PR pipeline

**Result:**

```text
OIDC Authentication        ✓
AWS Authorization          ✓
Terraform Validation       ✓
TFLint                     ✓
Checkov                    ✓
Terraform Plan             ✓
OPA Policy Enforcement     ✓
Compliance Gate            ✓
PR Failure Demonstration   ✓
PR Recovery Demonstration  ✓
```

````

### One small recommendation before you push

Since this README contains the **architecture and the actual troubleshooting story**, I'd put it in the repo exactly as above. It gives you a useful interview reference rather than just a list of commands.

Then:

```bash
git add README.md
git commit -m "Add comprehensive platform compliance documentation"
git push
````

Your repository will then tell the complete story:

**why the platform exists → architecture → AWS OIDC → Terraform → security scanning → policy-as-code → compliance gate → intentional failure → recovery → interview talking points.**
