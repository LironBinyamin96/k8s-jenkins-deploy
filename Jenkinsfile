pipeline {
    agent any

    environment {
        AWS_REGION         = 'il-central-1'
        ECR_REPO           = 'liron/helm/nginx'
        IMAGE_NAME         = 'nginx'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Set Version') {
            steps {
                script {
                    def versionFile = 'VERSION'
                    def version = '0.1'
                    if (fileExists(versionFile)) {
                        version = readFile(versionFile).trim()
                        def (major, minor) = version.tokenize('.')
                        minor = minor.toInteger() + 1
                        if (minor > 9) {
                            major = major.toInteger() + 1
                            minor = 0
                        }
                        version = "${major}.${minor}"
                    }
                    writeFile file: versionFile, text: version
                    env.IMAGE_TAG = version
                    echo "🔖 New image tag: ${env.IMAGE_TAG}"
                }
            }
        }

         stage('Build Docker Image') {
            steps {
                script {
                    def dockerImage = docker.build("${IMAGE_NAME}:${env.IMAGE_TAG}")
                }
            }
        }

        stage('Authenticate to AWS ECR') {
            steps {
                script {
                    sh '''
                    # משתמש ב-EC2 Instance Role לצורך החיבור, אין צורך במפתחות גישה
                    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                    ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    aws ecr get-login-password --region $AWS_REGION | helm registry login --username AWS --password-stdin $ECR_REGISTRY
                    '''
                }
            }
        }

        stage('Push to ECR') {
            steps {
                script {
                    def accountId = sh(
                        script: "aws sts get-caller-identity --query Account --output text",
                        returnStdout: true
                    ).trim()
                    def ecrUri = "${accountId}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

                    sh """
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ecrUri}:${IMAGE_TAG}
                        docker push ${ecrUri}:${IMAGE_TAG}
                    """
                    env.ECR_IMAGE_URI = "${ecrUri}:${IMAGE_TAG}"
                    echo "📦 Pushed ${IMAGE_NAME}:${IMAGE_TAG} → ${env.ECR_IMAGE_URI}"
                }
            }
        }

        stage('Configure Kubeconfig') {
            steps {
                withEnv(["KUBECONFIG=/tmp/eks.conf"]) {
                    echo "✅ KUBECONFIG set to $KUBECONFIG"
                }
            }
        }

        stage('Create Namespace') {
            steps {
                withEnv(["KUBECONFIG=/tmp/eks.conf"]) {
                    sh '''
                        kubectl get namespace nginx-deployment || \
                          kubectl create namespace  nginx-deployment
                    '''
                    echo "📂 Namespace ' nginx-deployment' ensured"
                }
            }
        }

        stage('Update Helm Chart') {
            steps {
                script {
                    // extract registry+repo (strip off ":tag")
                    def registryRepo = env.ECR_IMAGE_URI.split(':')[0]

                    // update values.yaml under nginx-deployment folder
                    sh """
                      sed -i 's|^\\s*repository:.*|  repository: ${registryRepo}|' nginx-deployment/values.yaml
                      sed -i 's|^\\s*tag:.*|  tag:        ${env.IMAGE_TAG}|'    nginx-deployment/values.yaml
                    """
                    echo "🔄 nginx-deployment/values.yaml updated → ${registryRepo}:${env.IMAGE_TAG}"
                }
            }
        }

        stage('Deploy with Helm') {
            steps {
                withEnv(["KUBECONFIG=/tmp/eks.conf"]) {
                    sh '''
                      helm upgrade --install nginx-deployment ./nginx \
                        --namespace  nginx-deployment
                    '''
                    echo "🚀 Helm release 'nginx-deployment' deployed/upgraded in ' nginx-deployment'"
                }
            }
        }
    }
}
