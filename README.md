<div align="center">

🛡️ AWS Platform Compliance Demo

Production-style Terraform CI/CD with Security, Compliance & Passwordless AWS Authentication

Terraform · GitHub Actions · AWS OIDC · STS · IAM · TFLint · Checkov · OPA/Conftest

<br/>








<br/>

Pull Request → Security Checks → Terraform Plan → Compliance Gate → Merge → Deploy → Verify

</div>

📊 Project Status

Area

Status

Terraform infrastructure

✅

GitHub Actions PR pipeline

✅

GitHub OIDC → AWS STS

✅

IAM trust + permission policies

✅

Terraform fmt / validate

✅

TFLint

✅

Checkov

✅

Terraform plan → JSON

✅

OPA / Conftest

✅

Compliance gate

✅

Automated Terraform apply

✅

S3 remote state

✅

AWS CLI verification

✅

Jenkins duplicate

🔜 Next phase

Current milestone: The GitHub Actions implementation has been exercised end-to-end: a PR was validated, a real compliance failure was tested, the PR was corrected and merged, Terraform deployed the infrastructure, and the resulting S3 security controls were independently verified with the AWS CLI.

🎯 What This Project Is

This is a hands-on Platform Engineering / DevSecOps demonstration.

The question it answers is:

How do we allow developers to change infrastructure while automatically enforcing security, compliance, review, and least-privilege AWS access?

The project combines:

🏗️ Terraform — Infrastructure as Code

🔄 GitHub Actions — CI/CD orchestration

🔐 GitHub OIDC — federated AWS authentication

⏱️ AWS STS — short-lived credentials

👮 AWS IAM — authorization and least privilege

🔎 TFLint — Terraform linting

🛡️ Checkov — IaC security scanning

📋 Terraform Plan — intended infrastructure changes

🧠 OPA / Conftest — policy-as-code

🗄️ S3 — Terraform remote state

🚀 Terraform Apply — automated deployment after merge

🏗️ Architecture

flowchart TD
    DEV[👨‍💻 Developer] --> PR[GitHub Pull Request]
    PR --> CI[GitHub Actions]

    CI --> FMT[Terraform fmt]
    CI --> VAL[Terraform validate]
    CI --> LINT[TFLint]
    CI --> CHECK[Checkov]
    CI --> PLAN[Terraform plan]

    CI --> AUTH[GitHub OIDC]
    AUTH --> STS[AWS STS]
    STS --> ROLE[IAM Role]
    ROLE --> CREDS[Temporary Credentials]

    PLAN --> JSON[tfplan.json]
    JSON --> OPA[OPA / Conftest]
    OPA --> GATE{COMPLIANCE GATE}

    FMT --> GATE
    VAL --> GATE
    LINT --> GATE
    CHECK --> GATE

    GATE -->|PASS| MERGE[✅ Merge]
    GATE -->|FAIL| BLOCK[🛑 Block]

    MERGE --> MAIN[main]
    MAIN --> DEPLOY[Terraform Deploy]

    DEPLOY --> AWSOIDC[GitHub OIDC]
    AWSOIDC --> AWSSTS[AWS STS]
    AWSSTS --> AWSROLE[IAM Deploy Role]
    AWSROLE --> APPLY[Terraform Apply]

    APPLY --> S3[(AWS S3 Bucket)]

The core idea

Developer
   ↓
Pull Request
   ↓
Validate + Scan + Plan
   ↓
OPA / Conftest
   ↓
COMPLIANCE GATE
   ├── PASS → Merge → Deploy
   └── FAIL → Block

🔐 Authentication: GitHub OIDC → AWS STS → IAM

No long-lived AWS access keys are stored in GitHub.

sequenceDiagram
    participant G as GitHub Actions
    participant O as GitHub OIDC
    participant S as AWS STS
    participant I as IAM Role
    participant A as AWS

    G->>O: Request OIDC token
    O-->>G: Identity token
    G->>S: AssumeRoleWithWebIdentity
    S->>I: Evaluate trust policy
    I-->>S: Allow / Deny
    S-->>G: Temporary credentials
    G->>A: AWS API calls

Traditional approach

GitHub Secrets
    │
    ├── AWS_ACCESS_KEY_ID
    └── AWS_SECRET_ACCESS_KEY
             │
             ▼
       Long-lived access

This project

GitHub Actions
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
AWS APIs

Why this is better

Control

Benefit

No permanent AWS keys

Smaller credential exposure window

OIDC federation

GitHub does not need an AWS secret

STS

Credentials are temporary

IAM trust policy

Restricts who can assume the role

IAM permissions

Restricts what the role can do

🧠 Authentication ≠ Authorization

This became one of the most important lessons during the build.

Trust policy

Who can assume this role?

Permission policy

What can the role do after it is assumed?

flowchart LR
    TOKEN[GitHub OIDC Token] --> TRUST[IAM Trust Policy]
    TRUST -->|Allowed| ROLE[IAM Role]
    TRUST -->|Denied| FAIL[❌ AssumeRole Failure]

    ROLE --> PERM[IAM Permission Policy]
    PERM --> AWS[AWS APIs]

Therefore:

OIDC authentication succeeds
            ≠
AWS API authorization succeeds

We experienced both sides of this distinction during the project.

🔎 Pull Request Compliance Pipeline

flowchart LR
    PR[Pull Request]
    PR --> FMT[fmt]
    FMT --> VAL[validate]
    VAL --> LINT[TFLint]
    LINT --> CHECK[Checkov]
    CHECK --> PLAN[Terraform Plan]
    PLAN --> JSON[tfplan.json]
    JSON --> OPA[OPA / Conftest]
    OPA --> GATE{Gate}
    GATE -->|PASS| MERGE[Merge]
    GATE -->|FAIL| BLOCK[Block]

What each stage does

Stage

Question it answers

terraform fmt

Is the Terraform consistently formatted?

terraform validate

Is the configuration structurally valid?

TFLint

Does the Terraform follow linting/provider rules?

Checkov

Does the IaC violate known security checks?

terraform plan

What infrastructure will actually change?

tfplan.json

What does Terraform intend to do in structured form?

OPA / Conftest

Does the planned infrastructure satisfy our organization policies?

📋 Why OPA / Conftest Runs After Terraform Plan

This is intentional.

Terraform configuration describes what the developer wrote.

Terraform plan describes what Terraform intends to do.

flowchart LR
    TF[Terraform .tf files]
    TF --> PLAN[terraform plan]
    PLAN --> SHOW[terraform show -json]
    SHOW --> JSON[tfplan.json]
    JSON --> OPA[OPA / Conftest]
    OPA --> DECISION[Policy Decision]

So the compliance check is performed against the planned infrastructure.

That gives us:

Code
 ↓
Terraform interprets it
 ↓
Terraform creates a plan
 ↓
Plan becomes JSON
 ↓
OPA evaluates the planned changes
 ↓
Compliance decision

🚦 Compliance Gate

The gate is the point where policy becomes an enforcement mechanism.

flowchart TD
    JSON[tfplan.json] --> OPA[OPA / Conftest]
    OPA --> GATE{COMPLIANCE GATE}

    GATE -->|PASS| MERGE[✅ PR may merge]
    GATE -->|FAIL| BLOCK[🛑 PR blocked]

Passing example

2 tests, 2 passed, 0 warnings, 0 failures

Failure example

FAIL - tfplan.json
Resource aws_s3_bucket.compliance_demo
must have an Owner tag

That failure was deliberately introduced and tested.

🧱 Terraform Infrastructure

The demo keeps the AWS infrastructure intentionally small.

Terraform manages an S3 bucket with:

🔐 AWS KMS encryption

🔄 Versioning

🚫 Public-access blocking

🏷️ Required tags

flowchart TD
    TF[Terraform]
    TF --> B[S3 Bucket]
    TF --> V[Versioning]
    TF --> E[KMS Encryption]
    TF --> P[Public Access Block]

    B --> AWS[(AWS S3)]
    V --> AWS
    E --> AWS
    P --> AWS

🗄️ Terraform Remote State

Terraform state is stored centrally in S3.

flowchart LR
    TF[Terraform] --> INIT[terraform init]
    INIT --> BACKEND[S3 Backend]
    BACKEND --> STATE["platform-compliance/terraform.tfstate"]

The remote-state bucket uses:

🔄 Versioning

🔐 Server-side encryption

🔒 Restricted access

Why remote state?

A team should not depend on a developer's local:

terraform.tfstate

Instead:

Developer / CI
      ↓
  Terraform
      ↓
 Central S3 State

🚀 Post-Merge Deployment

Once the PR passes the compliance gate and is merged:

flowchart TD
    PR[Approved PR] --> MERGE[Merge to main]
    MERGE --> DEPLOY[Terraform Deploy Workflow]

    DEPLOY --> OIDC[GitHub OIDC]
    OIDC --> STS[AWS STS]
    STS --> ROLE[IAM Role]
    ROLE --> CREDS[Temporary Credentials]

    DEPLOY --> INIT[terraform init]
    INIT --> PLAN[terraform plan]
    PLAN --> APPLY[terraform apply]
    APPLY --> AWS[(AWS Infrastructure)]

The deployment uses the same passwordless OIDC model.

☁️ Deployment Verification

The infrastructure was actually deployed — not just planned.

S3 bucket exists

aws s3api head-bucket \
  --bucket priest-platform-compliance-demo-417521971848

Verified:

BucketRegion: us-east-1

Versioning

aws s3api get-bucket-versioning \
  --bucket priest-platform-compliance-demo-417521971848

{
  "Status": "Enabled"
}

Public access protection

aws s3api get-public-access-block \
  --bucket priest-platform-compliance-demo-417521971848

{
  "BlockPublicAcls": true,
  "IgnorePublicAcls": true,
  "BlockPublicPolicy": true,
  "RestrictPublicBuckets": true
}

Encryption

aws s3api get-bucket-encryption \
  --bucket priest-platform-compliance-demo-417521971848

Verified:

SSEAlgorithm = aws:kms

Final AWS posture

Security control

Result

Bucket exists

✅

Versioning

✅ Enabled

KMS encryption

✅ Enabled

Block public ACLs

✅

Block public policies

✅

Restrict public buckets

✅

🧯 Real Failures We Encountered

This project intentionally documents the real engineering problems, not just the happy path.

1️⃣ OIDC Trust-Policy Failure

Symptom

GitHub Actions reported:

Could not assume role with OIDC:
Not authorized to perform sts:AssumeRoleWithWebIdentity

What was wrong?

The OIDC token reached AWS, but the IAM role's trust policy did not match the GitHub identity represented by the token.

The important claims included:

iss
aud
sub
repository
event_name
head_ref
base_ref

Resolution

The trust relationship was corrected to match the actual GitHub OIDC claims.

Afterward:

Configure AWS credentials  ✅
Verify AWS identity        ✅

Lesson

When OIDC fails, check:

OIDC provider exists in AWS

Correct provider ARN

aud = sts.amazonaws.com

sub matches the workflow/event

Workflow has id-token: write

2️⃣ s3:CreateBucket Authorization Failure

After OIDC authentication worked, Terraform reached AWS but failed with:

not authorized to perform:
s3:CreateBucket

What was wrong?

The role could be assumed, but its permission policy did not allow S3 bucket creation.

Authentication
      ↓
AssumeRoleWithWebIdentity
      ↓
SUCCESS
      ↓
Authorization
      ↓
s3:CreateBucket
      ↓
DENIED

Resolution

The required S3 permission was added to the role.

Lesson

OIDC identifies the workload. IAM permissions authorize the workload.

3️⃣ Terraform Needed Additional S3 Read Permissions

After s3:CreateBucket was fixed, Terraform exposed additional missing permissions while refreshing the bucket.

Examples included:

s3:GetBucketPolicy
s3:GetBucketCORS
s3:GetBucketWebsite
s3:GetAccelerateConfiguration
s3:GetBucketRequestPayment
s3:GetBucketLogging
s3:GetLifecycleConfiguration
s3:GetReplicationConfiguration
s3:GetObjectLockConfiguration

Why so many?

Terraform refreshes the resource before generating a plan.

Terraform Configuration
        ↓
Read current AWS resource
        ↓
Compare desired vs actual
        ↓
Generate plan

The AWS provider therefore needs permission to read the relevant S3 configuration.

Resolution

The missing read permissions were added incrementally based on the exact AWS API errors.

The final result:

Terraform Plan      ✅
Checkov             ✅
OPA / Conftest      ✅
Terraform Apply     ✅

Production lesson

Do not solve Terraform permission errors by immediately attaching AdministratorAccess.

Instead:

Read the denied API
       ↓
Understand why Terraform needs it
       ↓
Add the narrow permission
       ↓
Run again
       ↓
Review least privilege

4️⃣ BucketAlreadyExists

During testing, Terraform attempted to create a bucket that already existed.

AWS returned:

BucketAlreadyExists

Why?

The bucket existed in AWS, but Terraform state did not yet contain the resource correctly.

Resolution

The resource was imported:

terraform import aws_s3_bucket.compliance_demo \
  priest-platform-compliance-demo-417521971848

Then:

terraform state list

returned:

aws_s3_bucket.compliance_demo

Lesson

AWS resource exists
       +
Terraform state missing it
       ↓
terraform import

5️⃣ Remote-State Initialization

After moving Terraform to an S3 backend, Terraform required backend initialization.

Normal:

terraform init

If the backend configuration changes:

terraform init -reconfigure

If state actually needs to be migrated:

terraform init -migrate-state

Important

These commands are not interchangeable.

-reconfigure → accept a new backend configuration

-migrate-state → move existing state to the new backend configuration

🧪 Deliberate Compliance Failure

To prove that the policy gate was real, the required Owner tag was intentionally removed.

Conftest failed:

FAIL - tfplan.json
Resource aws_s3_bucket.compliance_demo
must have an Owner tag

The PR was therefore non-compliant.

After restoring:

Owner = "Platform-Team"

the policy passed:

2 tests, 2 passed
0 warnings, 0 failures

This proves the gate works

Non-compliant Terraform
        ↓
Terraform Plan
        ↓
tfplan.json
        ↓
OPA / Conftest
        ↓
FAIL
        ↓
PR BLOCKED

And:

Compliant Terraform
        ↓
Terraform Plan
        ↓
tfplan.json
        ↓
OPA / Conftest
        ↓
PASS
        ↓
PR MERGED
        ↓
Terraform Apply

🧰 Useful Commands

Terraform

terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
terraform apply tfplan

State

terraform state list
terraform state pull

Import

terraform import aws_s3_bucket.compliance_demo \
  priest-platform-compliance-demo-417521971848

AWS verification

aws s3api head-bucket \
  --bucket priest-platform-compliance-demo-417521971848

aws s3api get-bucket-versioning \
  --bucket priest-platform-compliance-demo-417521971848

aws s3api get-public-access-block \
  --bucket priest-platform-compliance-demo-417521971848

aws s3api get-bucket-encryption \
  --bucket priest-platform-compliance-demo-417521971848

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
├── Jenkinsfile
├── README.md
└── LICENSE

Keep these out of Git

terraform.tfstate
terraform.tfstate.*
.terraform/
tfplan
tfplan.json
.env
AWS access keys
AWS secret keys

🔁 Complete CI/CD Lifecycle

flowchart LR
    DEV[Developer] --> PR[Pull Request]
    PR --> CI[CI Security + Compliance]
    CI --> GATE{Policy Gate}

    GATE -->|FAIL| FIX[Fix]
    FIX --> PR

    GATE -->|PASS| MERGE[Merge]
    MERGE --> CD[Terraform Deploy]
    CD --> AWS[(AWS)]
    AWS --> VERIFY[CLI Verification]

The production-style flow

Code → Validate → Scan → Plan → Govern → Approve → Deploy → Verify

🏭 What Would Change in Production?

This demo intentionally keeps the infrastructure small. A real platform could add:

🔐 Identity & Access

Separate plan and apply roles

Dedicated deployment accounts

IAM permissions boundaries

AWS Organizations SCPs

IAM Access Analyzer

CloudTrail

🧱 Terraform

Reusable modules

Environment separation

Strong state isolation

Provider/version governance

Module versioning

🚦 CI/CD

Protected main

Required PR approvals

Required status checks

Environment approvals

Artifact retention

Notifications

🛡️ Security & Compliance

Approved AWS regions

Mandatory encryption

Required logging

Required tags

Naming standards

Public-access controls

Cost policies

☁️ AWS

Multi-account architecture

Dedicated state account

KMS key management

AWS Config

GuardDuty

Security Hub

🔜 Next Phase: Jenkins

The next phase is to reproduce the CI/CD orchestration in Jenkins.

We do not need to duplicate the AWS infrastructure.

We reuse:

terraform/
policies/
scripts/

and add Jenkins orchestration.

flowchart TD
    TF[Shared Terraform] --> GA[GitHub Actions]
    TF --> J[Jenkins]

    POL[Shared OPA Policies] --> GA
    POL --> J

    GA --> G1[Compliance Gate]
    J --> G2[Compliance Gate]

    G1 --> AWS[(AWS)]
    G2 --> AWS

Goal

Demonstrate the same platform controls through two enterprise CI/CD platforms:

GitHub Actions ──┐
                 ├── Same Terraform + Same Policies → AWS
Jenkins ─────────┘

🎤 Senior DevOps Interview Summary

I built a Terraform platform-compliance pipeline using GitHub Actions. Pull requests run Terraform formatting and validation, TFLint, Checkov, and Terraform plan. The plan is converted to JSON and evaluated with OPA/Conftest, creating a compliance gate before merge. GitHub Actions authenticates to AWS through OIDC and STS instead of long-lived AWS keys. After an approved merge, a deployment workflow assumes an IAM role through OIDC and runs Terraform against an S3 remote backend. The infrastructure was deployed to AWS and verified with the AWS CLI. I also deliberately tested a policy failure and worked through real OIDC trust-policy and least-privilege IAM permission failures during implementation.

🏆 Final Capability Checklist

Terraform Infrastructure as Code

Pull-request validation

Terraform fmt

Terraform validate

TFLint

Checkov

Terraform Plan

Terraform Plan JSON

OPA / Conftest

Compliance gate

GitHub OIDC

AWS STS

IAM trust policy

IAM permission policy

Temporary credentials

S3 remote state

Automated Terraform deployment

S3 versioning

KMS encryption

Public-access blocking

Deliberate compliance failure

OIDC troubleshooting

IAM least-privilege troubleshooting

Terraform resource import

AWS CLI verification

Jenkins implementation

<div align="center">

🚀 Platform Compliance Demo

Terraform · AWS · GitHub Actions · OIDC · IAM · STS · TFLint · Checkov · OPA · Conftest

Built as a hands-on Senior DevOps / Platform Engineering demonstration.

</div>
