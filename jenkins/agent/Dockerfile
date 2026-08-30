FROM jenkins/inbound-agent:latest-jdk21

USER root

ENV DEBIAN_FRONTEND=noninteractive

# Base dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    tar \
    git \
    python3 \
    python3-pip \
    gnupg \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# Terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor \
    | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com \
$(. /etc/os-release && echo $VERSION_CODENAME) main" \
    | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get install -y terraform \
    && rm -rf /var/lib/apt/lists/*

# TFLint
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh \
    | bash

# Checkov
RUN pip3 install --break-system-packages checkov

# OPA
RUN curl -L \
    -o /usr/local/bin/opa \
    https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static \
    && chmod +x /usr/local/bin/opa

# Conftest
ARG CONFTEST_VERSION=0.69.0

RUN wget -q \
    "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
    -O /tmp/conftest.tar.gz \
    && tar -xzf /tmp/conftest.tar.gz -C /tmp \
    && mv /tmp/conftest /usr/local/bin/conftest \
    && rm -f /tmp/conftest.tar.gz

# Verify the toolchain
RUN git --version \
    && java -version \
    && terraform version \
    && aws --version \
    && tflint --version \
    && checkov --version \
    && opa version \
    && conftest --version

# Return to the Jenkins agent user
USER jenkins
