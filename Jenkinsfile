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
