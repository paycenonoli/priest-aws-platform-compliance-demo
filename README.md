<div align="center">

AWS Platform Compliance Demo

Production-style Terraform CI/CD with Security, Compliance & OIDC

GitHub Actions • Terraform • AWS IAM/OIDC • STS • TFLint • Checkov • OPA/Conftest

<br/>







<br/>

Pull Request → Security Scans → Terraform Plan → Policy Gate → Merge → Terraform Apply → AWS

</div>

📌 Project Status

Component

Status

Terraform Infrastructure

✅ Complete

GitHub OIDC → AWS STS

✅ Complete

Terraform PR Compliance

✅ Complete

TFLint

✅ Passing

Checkov

✅ Passing

OPA / Conftest

✅ Passing

Terraform Plan

✅ Passing

Compliance Gate

✅ Tested

Terraform Deployment

✅ Passing

AWS S3 Verification

✅ Verified

Jenkins Implementation

🔜 Next Phase

Current milestone: The GitHub Actions implementation has been successfully tested end-to-end. The infrastructure was deployed to AWS and independently verified with the AWS CLI.

🎯 What This Project Demonstrates

This project demonstrates a production-style approach to answering:

How can a DevOps/platform team ensure that Terraform infrastructure is secure, compliant, reviewed, and automatically deployable without storing long-lived AWS credentials in CI/CD?

The implementation combines:

Terraform for Infrastructure as Code

GitHub Actions for CI/CD orchestration

GitHub OIDC for passwordless/federated AWS authentication

AWS STS for short-lived credentials

AWS IAM for authorization

TFLint for Terraform linting

Checkov for infrastructure security scanning

Terraform Plan as the intended-change artifact

OPA / Conftest for policy-as-code

S3 for Terraform remote state

Automated Terraform Apply after an approved merge

The project also intentionally includes real failure scenarios and troubleshooting rather than documenting only the happy path.

🏗️ End-to-End Architecture

flowchart TD
    DEV[👨‍💻 Developer] --> PR[GitHub Pull Request]

    PR --> CI[GitHub Actions<br/>PR Compliance]

    CI --> OIDC[GitHub OIDC]
    OIDC --> STS[AWS STS]
    STS --> ROLE[IAM Role]
    ROLE --> CREDS[Temporary AWS Credentials]

    CI --> FMT[Terraform fmt]
    CI --> VAL[Terraform validate]
    CI --> LINT[TFLint]
    CI --> CHECKOV[Checkov]
    CI --> PLAN[Terraform Plan]

    PLAN --> TFPLAN[tfplan]
    TFPLAN --> JSON[tfplan.json]
    JSON --> OPA[OPA / Conftest]

    FMT --> GATE
    VAL --> GATE
    LINT --> GATE
    CHECKOV --> GATE
    OPA --> GATE

    GATE{COMPLIANCE<br/>GATE}

    GATE -->|PASS| MERGE[✅ Merge PR]
    GATE -->|FAIL| BLOCK[❌ Block Merge]

    MERGE --> MAIN[main]
    MAIN --> DEPLOY[Terraform Deploy Workflow]

    DEPLOY --> DOIDC[GitHub OIDC]
    DOIDC --> DSTS[AWS STS]
    DSTS --> DROLE[IAM Role]
    DROLE --> DCREDS[Temporary Credentials]

    DEPLOY --> INIT[Terraform Init]
    INIT --> REMOTE[(S3 Remote State)]
    DEPLOY --> DPLAN[Terraform Plan]
    DPLAN --> APPLY[Terraform Apply]

    APPLY --> S3[(AWS S3 Bucket)]
    S3 --> V[Versioning]
    S3 --> KMS[KMS Encryption]
    S3 --> PAB[Public Access Block]

🔐 Authentication: GitHub OIDC → AWS STS → IAM

This project deliberately avoids storing long-lived AWS access keys in GitHub.

sequenceDiagram
    participant G as GitHub Actions
    participant O as GitHub OIDC Provider
    participant S as AWS STS
    participant I as IAM Role
    participant A as AWS APIs

    G->>O: Request OIDC token
    O-->>G: Short-lived identity token
    G->>S: AssumeRoleWithWebIdentity
    S->>I: Evaluate trust policy
    I-->>S: Allow / Deny
    S-->>G: Temporary AWS credentials
    G->>A: Call AWS APIs

Why OIDC?

Traditional CI/CD authentication commonly relies on:

AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY

Those are long-lived credentials.

This project uses:

GitHub OIDC Token
        │
        ▼
AWS STS
        │
        ▼
Temporary Credentials
        │
        ▼
AWS APIs

Benefits

🔒 No long-lived AWS secret stored in GitHub

⏱️ Temporary credentials

🎯 IAM trust-policy restrictions

🔄 Credentials are issued per workflow execution

🛡️ Centralized AWS authorization

🏭 Better alignment with production CI/CD security

🧠 Authentication vs Authorization

One of the most important lessons from this project:

Trust Policy

Answers:

Who is allowed to assume this IAM role?

Permission Policy

Answers:

What can the role do after it has been assumed?

flowchart LR
    GH[GitHub OIDC Token] --> TRUST[IAM Trust Policy]
    TRUST -->|Allowed| ROLE[IAM Role]
    TRUST -->|Denied| FAIL[❌ AssumeRole Failure]

    ROLE --> PERM[IAM Permission Policy]
    PERM --> S3[S3 APIs]

Therefore:

OIDC authentication succeeds
          ≠
AWS API authorization succeeds

We encountered this distinction directly during the implementation.

🧱 Terraform Infrastructure

The infrastructure is intentionally small so the CI/CD security and compliance architecture remains the focus.

Terraform creates an S3 bucket with:

✅ Versioning

✅ AWS KMS server-side encryption

✅ Public-access blocking

✅ Required resource tags

flowchart TD
    TF[Terraform Configuration]
    TF --> B[aws_s3_bucket]
    TF --> V[aws_s3_bucket_versioning]
    TF --> E[aws_s3_bucket_server_side_encryption_configuration]
    TF --> P[aws_s3_bucket_public_access_block]

    B --> AWS[(AWS S3)]
    V --> AWS
    E --> AWS
    P --> AWS

🗄️ Terraform Remote State

Terraform state is stored centrally in an S3 backend.

flowchart LR
    DEV[Developer / CI] --> TF[Terraform]
    TF --> INIT[terraform init]
    INIT --> STATE[(S3 Remote State)]
    STATE --> KEY["platform-compliance/terraform.tfstate"]

The state bucket is configured with:

Versioning

Server-side encryption

Restricted access

Why remote state?

A production team should not depend on a developer's local:

terraform.tfstate

Instead:

Developer / CI
      │
      ▼
 Terraform
      │
      ▼
Central Remote State
      │
      ▼
 S3 Backend

This gives multiple execution environments a shared source of Terraform state.

🔍 CI Security & Quality Pipeline

Each tool has a different responsibility.

Tool

Responsibility

terraform fmt

Formatting consistency

terraform validate

Terraform configuration validation

TFLint

Terraform linting and provider-aware checks

Checkov

IaC security/static analysis

terraform plan

Determines intended infrastructure changes

OPA

Policy-as-code engine

Conftest

Executes OPA policies against structured data

AWS IAM

Authorization

AWS STS

Temporary credentials

GitHub OIDC

Federated identity

🧪 Terraform Plan → JSON → OPA

This is one of the core architectural decisions.

flowchart LR
    TF[Terraform Configuration]
    TF --> PLAN["terraform plan -out=tfplan"]
    PLAN --> SHOW["terraform show -json tfplan"]
    SHOW --> JSON[tfplan.json]
    JSON --> CONFTEST[Conftest]
    CONFTEST --> REG[terraform.rego]
    REG --> RESULT{Compliance Result}

Why evaluate the Terraform plan?

The .tf files represent what the developer wrote.

The Terraform plan represents what Terraform intends to do.

Developer Configuration
          │
          ▼
     Terraform Plan
          │
          ▼
Actual Intended Changes
          │
          ▼
     OPA / Conftest
          │
          ▼
     Policy Decision

This makes the Terraform plan a useful policy enforcement boundary.

🚦 The Compliance Gate

The compliance gate determines whether the pull request can proceed.

flowchart TD
    PLAN[Terraform Plan] --> JSON[tfplan.json]
    JSON --> OPA[OPA / Conftest]
    OPA --> GATE{COMPLIANCE GATE}

    GATE -->|PASS| MERGE[✅ PR Can Merge]
    GATE -->|FAIL| BLOCK[🛑 PR Blocked]

Example passing result:

2 tests, 2 passed, 0 warnings, 0 failures

Example failure:

FAIL - tfplan.json
Resource aws_s3_bucket.compliance_demo
must have an Owner tag

This was deliberately tested to prove that the compliance gate actually blocks non-compliant infrastructure.

🔄 Why OPA Comes After Terraform Plan

TFLint and Checkov can inspect Terraform configuration directly.

OPA in this project evaluates the Terraform plan.

Therefore:

Terraform .tf files
        │
        ▼
Terraform Plan
        │
        ▼
Planned Infrastructure
        │
        ▼
tfplan.json
        │
        ▼
OPA / Conftest

OPA is therefore not simply another Terraform linter.

It is enforcing organizational policy against the planned infrastructure.

🚀 Deployment Architecture

Once the PR passes compliance and is merged:

flowchart TD
    PR[Approved Pull Request] --> MERGE[Merge]
    MERGE --> MAIN[main]
    MAIN --> DEPLOY[Terraform Deploy Workflow]

    DEPLOY --> OIDC[GitHub OIDC]
    OIDC --> STS[AWS STS]
    STS --> ROLE[IAM Role]
    ROLE --> CREDS[Temporary Credentials]

    DEPLOY --> INIT[terraform init]
    INIT --> PLAN[terraform plan]
    PLAN --> APPLY[terraform apply]
    APPLY --> AWS[(AWS Infrastructure)]

The deployment workflow uses the same OIDC security model instead of storing permanent AWS credentials.

☁️ Actual AWS Result

The infrastructure was not merely planned.

It was actually deployed and independently verified through the AWS CLI.

S3 Bucket

aws s3api head-bucket \
  --bucket priest-platform-compliance-demo-417521971848

Result:

BucketArn: arn:aws:s3:::priest-platform-compliance-demo-417521971848
BucketRegion: us-east-1

Versioning

aws s3api get-bucket-versioning \
  --bucket priest-platform-compliance-demo-417521971848

{
  "Status": "Enabled"
}

Public Access Protection

aws s3api get-public-access-block \
  --bucket priest-platform-compliance-demo-417521971848

{
  "PublicAccessBlockConfiguration": {
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }
}

Encryption

aws s3api get-bucket-encryption \
  --bucket priest-platform-compliance-demo-417521971848

Verified:

SSEAlgorithm = aws:kms

Final AWS security posture

Control

Result

S3 Bucket

✅ Exists

Versioning

✅ Enabled

KMS Encryption

✅ Enabled

Public ACLs

✅ Blocked

Public Policies

✅ Blocked

Restrict Public Buckets

✅ Enabled

🧯 Real Challenges Encountered

This project was intentionally built through real failures rather than a simulated "everything worked first time" workflow.

🔴 Challenge 1 — GitHub OIDC Trust Policy Failure

Symptom

GitHub Actions failed while configuring AWS credentials:

Could not assume role with OIDC:
Not authorized to perform sts:AssumeRoleWithWebIdentity

The action retried multiple times.

Root Cause

The GitHub OIDC token reached AWS STS, but the IAM role's trust policy did not authorize the identity represented by that token.

OIDC Provider Exists
        ≠
IAM Role Trusts This GitHub Identity

Investigation

The workflow inspected OIDC claims including:

iss
aud
sub
repository
event_name
ref
head_ref
base_ref

The sub claim was especially important because the trust policy used it to restrict which GitHub identity could assume the role.

Resolution

The IAM trust relationship was corrected to match the GitHub OIDC identity used by the workflow.

After the fix:

Configure AWS credentials     ✅
Verify AWS identity           ✅

Key lesson

When GitHub Actions cannot assume an AWS role, check:

AWS has the GitHub OIDC provider

Trust policy references the correct provider

aud equals sts.amazonaws.com

sub matches the actual workflow/event identity

GitHub workflow has:

permissions:
  id-token: write
  contents: read

🔴 Challenge 2 — Missing s3:CreateBucket

After OIDC authentication was fixed, the workflow reached Terraform.

It then failed with:

not authorized to perform:
s3:CreateBucket

Root Cause

The IAM role could be assumed successfully, but its permission policy did not allow S3 bucket creation.

This demonstrated:

Authentication
      │
      ▼
AssumeRoleWithWebIdentity
      │
      ▼
SUCCESS
      │
      ▼
Authorization
      │
      ▼
s3:CreateBucket
      │
      ▼
DENIED

Resolution

The required S3 permission was added to the role's identity-based policy.

Key lesson

OIDC tells AWS who the workload is.

IAM policies determine what that workload can do.

🔴 Challenge 3 — Terraform Needed More S3 Read Permissions

After s3:CreateBucket was added, Terraform continued failing during refresh/plan.

The AWS provider progressively exposed missing permissions such as:

s3:GetBucketPolicy
s3:GetBucketCORS
s3:GetBucketWebsite
s3:GetAccelerateConfiguration
s3:GetBucketRequestPayment
s3:GetBucketLogging
s3:GetLifecycleConfiguration
s3:GetReplicationConfiguration
s3:GetObjectLockConfiguration

Why?

Terraform does not simply create a resource and stop.

During refresh and planning, Terraform reads the existing AWS resource to compare:

Terraform Configuration
        │
        ▼
Current AWS State
        │
        ▼
Terraform Plan

Conceptually:

Terraform Plan
      │
      ▼
Refresh S3 Resource
      │
      ├── GetBucketPolicy
      ├── GetBucketCORS
      ├── GetBucketWebsite
      ├── GetBucketLogging
      ├── GetLifecycleConfiguration
      ├── GetReplicationConfiguration
      ├── GetObjectLockConfiguration
      └── ...
      │
      ▼
Generate Plan

Resolution

The required read permissions were added to the IAM policy.

The pipeline eventually reached:

Terraform Plan       ✅
Checkov               ✅
OPA / Conftest        ✅
Terraform Apply       ✅

Production lesson

Do not blindly make an IAM policy broad just to make Terraform work.

Instead:

Identify the exact denied API call

Determine why Terraform needs it

Add the narrowest appropriate permission

Test again

Review the final policy for least privilege

🔴 Challenge 4 — BucketAlreadyExists

During testing Terraform attempted to create:

priest-platform-compliance-demo-417521971848

AWS returned:

BucketAlreadyExists

What happened?

The bucket had already been created during an earlier deployment attempt.

Terraform did not have that resource represented correctly in its state, so it attempted to create it again.

Resolution

The existing resource was imported:

terraform import aws_s3_bucket.compliance_demo \
  priest-platform-compliance-demo-417521971848

Then:

terraform state list

showed:

aws_s3_bucket.compliance_demo

Key lesson

An AWS resource can exist without Terraform knowing that Terraform should manage it.

AWS Resource Exists
        │
        ▼
Terraform State?
   │           │
  NO          YES
   │           │
   ▼           ▼
Import       Manage

🔴 Challenge 5 — Remote State / Backend Initialization

After introducing the S3 backend, Terraform required backend initialization.

The normal initialization command was:

terraform init

If backend configuration changes, Terraform may require:

terraform init -reconfigure

or, where state actually needs to be migrated:

terraform init -migrate-state

Important distinction

-reconfigure tells Terraform to use the new backend configuration without migrating existing state.

-migrate-state is for moving state between backend configurations.

Always understand which operation is appropriate before using either option in production.

🧪 Deliberate Compliance Failure

A real compliance failure was deliberately introduced by removing the required Owner tag.

The pipeline reported:

FAIL - tfplan.json
Resource aws_s3_bucket.compliance_demo
must have an Owner tag

The compliance gate failed.

After restoring the required tag:

Owner = Platform-Team

the pipeline reported:

2 tests, 2 passed
0 warnings
0 failures

This proves:

Non-Compliant Infrastructure
          │
          ▼
     OPA / Conftest
          │
          ▼
        FAIL
          │
          ▼
     PR BLOCKED

and:

Compliant Infrastructure
          │
          ▼
     OPA / Conftest
          │
          ▼
        PASS
          │
          ▼
      PR MERGED

🧰 Useful Local Commands

Terraform

terraform init

terraform fmt -recursive

terraform validate

terraform plan

terraform plan -out=tfplan

terraform show -json tfplan > tfplan.json

terraform apply tfplan

Terraform State

terraform state list

terraform state pull

terraform import aws_s3_bucket.compliance_demo \
  priest-platform-compliance-demo-417521971848

AWS Verification

aws s3api head-bucket \
  --bucket priest-platform-compliance-demo-417521971848

aws s3api get-bucket-versioning \
  --bucket priest-platform-compliance-demo-417521971848

aws s3api get-public-access-block \
  --bucket priest-platform-compliance-demo-417521971848

aws s3api get-bucket-encryption \
  --bucket priest-platform-compliance-demo-417521971848

Remote State Verification

aws s3api list-objects-v2 \
  --bucket priest-platform-compliance-tfstate-417521971848 \
  --prefix platform-compliance/

📁 Repository Structure

priest-aws-platform-compliance-demo/
│
├── .github/
│   └── workflows/
│       ├── terraform-pr.yml
│       └── terraform-deploy.yml
│
├── policies/
│   └── terraform.rego
│
├── scripts/
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── backend.tf
│   ├── terraform.tfvars
│   └── .terraform.lock.hcl
│
├── .checkov.yaml
├── .tflint.hcl
├── Jenkinsfile              # 🔜 Next phase
├── README.md
└── LICENSE

Do not commit

terraform.tfstate
terraform.tfstate.*
.terraform/
tfplan
tfplan.json
.env
AWS access keys
AWS secret keys

🧩 GitHub Actions Workflow

flowchart TD
    PR[Pull Request] --> CO[Checkout]
    CO --> AUTH[Configure AWS Credentials]
    AUTH --> FMT[Terraform fmt]
    FMT --> VAL[Terraform validate]
    VAL --> LINT[TFLint]
    LINT --> CHECK[Checkov]
    CHECK --> PLAN[Terraform Plan]
    PLAN --> JSON[tfplan.json]
    JSON --> OPA[OPA / Conftest]
    OPA --> GATE{Compliance Gate}
    GATE -->|PASS| MERGE[Merge]
    GATE -->|FAIL| BLOCK[Block PR]

🚢 GitHub Actions Deployment Workflow

flowchart TD
    MERGE[PR Merged] --> MAIN[main]
    MAIN --> AUTH[OIDC → AWS STS]
    AUTH --> ROLE[IAM Role]
    ROLE --> INIT[Terraform Init]
    INIT --> PLAN[Terraform Plan]
    PLAN --> APPLY[Terraform Apply]
    APPLY --> AWS[AWS Infrastructure]

🔁 Complete CI/CD Lifecycle

flowchart LR
    DEV[Developer] --> PR[Pull Request]
    PR --> CI[Compliance CI]
    CI --> GATE{Policy Gate}
    GATE -->|Fail| FIX[Developer Fix]
    FIX --> PR
    GATE -->|Pass| MERGE[Merge]
    MERGE --> CD[Deployment]
    CD --> AWS[(AWS)]

This creates the production-style lifecycle:

Code → Validate → Secure → Plan → Govern → Approve → Deploy → Verify

🏭 Production Improvements

This demo intentionally focuses on the core architecture. A production platform could extend it with:

IAM

Separate plan and apply roles

Separate CI and deployment roles

Strict least-privilege policies

IAM permissions boundaries

AWS Organizations / SCPs

CloudTrail

IAM Access Analyzer

Terraform

Reusable modules

Environment separation

Version pinning

Provider upgrade strategy

Stronger remote-state controls

State locking strategy

CI/CD

Protected main

Required PR approvals

Required status checks

Environment approvals

Artifact retention

Notifications

Security scanning

Separate plan/apply privileges

Compliance

Required encryption

Required logging

Required tags

Approved AWS regions

Naming standards

Public-access policies

Cost-control policies

AWS

Multi-account architecture

Dedicated deployment account

Dedicated state account

KMS key management

CloudTrail

GuardDuty

Security Hub

AWS Config

🔜 Next Phase: Jenkins

The next phase is to reproduce the CI/CD architecture with Jenkins.

We do not need to duplicate the Terraform infrastructure.

We reuse:

terraform/
policies/
scripts/

and create a Jenkins orchestration layer.

flowchart TD
    TF[Shared Terraform] --> GA[GitHub Actions]
    TF --> J[Jenkins]

    POL[Shared OPA Policies] --> GA
    POL --> J

    GA --> GATE1[Compliance Gate]
    J --> GATE2[Compliance Gate]

    GATE1 --> AWS[(AWS)]
    GATE2 --> AWS

The goal is to demonstrate that the same platform security controls can be implemented using different enterprise CI/CD platforms.

🎤 Senior DevOps Interview Explanation

A concise explanation of the project:

"I built a Terraform platform compliance pipeline using GitHub Actions. Pull requests trigger Terraform formatting and validation, TFLint, Checkov, and Terraform plan. The plan is converted to JSON and evaluated with OPA/Conftest policies. The compliance result acts as a merge gate. GitHub Actions authenticates to AWS using OIDC and STS rather than long-lived AWS credentials. After the PR passes and is merged, a deployment workflow assumes the AWS IAM role through OIDC and runs Terraform against an S3 remote backend. The infrastructure deployed is an S3 bucket with versioning, KMS encryption, and public-access blocking. I deliberately tested compliance failures and resolved real OIDC trust-policy and least-privilege IAM permission issues encountered during implementation."

🧠 Key Concepts to Be Able to Explain

Before presenting this project in an interview, be comfortable explaining:

Terraform

State

Remote state

terraform init

terraform plan

terraform apply

Resource import

Provider refresh

Plan artifacts

AWS

IAM roles

Trust policies

Permission policies

STS

OIDC

Temporary credentials

Least privilege

S3 security controls

KMS encryption

GitHub Actions

Workflows

Jobs

Steps

Permissions

Pull-request triggers

OIDC authentication

Secrets vs federated identity

Status checks

Security / Compliance

SAST vs IaC scanning

Checkov

TFLint

Policy-as-code

OPA

Rego

Conftest

Compliance gates

CI/CD

Continuous Integration

Continuous Delivery / Deployment

Pull-request validation

Promotion through environments

Approval gates

Automated deployment

🏆 Final Project Outcome

The GitHub Actions implementation now provides:

Terraform Infrastructure as Code

GitHub Pull Request workflow

Terraform formatting

Terraform validation

TFLint

Checkov

Terraform Plan

Terraform Plan JSON

OPA / Conftest policy-as-code

Working compliance gate

GitHub OIDC authentication

AWS STS federation

IAM role-based authorization

Temporary AWS credentials

Terraform remote S3 state

Automated Terraform deployment

S3 versioning

KMS encryption

S3 public-access blocking

Deliberate compliance failure test

Real OIDC trust-policy troubleshooting

Real IAM permission troubleshooting

Terraform resource import

Independent AWS verification

📸 Architecture Summary

                    ┌─────────────────────┐
                    │     DEVELOPER       │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │    GITHUB PR        │
                    └──────────┬──────────┘
                               │
                               ▼
              ┌────────────────────────────────┐
              │       GITHUB ACTIONS            │
              │                                │
              │  fmt → validate → TFLint       │
              │          ↓                     │
              │       Checkov                  │
              │          ↓                     │
              │    Terraform Plan              │
              │          ↓                     │
              │      tfplan.json               │
              │          ↓                     │
              │     OPA / Conftest             │
              └────────────────┬───────────────┘
                               │
                               ▼
                     ┌─────────────────┐
                     │ COMPLIANCE GATE │
                     └───────┬─────────┘
                         PASS│FAIL
                             │
                             ▼
                           MERGE
                             │
                             ▼
                    ┌──────────────────┐
                    │ TERRAFORM DEPLOY │
                    └────────┬─────────┘
                             │
                       GitHub OIDC
                             │
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
                       Terraform Apply
                             │
                             ▼
                    ┌──────────────────┐
                    │      AWS S3      │
                    │                  │
                    │ Versioning   ✓   │
                    │ KMS          ✓   │
                    │ Public Block ✓   │
                    └──────────────────┘

<div align="center">

Built as a hands-on Senior DevOps / Platform Engineering demonstration

Terraform • AWS • GitHub Actions • OIDC • IAM • STS • TFLint • Checkov • OPA • Conftest

</div>
