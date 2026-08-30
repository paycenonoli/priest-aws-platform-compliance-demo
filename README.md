AWS Platform Compliance Demo — Jenkins CI/CD

<div align="center">

🔐 AWS Platform Compliance Demo

Jenkins • Docker Agents • Terraform • TFLint • Checkov • OPA • Conftest • AWS

A production-style DevSecOps demonstration of infrastructure compliance enforced through Jenkins

</div>

📋 Table of Contents

1. Project Overview

2. What This Project Demonstrates

3. Architecture

4. Jenkins Controller vs Agent

5. Why We Use a Custom Docker Agent

6. Repository Structure

7. Toolchain

8. Jenkins EC2 Infrastructure

9. Building the Custom Agent Image

10. Testing the Agent Image

11. Jenkins Docker Integration

12. Jenkinsfile

13. CI/CD Pipeline Flow

14. Terraform Compliance Workflow

15. TFLint

16. Checkov

17. OPA and Conftest

18. AWS Authentication

19. Security Model

20. Challenges Encountered and Resolutions

21. Troubleshooting

22. Commands Reference

23. Production Improvements

24. Senior DevOps Interview Talking Points

25. Final Architecture

1. Project Overview

This project demonstrates how an organization can implement Infrastructure as Code compliance and security controls inside a Jenkins CI/CD pipeline.

Terraform is used to define AWS infrastructure, while multiple automated quality and security controls evaluate the configuration before it can be deployed.

The project intentionally separates:

Jenkins controller responsibilities

Jenkins agent responsibilities

infrastructure validation

security scanning

policy enforcement

AWS authentication

infrastructure deployment

The goal is to demonstrate a Jenkins implementation that resembles a real enterprise DevSecOps workflow rather than a simple terraform apply job.

2. What This Project Demonstrates

The pipeline is designed around the following controls:

Developer
    │
    │ Git push / Pull Request
    ▼
 GitHub
    │
    ▼
 Jenkins
    │
    ▼
 Docker-based Jenkins Agent
    │
    ├── Terraform
    ├── TFLint
    ├── Checkov
    ├── OPA
    └── Conftest
    │
    ▼
 Compliance / Security Gate
    │
    ├───────────────┐
    │               │
   PASS            FAIL
    │               │
    ▼               ▼
Continue         Stop Pipeline
    │
    ▼
Terraform Plan / Apply

The project demonstrates:

Infrastructure as Code

CI/CD

DevSecOps

Policy as Code

Shift-left security

Immutable build environments

Ephemeral CI agents

Least-privilege AWS access

Automated compliance gates

Separation of build and deployment responsibilities

3. Architecture

High-Level Architecture

                         ┌─────────────────┐
                         │    Developer    │
                         └────────┬────────┘
                                  │
                                  │ Git Push / PR
                                  ▼
                         ┌─────────────────┐
                         │     GitHub      │
                         │   Repository    │
                         └────────┬────────┘
                                  │
                                  │ Webhook / SCM Trigger
                                  ▼
                    ┌──────────────────────────┐
                    │    Jenkins Controller    │
                    │        AWS EC2           │
                    └────────────┬─────────────┘
                                 │
                                 │ Docker Plugin
                                 ▼
                    ┌──────────────────────────┐
                    │      Docker Engine       │
                    │        AWS EC2           │
                    └────────────┬─────────────┘
                                 │
                                 │ Provision
                                 ▼
              ┌─────────────────────────────────────────┐
              │      Custom Jenkins Agent Container     │
              │                                         │
              │  Git          Terraform                │
              │  TFLint       Checkov                  │
              │  OPA          Conftest                 │
              │  AWS CLI                               │
              └───────────────────┬─────────────────────┘
                                  │
                                  ▼
                    ┌──────────────────────────┐
                    │      CI Validation       │
                    ├──────────────────────────┤
                    │ Terraform fmt             │
                    │ Terraform validate        │
                    │ TFLint                    │
                    │ Checkov                   │
                    │ OPA / Conftest            │
                    └────────────┬─────────────┘
                                 │
                         Compliance Gate
                                 │
                      ┌──────────┴──────────┐
                      │                     │
                     PASS                  FAIL
                      │                     │
                      ▼                     ▼
                Terraform Plan        Pipeline Stops
                      │
                      ▼
                Terraform Apply
                      │
                      ▼
                     AWS

4. Jenkins Controller vs Agent

The project demonstrates the distinction between the Jenkins controller and the Jenkins agent.

Jenkins Controller

The controller is responsible for orchestration. It:

receives build requests

loads Jenkinsfiles

schedules pipeline stages

manages jobs

communicates with agents

records build results

provides the Jenkins UI

The controller should not be treated as the place where every build tool is manually installed.

Jenkins Agent

The agent performs the actual workload:

Jenkins Agent
│
├── Git
├── Terraform
├── AWS CLI
├── TFLint
├── Checkov
├── OPA
└── Conftest

The relationship is:

             Jenkins Controller
                     │
                     │ schedules work
                     ▼
              Jenkins Agent
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
      Terraform    Checkov     OPA
          │          │          │
          └──────────┼──────────┘
                     ▼
                    AWS

5. Why We Use a Custom Docker Agent

A common approach is to install every build tool directly on the Jenkins server:

Jenkins EC2
│
├── Terraform
├── AWS CLI
├── TFLint
├── Checkov
├── OPA
└── Conftest

This creates:

manual server configuration

version drift

difficult upgrades

inconsistent build environments

poor reproducibility

harder disaster recovery

Instead, this project packages the toolchain into an immutable Docker image:

                    Dockerfile
                        │
                        ▼
             ┌────────────────────┐
             │  Jenkins Agent     │
             │       Image        │
             ├────────────────────┤
             │ Git                │
             │ Terraform          │
             │ AWS CLI            │
             │ TFLint             │
             │ Checkov            │
             │ OPA                │
             │ Conftest           │
             └─────────┬──────────┘
                       │
                       ▼
              Jenkins Agent
              Container

Every agent created from the image receives the same toolchain.

6. Repository Structure

priest-aws-platform-compliance-demo/
│
├── .checkov.yaml
├── .gitignore
├── Jenkinsfile
├── README.md
├── demo-architecture
│
├── jenkins/
│   └── agent/
│       └── Dockerfile
│
├── policies/
│   └── terraform.rego
│
├── scripts/
│   ├── policy-check.sh
│   └── security-check.sh
│
└── terraform/
    ├── backend.tf
    ├── main.tf
    ├── outputs.tf
    ├── s3-security.tf
    ├── variables.tf
    ├── versions.tf
    ├── .tflint.hcl
    └── .terraform.lock.hcl

The Jenkins implementation is maintained on:

jenkins/platform-compliance

7. Toolchain

Tool

Purpose

Jenkins

CI/CD orchestration

Docker

Agent container runtime

Git

Source control

Terraform

Infrastructure as Code

TFLint

Terraform linting

Checkov

Infrastructure security scanning

OPA

Policy evaluation engine

Conftest

Policy testing

AWS CLI

AWS interaction

The tested custom agent contained:

Git         2.47.3
Terraform   1.16.0
AWS CLI     2.36.34
TFLint      0.64.0
Checkov     3.3.16
OPA         1.20.1
Conftest    0.69.0

Tool versions can change when the image is rebuilt. Production images should pin tested versions.

8. Jenkins EC2 Infrastructure

Jenkins was installed on a dedicated AWS EC2 instance.

                    AWS EC2
                       │
          ┌────────────┴────────────┐
          │                         │
          ▼                         ▼
 Jenkins Controller            Docker Engine
          │                         │
          └─────────────┬───────────┘
                        │
                        ▼
                 Jenkins Agents

Check Jenkins:

sudo systemctl status jenkins --no-pager

Check Docker:

docker --version

The Jenkins user was granted Docker access:

sudo usermod -aG docker jenkins

Verify:

sudo -u jenkins docker ps

The important principle is that the identity executing Jenkins workloads must have the required Docker access.

9. Building the Custom Agent Image

The Dockerfile is maintained in Git:

jenkins/agent/Dockerfile

It uses:

FROM jenkins/inbound-agent:latest-jdk21

The image temporarily becomes root to install packages:

USER root

and returns to the Jenkins user:

USER jenkins

Build

From the repository root:

sudo -u jenkins docker build   -t platform-compliance-agent:1.0   -f jenkins/agent/Dockerfile .

Expected:

Successfully built ...
Successfully tagged platform-compliance-agent:1.0

The resulting image is the reusable CI execution environment.

10. Testing the Agent Image

The image was tested independently before being introduced into Jenkins.

This is an important troubleshooting pattern:

Validate each infrastructure layer independently before adding the next dependency.

Check Terraform:

sudo -u jenkins docker run --rm   --entrypoint terraform   platform-compliance-agent:1.0   version

Check all tools:

sudo -u jenkins docker run --rm   --entrypoint bash   platform-compliance-agent:1.0   -c '
    echo "=== Git ==="
    git --version

    echo "=== Terraform ==="
    terraform version

    echo "=== AWS CLI ==="
    aws --version

    echo "=== TFLint ==="
    tflint --version

    echo "=== Checkov ==="
    checkov --version

    echo "=== OPA ==="
    opa version

    echo "=== Conftest ==="
    conftest --version
  '

Expected toolchain:

Git         2.47.3
Terraform   1.16.0
AWS CLI     2.36.34
TFLint      0.64.0
Checkov     3.3.16
OPA         1.20.1
Conftest    0.69.0

Why --entrypoint matters

The jenkins/inbound-agent base image has a Jenkins agent entrypoint.

Therefore:

docker run platform-compliance-agent:1.0 terraform version

does not directly execute Terraform.

It passes the arguments to the Jenkins agent process.

For testing individual tools, override the entrypoint:

--entrypoint terraform

The inherited Jenkins entrypoint remains desirable when Jenkins launches the container because the container must connect back to the Jenkins controller.

11. Jenkins Docker Integration

The Jenkins controller uses the Docker plugin to communicate with Docker and provision Docker-based agents.

Installed Docker-related plugins include:

docker-plugin
docker-commons
docker-java-api

The intended architecture is:

                  Jenkins Controller
                         │
                         │ Docker Plugin
                         ▼
                  Docker Engine
                         │
                         │ create container
                         ▼
             platform-compliance-agent:1.0
                         │
                         ▼
                   Jenkins Agent

The Jenkins Docker configuration should point to the Docker daemon available to the Jenkins service, typically through the Docker Unix socket:

unix:///var/run/docker.sock

Avoid insecure permissions such as:

chmod 777 /var/run/docker.sock

12. Jenkinsfile

The Jenkinsfile is stored at:

Jenkinsfile

A basic validation pipeline is:

pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Tool Verification') {
            steps {
                sh '''
                    echo "=== Git ==="
                    git --version

                    echo "=== Terraform ==="
                    terraform version

                    echo "=== AWS CLI ==="
                    aws --version

                    echo "=== TFLint ==="
                    tflint --version

                    echo "=== Checkov ==="
                    checkov --version

                    echo "=== OPA ==="
                    opa version

                    echo "=== Conftest ==="
                    conftest --version
                '''
            }
        }

        stage('Terraform Format') {
            steps {
                sh 'terraform fmt -check -recursive'
            }
        }

        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    sh 'terraform init -backend=false'
                    sh 'terraform validate'
                }
            }
        }
    }
}

Once the Docker cloud/agent template is configured, this pipeline should execute inside the custom Docker agent rather than depending on tools installed on the controller.

13. CI/CD Pipeline Flow

                         ┌─────────────────┐
                         │    Developer    │
                         └────────┬────────┘
                                  │
                                  │ Git Push / PR
                                  ▼
                         ┌─────────────────┐
                         │     GitHub      │
                         │   Repository    │
                         └────────┬────────┘
                                  │
                                  ▼
                       ┌─────────────────────┐
                       │   Jenkins           │
                       │   Controller        │
                       └──────────┬──────────┘
                                  │
                                  ▼
                       ┌─────────────────────┐
                       │   Docker Agent      │
                       │   Provisioned       │
                       └──────────┬──────────┘
                                  │
                   ┌──────────────┼──────────────┐
                   │              │              │
                   ▼              ▼              ▼
                Terraform       TFLint        Checkov
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
              Continue Pipeline          Pipeline Stops
                    │
                    ▼
             Terraform Apply
                    │
                    ▼
                   AWS

14. Terraform Compliance Workflow

The Terraform portion manages AWS infrastructure including an S3 bucket.

Security requirements include controls such as:

versioning enabled

server-side encryption

public access blocked

secure bucket configuration

The intended workflow is:

Terraform Code
      │
      ▼
terraform fmt
      │
      ▼
terraform validate
      │
      ▼
TFLint
      │
      ▼
Checkov
      │
      ▼
terraform plan
      │
      ▼
tfplan.json
      │
      ▼
OPA / Conftest
      │
      ▼
Compliance Gate

This creates multiple layers of defense.

15. TFLint

TFLint focuses on Terraform-specific linting.

It can identify:

invalid Terraform usage

suspicious configurations

provider-specific issues

style problems

potential configuration mistakes

Run:

tflint

Check version:

tflint --version

TFLint is a linting/quality control, not a replacement for security scanning or policy enforcement.

16. Checkov

Checkov performs static analysis against Infrastructure as Code.

Example:

checkov -d terraform/

It can identify insecure configurations such as:

publicly accessible resources

missing encryption

weak IAM configuration

missing security controls

other known IaC security issues

Checkov Python Isolation

The Jenkins inbound-agent image is Debian-based.

A direct system-level:

pip3 install --break-system-packages checkov

initially failed because pip encountered a Debian-managed Python package:

error: uninstall-no-record-file

Checkov was therefore isolated in:

/opt/checkov-venv

Conceptually:

System Python
     │
     └── remains untouched

/opt/checkov-venv
     │
     ├── Checkov
     └── Checkov dependencies

A symlink makes the command available as:

/usr/local/bin/checkov
        │
        ▼
/opt/checkov-venv/bin/checkov

The pipeline can therefore execute:

checkov --version

without managing the virtual environment itself.

17. OPA and Conftest

Open Policy Agent

OPA is a general-purpose policy engine.

Rego policies encode organizational compliance rules as executable logic.

Conceptually:

Configuration
     │
     ▼
Policy Evaluation
     │
     ├── Compliant
     └── Non-compliant

Conftest

Conftest uses Rego policies to test structured configuration.

The Terraform policy workflow can be represented as:

Terraform
    │
    ▼
Terraform Plan
    │
    ▼
JSON representation
    │
    ▼
Conftest / OPA
    │
    ▼
Policy Decision

This is Policy as Code.

Instead of relying exclusively on manual review, the compliance rule becomes executable and repeatable.

18. AWS Authentication

AWS credentials should never be baked into:

Dockerfiles

Git repositories

Jenkinsfiles

container images

Do not commit:

AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN

The preferred model is temporary credentials:

Jenkins
   │
   ▼
IAM Role / Temporary Credentials
   │
   ▼
Jenkins Agent
   │
   ▼
Terraform / AWS CLI
   │
   ▼
AWS APIs

For AWS-hosted Jenkins, an EC2 instance profile can provide temporary credentials to the host.

For a more isolated architecture, Jenkins can assume a dedicated deployment role using temporary STS credentials.

The production design should follow least privilege and separation of duties.

19. Security Model

Least Privilege

The Jenkins identity should receive only the AWS permissions necessary for:

reading required infrastructure

managing required resources

accessing Terraform state

performing approved deployment operations

Avoid unrestricted administrator permissions unless specifically justified.

No Credentials in Git

Never commit AWS credentials or other secrets.

No Credentials in the Agent Image

The image contains tools, not credentials:

Agent Image
│
├── Terraform
├── AWS CLI
├── Checkov
├── OPA
└── Conftest

NO:
├── AWS credentials
└── secrets

Non-root Agent

Packages are installed as root during image build, but normal agent execution returns to:

USER jenkins

Docker Socket

The Jenkins user requires Docker access in this architecture.

The Docker socket is a highly privileged interface. Production environments should carefully evaluate this trust boundary and consider stronger isolation.

20. Challenges Encountered and Resolutions

This project documents real troubleshooting rather than only the final happy path.

Challenge 1 — Jenkins agent base image was Debian, not Ubuntu

The initial Dockerfile assumed:

FROM ubuntu:24.04

The design was changed to:

FROM jenkins/inbound-agent:latest-jdk21

The new base image is Debian-based.

The build then failed:

E: Unable to locate package software-properties-common

Resolution

The unnecessary Ubuntu-specific package was removed.

Lesson

Always inspect the operating system and package ecosystem of a base image before writing package installation commands.

Challenge 2 — Checkov installation conflicted with Debian Python packages

The initial installation:

pip3 install --break-system-packages checkov

failed with:

error: uninstall-no-record-file

A Debian-managed Python package was being encountered when pip attempted to replace it.

Resolution

Checkov was isolated in:

/opt/checkov-venv

Lesson

Isolate application dependencies from operating-system-managed Python packages.

Challenge 3 — Tool testing appeared to fail because of the Jenkins entrypoint

Running:

docker run --rm platform-compliance-agent:1.0 terraform version

produced Jenkins Remoting errors.

Checkov similarly returned Jenkins agent help.

Root Cause

The base image's entrypoint launches the Jenkins agent.

Resolution

Override the entrypoint for standalone tool tests:

docker run --rm   --entrypoint terraform   platform-compliance-agent:1.0   version

Lesson

Understand inherited Docker ENTRYPOINT and CMD behavior when extending vendor images.

Challenge 4 — The normal Ubuntu login user could not access Docker

Running:

docker ps

as ubuntu returned a Docker socket permission error.

However:

sudo -u jenkins docker ps

worked.

Root Cause

The Jenkins user had already been added to the Docker group:

sudo usermod -aG docker jenkins

Resolution

No insecure Docker socket permissions were required.

Lesson

Test permissions using the identity that actually executes the workload.

Challenge 5 — Jenkins initially had no Docker integration

The Jenkins installation did not initially contain the Docker plugin.

Resolution

The Docker plugin and its supporting dependencies were installed:

docker-plugin
docker-commons
docker-java-api

Lesson

Jenkins controller/agent orchestration requires the appropriate cloud/agent integration.

Challenge 6 — Terraform S3 state access failed

The Terraform workflow initially failed with S3 access errors such as:

not authorized to perform:
s3:CreateBucket

Later backend initialization failed with:

Unable to access object
platform-compliance/terraform.tfstate
...
S3: HeadObject
403 Forbidden

Resolution

The appropriate S3 permissions were added to the CI identity for the Terraform state bucket and object.

Lesson

Terraform requires permissions for both infrastructure operations and remote state operations.

Challenge 7 — Remote Terraform state existed but local state was absent

The remote state object existed in S3:

platform-compliance/terraform.tfstate

The state was inspected with:

terraform state pull

and the S3 object was confirmed with:

aws s3api list-objects-v2   --bucket priest-platform-compliance-tfstate-417521971848   --prefix platform-compliance/

Resolution

The existing S3 bucket was imported:

terraform import aws_s3_bucket.compliance_demo   priest-platform-compliance-demo-417521971848

Lesson

Terraform state is the mapping between configuration and real infrastructure. Existing infrastructure must be imported rather than recreated.

Challenge 8 — Terraform refresh required additional S3 read permissions

After importing the bucket, Terraform plan exposed additional missing permissions during refresh, including:

s3:GetBucketPolicy
s3:GetBucketCORS
s3:GetBucketWebsite
s3:GetAccelerateConfiguration
s3:GetBucketRequestPayment

Additional permissions required during the troubleshooting included:

s3:GetBucketLogging
s3:GetLifecycleConfiguration
s3:GetReplicationConfiguration
s3:GetObjectLockConfiguration

Resolution

The CI identity was given the required bucket-scoped read permissions.

Lesson

terraform plan refreshes real infrastructure. The permission set needed to create a resource is not necessarily sufficient to read the complete resource configuration during refresh.

Challenge 9 — S3 bucket already existed

Terraform attempted:

aws_s3_bucket.compliance_demo: Creating...

AWS returned:

BucketAlreadyExists

Resolution

The existing bucket was imported into Terraform state.

Lesson

Terraform should manage existing resources through state rather than attempting to recreate them.

21. Troubleshooting

Jenkins

sudo systemctl status jenkins --no-pager
sudo systemctl restart jenkins
sudo journalctl -u jenkins -f

Docker

docker --version
sudo -u jenkins docker ps
sudo -u jenkins docker images
ls -l /var/run/docker.sock
groups jenkins

Agent Image

sudo -u jenkins docker images | grep platform-compliance-agent

Run a shell:

sudo -u jenkins docker run --rm   --entrypoint bash   platform-compliance-agent:1.0

Git Version

git status
git branch --show-current
git branch -r
git log -1 --oneline
git remote -v

Rebuild Agent

sudo -u jenkins docker build   -t platform-compliance-agent:1.0   -f jenkins/agent/Dockerfile .

22. Commands Reference

Git

git status
git branch
git branch -r
git branch -a
git remote -v
git log -1 --oneline
git pull origin jenkins/platform-compliance
git push origin jenkins/platform-compliance

Docker

docker --version
docker ps
docker images
sudo -u jenkins docker ps
sudo -u jenkins docker images

Build:

sudo -u jenkins docker build   -t platform-compliance-agent:1.0   -f jenkins/agent/Dockerfile .

Jenkins

sudo systemctl status jenkins
sudo systemctl restart jenkins
sudo journalctl -u jenkins -f

Terraform

terraform fmt -check -recursive
terraform init
terraform init -backend=false
terraform validate
terraform plan
terraform apply
terraform state list
terraform state pull
terraform import <resource> <id>

AWS

aws sts get-caller-identity
aws s3api head-bucket --bucket <bucket-name>
aws s3api get-bucket-versioning --bucket <bucket-name>
aws s3api get-bucket-encryption --bucket <bucket-name>
aws s3api get-public-access-block --bucket <bucket-name>

Policy Tools

tflint --version
checkov --version
opa version
conftest --version

23. Production Improvements

The current implementation is a learning/demo environment. A production implementation could improve it in several ways.

1. Store the agent image in Amazon ECR

Instead of keeping the image only on the Jenkins EC2:

                  ECR
                   │
                   │ pull
                   ▼
             Jenkins Agent

This provides centralized image management and versioning.

2. Pin Tool Versions

Avoid relying on:

FROM jenkins/inbound-agent:latest-jdk21

for production.

Use tested, controlled versions for:

Jenkins agent

Terraform

TFLint

Checkov

OPA

Conftest

AWS CLI

3. Build the Agent Image Through CI

A mature architecture can be:

Dockerfile
    │
    ▼
CI Pipeline
    │
    ├── Build
    ├── Scan
    ├── Test
    └── Push
          │
          ▼
         ECR

Application pipelines then consume the tested image.

4. Use Ephemeral Agents

Build starts
     │
     ▼
Agent created
     │
     ▼
Pipeline executes
     │
     ▼
Build finishes
     │
     ▼
Agent destroyed

This prevents state from leaking between builds.

5. Separate CI and Deployment Roles

Jenkins CI Role
      │
      └── Validation / read permissions


Jenkins Deployment Role
      │
      └── Controlled Terraform apply permissions

6. Add Approval Before Production Apply

Terraform Plan
      │
      ▼
Security Scan
      │
      ▼
Policy Gate
      │
      ▼
Manual Approval
      │
      ▼
Terraform Apply

7. Store Compliance Artifacts

Retain:

Terraform plans

Checkov reports

policy results

test results

build logs

This improves auditability.

8. Add Notifications

Production pipelines can notify teams through approved collaboration and incident-management systems.

24. Senior DevOps Interview Talking Points

Why use Jenkins agents?

I separate orchestration from workload execution. The Jenkins controller manages jobs and scheduling, while agents execute builds. I use a custom Docker agent so every build receives a consistent and reproducible toolchain without manually installing Terraform, TFLint, Checkov, OPA, and Conftest on the Jenkins controller.

Why package the tools in a Docker image?

It eliminates tool-version drift and reduces configuration differences between builds. The image becomes an immutable build environment that can be versioned, tested, promoted, and eventually stored in ECR.

Why shouldn't all tools be installed on the controller?

The controller should primarily orchestrate builds. Installing every dependency directly on it creates coupling, version drift, and maintenance overhead. Agents provide isolated execution environments.

Why use Checkov and OPA/Conftest?

They provide different layers of control. Checkov performs security-oriented static analysis, while OPA and Conftest allow the organization to encode custom compliance requirements as Policy as Code.

What is Policy as Code?

Policy as Code expresses security and governance rules in executable policy files so they can be evaluated automatically and consistently during CI/CD instead of relying on manual reviews.

Why use Terraform plan before apply?

The plan provides a preview of infrastructure changes. It can also be converted into machine-readable JSON so security and compliance tooling can evaluate what Terraform intends to change before deployment.

Why does Terraform need S3 permissions during plan?

Terraform refreshes its state against real infrastructure during planning. Therefore the CI identity needs sufficient read permissions to inspect resources represented in the state, in addition to permissions required for creating or modifying resources.

Why import the S3 bucket?

The bucket already existed outside the current Terraform state. Importing associated the existing AWS resource with the Terraform resource address, preventing Terraform from attempting to create a duplicate resource.

What is the security concern with the Docker socket?

Access to the Docker daemon is highly privileged. A Jenkins process with Docker socket access can effectively control containers and potentially the host. Therefore this access must be treated as privileged and isolated carefully in production.

25. Final Architecture

                              DEVELOPER
                                  │
                                  │
                              Git Push
                                  │
                                  ▼
                         ┌─────────────────┐
                         │     GitHub      │
                         │   Repository    │
                         └────────┬────────┘
                                  │
                                  │ Webhook / SCM
                                  ▼
                  ┌─────────────────────────────┐
                  │      Jenkins Controller     │
                  │          AWS EC2            │
                  │                             │
                  │  Pipeline orchestration     │
                  │  Job scheduling             │
                  │  Credentials management     │
                  └──────────────┬──────────────┘
                                 │
                                 │ Docker Plugin
                                 ▼
                  ┌─────────────────────────────┐
                  │       Docker Engine         │
                  │          AWS EC2             │
                  └──────────────┬──────────────┘
                                 │
                                 │ Provision
                                 ▼
              ┌─────────────────────────────────────────┐
              │         Jenkins Agent Container         │
              │       platform-compliance-agent:1.0    │
              │                                         │
              │  Git                                     │
              │  Terraform                               │
              │  AWS CLI                                 │
              │  TFLint                                  │
              │  Checkov                                 │
              │  OPA                                     │
              │  Conftest                                │
              └───────────────────┬─────────────────────┘
                                  │
                                  ▼
                     ┌─────────────────────────┐
                     │    Quality & Security   │
                     │         Gates           │
                     ├─────────────────────────┤
                     │ Terraform fmt            │
                     │ Terraform validate       │
                     │ TFLint                   │
                     │ Checkov                  │
                     │ OPA / Conftest           │
                     └────────────┬────────────┘
                                  │
                                  ▼
                        ┌──────────────────┐
                        │ COMPLIANCE GATE  │
                        └────────┬─────────┘
                                 │
                     ┌───────────┴───────────┐
                     │                       │
                    PASS                    FAIL
                     │                       │
                     ▼                       ▼
              Terraform Plan           Pipeline Stops
                     │
                     ▼
               tfplan.json
                     │
                     ▼
               Policy Evaluation
                     │
                     ▼
              Approved Changes
                     │
                     ▼
              Terraform Apply
                     │
                     ▼
                    AWS

🎯 Key Takeaways

This project demonstrates that a mature Jenkins pipeline is more than:

terraform apply

Instead, the deployment path becomes:

CODE
  │
  ▼
CHECKOUT
  │
  ▼
FORMAT
  │
  ▼
VALIDATE
  │
  ▼
LINT
  │
  ▼
SECURITY SCAN
  │
  ▼
TERRAFORM PLAN
  │
  ▼
POLICY AS CODE
  │
  ▼
COMPLIANCE GATE
  │
  ├──────── FAIL ────────► STOP
  │
  ▼
APPROVAL
  │
  ▼
TERRAFORM APPLY
  │
  ▼
AWS

The Jenkins controller orchestrates. Docker agents execute. Policy as Code governs. Terraform provisions. AWS provides the infrastructure.
