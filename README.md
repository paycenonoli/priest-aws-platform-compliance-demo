AWS Platform Compliance Demo

A production-style DevOps platform engineering demonstration that
combines Terraform, GitHub Actions, AWS IAM/OIDC, TFLint, Checkov,
OPA/Conftest, and automated Terraform deployment.

The project demonstrates how infrastructure changes can move from a
developer's pull request through automated security/compliance checks,
into a controlled merge, and finally into AWS---without storing
long-lived AWS access keys in GitHub.

Current status: The GitHub Actions implementation is complete and
has been successfully tested end-to-end.
The Jenkins implementation is the next planned phase and will reuse
the same Terraform infrastructure and compliance policies.

1. What This Project Demonstrates

This project answers a practical production question:

How do we make sure Terraform infrastructure is secure and compliant
before it reaches AWS, while still allowing approved changes to be
deployed automatically?

The implementation uses two separate stages:

Pull Request / Compliance Pipeline

Every relevant pull request runs:

Terraform formatting

Terraform validation

TFLint

Checkov

Terraform plan

OPA / Conftest policy validation

The resulting Terraform plan is converted to JSON and evaluated against
organizational policies.

If the compliance tests fail, the pull request is blocked.

Deployment Pipeline

After the pull request passes compliance and is merged:

GitHub Actions authenticates to AWS using OIDC

Terraform initializes against the remote S3 state backend

Terraform creates the approved infrastructure

Terraform apply deploys the infrastructure to AWS

2. Architecture

Complete End-to-End Architecture

                           DEVELOPER
                               |
                               v
                       GitHub Pull Request
                               |
                               v
                 +---------------------------+
                 |    GitHub Actions         |
                 |    PR Compliance          |
                 +-------------+-------------+
                               |
              +----------------+----------------+
              |                                 |
              v                                 v
      OIDC Authentication                 Terraform Checks
              |                                 |
              v                    +------------+------------+
          AWS STS                  |            |            |
              |                    v            v            v
              v                 fmt/validate  TFLint      Checkov
          IAM Role
              |
              v
     Temporary AWS Credentials
              |
              +----------------------------------+
                                                 |
                                                 v
                                        Terraform Plan
                                                 |
                                                 v
                                            tfplan
                                                 |
                                                 v
                                           tfplan.json
                                                 |
                                                 v
                                       OPA / Conftest
                                                 |
                                                 v
                                      +-------------------+
                                      | COMPLIANCE GATE   |
                                      +---------+---------+
                                                |
                                  +-------------+-------------+
                                  |                           |
                                PASS                         FAIL
                                  |                           |
                                  v                           v
                                MERGE                       BLOCK
                                  |
                                  v
                                main
                                  |
                                  v
                    +---------------------------+
                    | Terraform Deploy Workflow |
                    +-------------+-------------+
                                  |
                                  v
                         OIDC -> AWS STS
                                  |
                                  v
                             IAM Role
                                  |
                                  v
                       Temporary Credentials
                                  |
                                  v
                       Terraform Init / Plan
                                  |
                                  v
                         Terraform Apply
                                  |
                                  v
                              AWS S3
                                  |
              +-------------------+-------------------+
              |                   |                   |
              v                   v                   v
          Versioning          KMS Encryption    Public Access
             ON                    ON               BLOCKED

3. AWS Authentication Architecture

The project intentionally avoids storing an AWS access key and secret
key in GitHub.

Instead, GitHub Actions obtains a short-lived OIDC token and exchanges
it with AWS STS.

GitHub Actions Runner
        |
        | 1. Request OIDC token
        v
GitHub OIDC Provider
token.actions.githubusercontent.com
        |
        | 2. Web identity token
        v
AWS STS
sts:AssumeRoleWithWebIdentity
        |
        | 3. Validate IAM trust policy
        v
IAM Role
GitHubActions-PlatformCompliance
        |
        | 4. Issue temporary credentials
        v
GitHub Actions Runner
        |
        | 5. Use temporary credentials
        v
AWS APIs

Why OIDC?

Traditional CI/CD authentication often uses:

AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY

Those are long-lived credentials.

This project instead uses:

GitHub OIDC token
        |
        v
AWS STS
        |
        v
Temporary AWS credentials

Advantages:

No long-lived AWS secret stored in GitHub

Credentials are short-lived

IAM trust policy can restrict which GitHub repository/workflow
context can assume the role

Access can be revoked centrally through IAM

Better alignment with production cloud security practices

4. IAM OIDC Trust Policy

The IAM role trusts GitHub's OIDC provider.

The trust relationship used during the demo was based on the repository
and pull-request identity supplied in the GitHub OIDC sub claim.

Conceptually:

GitHub repository
      |
      | OIDC token
      v
token.actions.githubusercontent.com
      |
      | subject + audience
      v
IAM Trust Policy
      |
      | authorized?
      +---- NO ----> AssumeRole fails
      |
     YES
      |
      v
AWS STS

The trust relationship included conditions equivalent to:

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
          "token.actions.githubusercontent.com:sub": "<AUTHORIZED_GITHUB_SUBJECT>"
        }
      }
    }
  ]
}

Important: The exact sub value must match the GitHub
event/context being authorized. A trust policy that works for one
GitHub event may not automatically authorize another event.

5. IAM Permission Policy

The IAM role also requires an identity-based permission policy.

The trust policy answers:

Who is allowed to assume this role?

The permissions policy answers:

What can the role do after it assumes the role?

These are different controls.

Trust Policy
     |
     +--> Can GitHub assume the role?
                  |
                 YES
                  |
                  v
        Permission Policy
                  |
                  +--> Can Terraform call S3?

For this demo, the role was intentionally given scoped S3 permissions
for the demonstration bucket.

During Terraform refresh, we discovered that the AWS provider reads more
S3 attributes than may initially be obvious from the Terraform
configuration. The policy therefore had to include the corresponding
read permissions.

Examples encountered during troubleshooting included:

s3:CreateBucket
s3:GetBucketLocation
s3:GetBucketAcl
s3:ListBucket
s3:GetBucketPolicy
s3:GetBucketCORS
s3:GetBucketVersioning
s3:PutBucketVersioning
s3:GetEncryptionConfiguration
s3:PutEncryptionConfiguration
s3:GetBucketPublicAccessBlock
s3:PutBucketPublicAccessBlock
s3:GetBucketTagging
s3:PutBucketTagging
s3:GetBucketWebsite
s3:GetAccelerateConfiguration
s3:GetBucketRequestPayment
s3:GetBucketLogging
s3:GetLifecycleConfiguration
s3:GetReplicationConfiguration
s3:GetObjectLockConfiguration

The exact policy should be reviewed and minimized further for a
production implementation.

6. Terraform Architecture

The infrastructure is intentionally simple so the security/compliance
workflow remains the focus.

The Terraform configuration creates an S3 bucket with:

Versioning

Server-side encryption using AWS KMS

Public-access blocking

Resource tags

Conceptually:

Terraform
   |
   +---- aws_s3_bucket
   |
   +---- aws_s3_bucket_versioning
   |
   +---- aws_s3_bucket_server_side_encryption_configuration
   |
   +---- aws_s3_bucket_public_access_block
   |
   v
AWS S3

7. Terraform Remote State

The project uses an S3 bucket for Terraform remote state.

Example backend architecture:

GitHub Actions
      |
      v
Terraform
      |
      | terraform init
      v
S3 Backend
      |
      +--> bucket:
      |    priest-platform-compliance-tfstate-<ACCOUNT_ID>
      |
      +--> key:
           platform-compliance/terraform.tfstate

The state bucket was configured with:

Versioning enabled

Server-side encryption

Restricted access

Why remote state?

Terraform state contains information Terraform needs to understand the
infrastructure it manages.

A production team should not depend on a developer's local:

terraform.tfstate

Instead:

Developer / CI
      |
      v
Terraform
      |
      v
Centralized Remote State

This allows different execution environments to work against the same
state.

8. Terraform Plan -> JSON -> OPA

This is one of the most important concepts in the project.

Terraform produces a plan:

terraform plan -out=tfplan

The binary plan is then converted to JSON:

terraform show -json tfplan > tfplan.json

OPA/Conftest evaluates the JSON representation.

Terraform Configuration
        |
        v
terraform plan
        |
        v
     tfplan
        |
        v
terraform show -json
        |
        v
   tfplan.json
        |
        v
Conftest / OPA
        |
        v
terraform.rego
        |
        v
Compliance Result

Why not run OPA directly against .tf files?

OPA is evaluating policy against structured data.

The Terraform plan contains information about the infrastructure
Terraform actually intends to create or change.

That makes the plan a useful policy boundary:

What the developer wrote
          |
          v
What Terraform intends to do
          |
          v
What policy allows

9. Compliance Gate

The compliance gate is the point where the pipeline decides whether the
infrastructure change is acceptable.

Terraform Plan
      |
      v
   tfplan.json
      |
      v
OPA / Conftest
      |
      +------------------+
      |                  |
      v                  v
    PASS                FAIL
      |                  |
      v                  v
  Allow merge       Block merge

For example, the demo policy verifies that the S3 bucket contains the
required Owner tag.

A compliant plan:

2 tests, 2 passed
0 warnings
0 failures

A deliberately non-compliant change produced:

FAIL - Resource aws_s3_bucket.compliance_demo
must have an Owner tag

That demonstrated that the compliance gate actually works rather than
merely reporting success.

10. Security Tools and Their Responsibilities

The project uses several tools because they solve different problems.

Tool                 Purpose

Terraform fmt        Formatting consistency
Terraform validate   Terraform configuration validation
TFLint               Terraform linting and provider-specific checks
Checkov              Infrastructure security/static analysis
Terraform plan       Shows intended infrastructure changes
OPA                  Policy-as-code engine
Conftest             Runs OPA policies against configuration/data
AWS IAM              Authorization
AWS STS              Temporary credentials
GitHub OIDC          Federated identity
S3                   Terraform remote state and demo infrastructure

11. GitHub Actions PR Workflow

The compliance workflow runs against pull requests that modify relevant
infrastructure or policy files.

Conceptually:

Pull Request
     |
     v
Checkout
     |
     v
Configure AWS Credentials
     |
     v
Terraform Setup
     |
     +---- Terraform fmt
     |
     +---- Terraform validate
     |
     +---- TFLint
     |
     +---- Checkov
     |
     +---- Terraform plan
     |
     v
tfplan.json
     |
     v
OPA / Conftest
     |
     v
Compliance Gate

Important ordering

OPA/Conftest comes after Terraform plan because the policy is
evaluating the planned infrastructure.

That means:

Terraform configuration
        |
        v
Terraform plan
        |
        v
Planned infrastructure
        |
        v
OPA/Conftest

This is different from tools such as TFLint and Checkov, which can
inspect the Terraform configuration directly.

12. Deployment Workflow

After the pull request passes and is merged, the deployment workflow
runs.

Merged Pull Request
        |
        v
      main
        |
        v
Terraform Deploy
        |
        +--> Checkout
        |
        +--> Configure AWS Credentials
        |
        +--> Verify AWS identity
        |
        +--> Terraform setup
        |
        +--> Terraform init
        |
        +--> Terraform plan
        |
        +--> Terraform apply
        |
        v
      AWS

The deployment uses the same OIDC-based AWS authentication model rather
than storing long-lived AWS credentials.

13. Actual AWS Result

The deployment was independently verified from the AWS CLI.

Bucket exists

aws s3api head-bucket \
  --bucket priest-platform-compliance-demo-417521971848

Result:

BucketArn: arn:aws:s3:::priest-platform-compliance-demo-417521971848
BucketRegion: us-east-1

Versioning

aws s3api get-bucket-versioning \
  --bucket priest-platform-compliance-demo-417521971848

Result:

{
  "Status": "Enabled"
}

Public access protection

aws s3api get-public-access-block \
  --bucket priest-platform-compliance-demo-417521971848

Result:

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

Result:

SSEAlgorithm = aws:kms

Therefore the infrastructure was not merely planned; the actual AWS
resource was verified.

14. Challenges Encountered and Resolutions

This section documents the real troubleshooting performed while building
the demo.

These challenges are intentionally included because they demonstrate
practical cloud/DevOps troubleshooting rather than a "happy path"
tutorial.

Challenge 1: GitHub OIDC Trust Policy Failure

Symptom

The workflow failed at:

Configure AWS credentials

with:

Could not assume role with OIDC:
Not authorized to perform sts:AssumeRoleWithWebIdentity

The workflow retried multiple times.

Cause

AWS STS was receiving the GitHub OIDC token, but the IAM role's trust
policy did not authorize that token's identity.

The important distinction:

OIDC provider exists
        !=
IAM role trusts the GitHub identity

Investigation

The workflow inspected the OIDC claims.

Important claims included:

iss
aud
sub
repository
event_name
ref
head_ref
base_ref

The sub claim was particularly important because the IAM trust policy
used it to restrict which GitHub identity could assume the role.

Resolution

The IAM trust relationship was corrected so that the GitHub OIDC
identity used by the workflow was authorized.

After the correction:

Configure AWS credentials     PASS
Verify AWS identity           PASS

Lesson

When GitHub Actions cannot assume an AWS role, check:

GitHub OIDC provider exists in AWS

IAM trust policy references the correct provider

aud matches sts.amazonaws.com

sub matches the actual GitHub OIDC subject

The workflow has:

permissions:
  id-token: write
  contents: read

15. Challenge 2: Missing S3 Create Permission

After OIDC authentication was fixed, the workflow reached Terraform but
failed during deployment.

Error:

not authorized to perform:
s3:CreateBucket

Cause

The IAM role was successfully assumed, but the role did not have
permission to create the S3 bucket.

This demonstrated an important AWS security concept:

Authentication / Assume Role
            |
            v
        SUCCESS
            |
            v
Authorization
            |
            v
       s3:CreateBucket
            |
            v
          DENIED

OIDC authentication does not automatically grant AWS permissions.

Resolution

The required S3 permissions were added to the role's identity-based
policy.

16. Challenge 3: Terraform Refresh Required More S3 Permissions

After adding s3:CreateBucket, Terraform still failed.

The errors progressively exposed additional permissions.

Examples included:

s3:GetBucketPolicy
s3:GetBucketCORS
s3:GetBucketWebsite
s3:GetAccelerateConfiguration
s3:GetBucketRequestPayment

Later, additional Terraform provider refresh operations required:

s3:GetBucketLogging
s3:GetLifecycleConfiguration
s3:GetReplicationConfiguration
s3:GetObjectLockConfiguration

Why did this happen?

Terraform does not simply execute:

CREATE S3 BUCKET

and stop.

During refresh and planning, the AWS provider reads the existing
resource and its attributes to determine the current state.

Conceptually:

Terraform Plan
      |
      v
Refresh AWS resource
      |
      +--> GetBucketPolicy
      +--> GetBucketCORS
      +--> GetBucketWebsite
      +--> GetBucketLogging
      +--> GetLifecycleConfiguration
      +--> ...
      |
      v
Compare AWS state
with Terraform configuration
      |
      v
Generate plan

Therefore, an IAM role used by Terraform needs enough read access to
inspect the resources it manages.

Resolution

The missing read permissions were added to the IAM policy.

The workflow eventually reached:

Terraform Plan       PASS
Checkov               PASS
OPA / Conftest        PASS
Terraform Apply       PASS

Lesson

A Terraform IAM policy must account for both:

Actions needed to create/update/delete resources

Actions needed to read/refresh those resources during Terraform
planning

For production, the final policy should be deliberately reviewed and
minimized rather than blindly adding every permission requested by an
error message.

17. Challenge 4: BucketAlreadyExists

During testing, Terraform attempted to create:

priest-platform-compliance-demo-417521971848

but AWS returned:

BucketAlreadyExists

What happened?

The bucket had already been created during an earlier deployment
attempt.

Terraform did not yet have that bucket represented correctly in its
current state, so Terraform believed it needed to create it.

Resolution

The existing bucket was imported:

terraform import aws_s3_bucket.compliance_demo \
  priest-platform-compliance-demo-417521971848

Then:

terraform state list

showed:

aws_s3_bucket.compliance_demo

This brought the existing AWS resource under Terraform management.

18. Challenge 5: Understanding Remote State

The project initially required clarification around the difference
between:

Terraform configuration
Terraform state
AWS infrastructure

These are not the same thing.

Configuration

main.tf
variables.tf
outputs.tf

describes the desired infrastructure.

State

Terraform state records what Terraform knows about the infrastructure it
manages.

AWS

AWS contains the actual resources.

The relationship is:

Terraform Configuration
          |
          | desired state
          v
      Terraform
          |
          | state
          v
   Remote S3 Backend
          |
          |
          v
      AWS Resources

The remote state was verified in S3 at:

platform-compliance/terraform.tfstate

19. Challenge 6: Terraform Backend Initialization

After introducing the S3 backend, Terraform reported:

Backend initialization required

The solution was:

terraform init

When the backend configuration changes, Terraform may require:

terraform init -reconfigure

or, when appropriate for an actual state migration:

terraform init -migrate-state

Important distinction

-reconfigure tells Terraform to use the new backend configuration
without attempting to migrate the existing state.

-migrate-state is used when state needs to be moved from one backend
configuration to another.

Always understand which operation is appropriate before using either
option in a production environment.

20. Compliance Failure Demonstration

The project intentionally included a failing compliance test.

The policy required the S3 bucket to have an Owner tag.

A non-compliant Terraform plan resulted in:

FAIL - tfplan.json
Resource aws_s3_bucket.compliance_demo
must have an Owner tag

The workflow then failed:

2 tests, 1 passed, 1 failure

After restoring the required tag:

2 tests, 2 passed
0 warnings
0 failures

This proves the compliance gate is functional.

21. Why This Is More Than a Terraform Project

The actual project demonstrates several layers of DevOps engineering.

                    DevOps Platform
                          |
        +-----------------+-----------------+
        |                 |                 |
        v                 v                 v
   Infrastructure      Security          Automation
        |                 |                 |
    Terraform          IAM/OIDC         GitHub Actions
        |              Checkov           CI/CD
        |              OPA
        |              Conftest
        v
       AWS

It also demonstrates the separation of concerns:

Terraform
    |
    +--> Infrastructure provisioning

TFLint
    |
    +--> Terraform quality/linting

Checkov
    |
    +--> Security/static analysis

OPA/Conftest
    |
    +--> Organizational compliance policy

IAM/OIDC
    |
    +--> Secure cloud authentication/authorization

GitHub Actions
    |
    +--> CI/CD orchestration

22. Suggested Repository Structure

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
│   └── ...
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
├── Jenkinsfile                 # planned Jenkins phase
├── README.md
└── LICENSE

Do not commit:

terraform.tfstate
terraform.tfstate.*
.terraform/
tfplan
tfplan.json
.env
AWS access keys
AWS secret keys

23. Useful Local Commands

Terraform

Initialize:

terraform init

Format:

terraform fmt -recursive

Validate:

terraform validate

Plan:

terraform plan

Save a plan:

terraform plan -out=tfplan

Convert plan to JSON:

terraform show -json tfplan > tfplan.json

Apply:

terraform apply tfplan

Inspect state:

terraform state list

Pull remote state:

terraform state pull

Import an existing resource:

terraform import aws_s3_bucket.compliance_demo \
  priest-platform-compliance-demo-417521971848

24. AWS Verification Commands

Check the bucket:

aws s3api head-bucket \
  --bucket priest-platform-compliance-demo-417521971848

Check versioning:

aws s3api get-bucket-versioning \
  --bucket priest-platform-compliance-demo-417521971848

Check public access:

aws s3api get-public-access-block \
  --bucket priest-platform-compliance-demo-417521971848

Check encryption:

aws s3api get-bucket-encryption \
  --bucket priest-platform-compliance-demo-417521971848

Check the Terraform state object:

aws s3api list-objects-v2 \
  --bucket priest-platform-compliance-tfstate-417521971848 \
  --prefix platform-compliance/

25. Testing the Compliance Gate

A useful demonstration is to intentionally introduce a policy violation.

For example, remove the required Owner tag from the Terraform
configuration.

Then:

git checkout -b test/compliance-failure

Make the change and push:

git add .
git commit -m "test: demonstrate compliance policy failure"
git push -u origin test/compliance-failure

Open a pull request.

Expected result:

Terraform Plan
      |
      v
OPA / Conftest
      |
      v
FAIL
      |
      v
Pull Request blocked

Restore the required configuration:

Owner = Platform-Team

Push the fix.

Expected result:

OPA / Conftest
      |
      v
PASS
      |
      v
Pull Request can be merged

26. Production Improvements

This project intentionally focuses on demonstrating the architecture. A
production implementation would add further controls.

Potential improvements include:

IAM

Separate plan and apply roles

Separate CI and deployment roles

Least-privilege IAM policies

IAM permissions boundaries

AWS Organizations/SCP controls

CloudTrail monitoring

Access Analyzer

Terraform

Remote state with tightly controlled access

State locking where supported/appropriate

Separate environments

Terraform modules

Version pinning

Provider upgrade strategy

CI/CD

Protected main

Required PR approvals

Required status checks

Environment approvals

Separate plan and apply jobs

Artifact retention

Security scanning

Notifications

Compliance

More OPA policies

Policies for encryption

Policies for public access

Required tags

Required logging

Approved regions

Resource naming standards

Cost-control policies

AWS

Dedicated deployment account

Dedicated state account

Multi-account architecture

KMS key management

CloudTrail

GuardDuty

Security Hub

Config rules

27. Next Phase: Jenkins

The GitHub Actions implementation will be duplicated conceptually using
Jenkins.

The important design principle is:

Do not duplicate the infrastructure or compliance rules
unnecessarily. Duplicate the CI/CD orchestration layer.

The future architecture will look like:

                         Terraform
                             |
               +-------------+-------------+
               |                           |
               v                           v
        GitHub Actions                  Jenkins
               |                           |
               v                           v
       Compliance Pipeline        Compliance Pipeline
               |                           |
               +-------------+-------------+
                             |
                             v
                      Terraform Plan
                             |
                             v
                       OPA / Conftest
                             |
                             v
                      Compliance Gate
                             |
                             v
                         Terraform
                             |
                             v
                            AWS

The same:

terraform/
policies/

can therefore be reused.

The Jenkins implementation will demonstrate how the same platform
controls can be implemented in another enterprise CI/CD platform.

28. Interview Explanation

A concise way to explain this project in a Senior DevOps interview:

"I built a Terraform platform compliance pipeline using GitHub
Actions. Pull requests trigger Terraform formatting and validation,
TFLint, Checkov, and Terraform plan. The plan is converted to JSON and
evaluated with OPA/Conftest policies. The compliance result acts as a
merge gate. GitHub Actions authenticates to AWS using OIDC and STS
rather than long-lived AWS credentials. After the PR passes and is
merged, a deployment workflow assumes the AWS IAM role through OIDC
and runs Terraform against an S3 remote backend. The infrastructure
deployed is an S3 bucket with versioning, KMS encryption, and
public-access blocking. I also deliberately tested compliance failures
and resolved real OIDC trust-policy and least-privilege IAM permission
issues encountered during implementation."

29. Key Lessons

Authentication vs Authorization

OIDC
 |
 v
Authentication / Federation
 |
 v
IAM Role
 |
 v
Authorization through IAM policies

Successfully assuming an IAM role does not mean the role can perform
every AWS action.

Plan vs Compliance

Terraform Plan
      |
      v
What Terraform intends to change
      |
      v
OPA / Conftest
      |
      v
Is that change allowed?

Configuration vs State vs Infrastructure

.tf files
   |
   v
Terraform
   |
   +---- Remote State
   |
   v
AWS

These are separate concepts and should not be confused.

CI vs CD

CI
 |
 +--> fmt
 +--> validate
 +--> lint
 +--> security scan
 +--> plan
 +--> compliance
 |
 +--> Merge

Then:

CD
 |
 +--> authenticate
 +--> init
 +--> plan
 +--> apply
 |
 +--> AWS

30. Final Project Outcome

The completed GitHub Actions implementation provides:

Terraform infrastructure as code

GitHub Pull Request workflow

Terraform formatting

Terraform validation

TFLint

Checkov

Terraform plan

Terraform plan JSON

OPA/Conftest policy-as-code

Compliance gate

GitHub OIDC authentication

AWS STS federation

IAM role-based access

Temporary AWS credentials

Terraform remote S3 state

Automated Terraform deployment

S3 versioning

KMS encryption

S3 public-access blocking

Intentional compliance failure test

Real IAM/OIDC troubleshooting

Independent AWS verification

The next major milestone is the Jenkins implementation, using the
same Terraform and compliance architecture.

Project Architecture in One Picture

                       +----------------+
                       |    Developer   |
                       +-------+--------+
                               |
                               v
                       +---------------+
                       | GitHub PR     |
                       +-------+-------+
                               |
                               v
                  +-------------------------+
                  | GitHub Actions          |
                  | PR Compliance           |
                  +-----------+-------------+
                              |
             +----------------+----------------+
             |                                 |
             v                                 v
      GitHub OIDC                         Quality/Security
             |                                 |
             v                      +----------+----------+
         AWS STS                    |          |          |
             |                      v          v          v
             v                    TFLint   Checkov    Terraform
         IAM Role                                       fmt/validate
             |                                              |
             v                                              v
    Temporary Credentials                             Terraform Plan
                                                            |
                                                            v
                                                       tfplan.json
                                                            |
                                                            v
                                                     OPA / Conftest
                                                            |
                                                            v
                                                   +----------------+
                                                   | COMPLIANCE GATE|
                                                   +-------+--------+
                                                           |
                                               +-----------+-----------+
                                               |                       |
                                             PASS                     FAIL
                                               |                       |
                                               v                       v
                                             MERGE                   BLOCK
                                               |
                                               v
                                             main
                                               |
                                               v
                                    +----------------------+
                                    | Terraform Deployment |
                                    +----------+-----------+
                                               |
                                               v
                                          GitHub OIDC
                                               |
                                               v
                                            AWS STS
                                               |
                                               v
                                           IAM Role
                                               |
                                               v
                                          Terraform
                                            Apply
                                               |
                                               v
                                      +-------------------+
                                      |       AWS S3      |
                                      |                   |
                                      | Versioning   ✓    |
                                      | KMS          ✓    |
                                      | Public Block ✓    |
                                      +-------------------+

This is the current, end-to-end state of the project.
