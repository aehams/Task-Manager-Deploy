pipeline {
    agent any

    parameters {
        string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'Git branch to checkout')
        string(name: 'AWS_REGION', defaultValue: 'eu-north-1', description: 'AWS Region for ECR')
        string(name: 'ECR_REGISTRY', defaultValue: '381304436206.dkr.ecr.eu-north-1.amazonaws.com', description: 'AWS ECR Registry URL')
    }

    environment {
        // AWS ECR Configuration
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        AWS_REGION = "${params.AWS_REGION}"
        ECR_REGISTRY = "${params.ECR_REGISTRY}"
        
        // Repository names
        BACKEND_REPO = 'backend'
        FRONTEND_REPO = 'frontend'
        
        // Image tags
        BUILD_TAG = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
        
        // Kubernetes
        K8S_NAMESPACE = 'task-manager'
        KUBE_CONFIG = credentials('kubeconfig-esk')
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔄 Checking out code from GitHub..."
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: "${params.GIT_BRANCH}"]],
                        userRemoteConfigs: [[
                            url: 'https://github.com/aehams/Task-Manager-Deploy.git',
                            credentialsId: 'github-credentials'
                        ]]
                    ])
                }
            }
        }

        stage('Build Frontend Docker Image') {
            steps {
                script {
                    echo "🔨 Building Frontend Docker image..."
                    sh '''
                        cd frontend
                        docker build \
                            -t ${FRONTEND_REPO}:${BUILD_TAG} \
                            -t ${FRONTEND_REPO}:latest \
                            .
                        docker images | grep ${FRONTEND_REPO}
                    '''
                }
            }
        }

        stage('Build Backend Docker Image') {
            steps {
                script {
                    echo "🔨 Building Backend Docker image..."
                    sh '''
                        cd backend
                        docker build \
                            -t ${BACKEND_REPO}:${BUILD_TAG} \
                            -t ${BACKEND_REPO}:latest \
                            .
                        docker images | grep ${BACKEND_REPO}
                    '''
                }
            }
        }

        stage('Login to AWS ECR') {
            steps {
                script {
                    echo "🔐 Logging in to AWS ECR..."
                    sh '''
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    '''
                }
            }
        }

        stage('Tag Images for ECR') {
            steps {
                script {
                    echo "🏷️  Tagging images for ECR..."
                    sh '''
                        # Tag Frontend
                        docker tag ${FRONTEND_REPO}:${BUILD_TAG} \
                            ${ECR_REGISTRY}/${FRONTEND_REPO}:${BUILD_TAG}
                        docker tag ${FRONTEND_REPO}:${BUILD_TAG} \
                            ${ECR_REGISTRY}/${FRONTEND_REPO}:latest
                        
                        # Tag Backend
                        docker tag ${BACKEND_REPO}:${BUILD_TAG} \
                            ${ECR_REGISTRY}/${BACKEND_REPO}:${BUILD_TAG}
                        docker tag ${BACKEND_REPO}:${BUILD_TAG} \
                            ${ECR_REGISTRY}/${BACKEND_REPO}:latest
                    '''
                }
            }
        }

        stage('Push to ECR') {
            steps {
                script {
                    echo "📤 Pushing images to ECR..."
                    sh '''
                        # Push Frontend
                        docker push ${ECR_REGISTRY}/${FRONTEND_REPO}:${BUILD_TAG}
                        docker push ${ECR_REGISTRY}/${FRONTEND_REPO}:latest
                        
                        # Push Backend
                        docker push ${ECR_REGISTRY}/${BACKEND_REPO}:${BUILD_TAG}
                        docker push ${ECR_REGISTRY}/${BACKEND_REPO}:latest
                        
                        echo "✅ Images pushed successfully"
                        echo "Frontend: ${ECR_REGISTRY}/${FRONTEND_REPO}:${BUILD_TAG}"
                        echo "Backend: ${ECR_REGISTRY}/${BACKEND_REPO}:${BUILD_TAG}"
                    '''
                }
            }
        }

        stage('Update Kubernetes Manifests') {
            steps {
                script {
                    echo "📝 Updating Kubernetes manifests with new image tags..."
                    sh '''
                        # Update Backend deployment
                        sed -i "" "s|backend:latest|${ECR_REGISTRY}/${BACKEND_REPO}:${BUILD_TAG}|g" k8s/backend-deployment.yaml
                        
                        # Update Frontend deployment
                        sed -i "" "s|frontend:latest|${ECR_REGISTRY}/${FRONTEND_REPO}:${BUILD_TAG}|g" k8s/frontend-deployment.yaml
                        
                        # Verify changes
                        echo "Updated Backend:"
                        grep "image:" k8s/backend-deployment.yaml | head -1
                        echo "Updated Frontend:"
                        grep "image:" k8s/frontend-deployment.yaml | head -1
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    echo "🚀 Deploying to Kubernetes..."
                    sh '''
                        # Setup kubeconfig
                        export KUBECONFIG=${KUBE_CONFIG}
                        
                        # Check cluster connection
                        kubectl cluster-info
                        
                        # Create namespace if not exists
                        kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Apply all manifests in order
                        echo "📦 Applying Namespace..."
                        kubectl apply -f k8s/namespace.yaml
                        
                        echo "🔐 Applying Secrets..."
                        kubectl apply -f k8s/secret.yaml
                        
                        echo "⚙️  Applying ConfigMaps..."
                        kubectl apply -f k8s/configmap.yaml
                        
                        echo "💾 Applying PostgreSQL Storage..."
                        kubectl apply -f k8s/postgres-pv.yaml
                        
                        echo "🗄️  Applying PostgreSQL Deployment..."
                        kubectl apply -f k8s/postgres-deployment.yaml
                        kubectl apply -f k8s/postgres-service.yaml
                        
                        echo "🖥️  Applying Backend Deployment..."
                        kubectl apply -f k8s/backend-deployment.yaml
                        kubectl apply -f k8s/backend-service.yaml
                        
                        echo "🎨 Applying Frontend Deployment..."
                        kubectl apply -f k8s/frontend-deployment.yaml
                        kubectl apply -f k8s/frontend-service.yaml
                        
                        echo "🌐 Applying Ingress..."
                        kubectl apply -f k8s/ingress.yaml
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    echo "✅ Verifying deployment status..."
                    sh '''
                        export KUBECONFIG=${KUBE_CONFIG}
                        
                        echo "📊 Checking Pods status..."
                        kubectl get pods -n ${K8S_NAMESPACE}
                        
                        echo "🔄 Checking Deployments..."
                        kubectl get deployments -n ${K8S_NAMESPACE}
                        
                        echo "⚙️  Checking Services..."
                        kubectl get services -n ${K8S_NAMESPACE}
                    '''
                }
            }
        }

        stage('Rollout Status') {
            steps {
                script {
                    echo "⏳ Waiting for rollout to complete..."
                    sh '''
                        export KUBECONFIG=${KUBE_CONFIG}
                        
                        # Wait for PostgreSQL
                        echo "Waiting for PostgreSQL..."
                        kubectl rollout status deployment/postgres \
                            -n ${K8S_NAMESPACE} \
                            --timeout=5m
                        
                        # Wait for Backend
                        echo "Waiting for Backend..."
                        kubectl rollout status deployment/backend \
                            -n ${K8S_NAMESPACE} \
                            --timeout=10m
                        
                        # Wait for Frontend
                        echo "Waiting for Frontend..."
                        kubectl rollout status deployment/frontend \
                            -n ${K8S_NAMESPACE} \
                            --timeout=5m
                        
                        echo "✅ All deployments rolled out successfully!"
                    '''
                }
            }
        }

        stage('Post-Deploy Health Check') {
            steps {
                script {
                    echo "🏥 Running health checks..."
                    sh '''
                        export KUBECONFIG=${KUBE_CONFIG}
                        
                        # Check pod logs
                        echo "📋 Backend Logs (last 50 lines):"
                        kubectl logs -n ${K8S_NAMESPACE} \
                            -l app=backend \
                            --tail=50 \
                            --all-containers=true || true
                        
                        echo "📋 Frontend Logs (last 50 lines):"
                        kubectl logs -n ${K8S_NAMESPACE} \
                            -l app=frontend \
                            --tail=50 \
                            --all-containers=true || true
                        
                        echo "📋 PostgreSQL Logs (last 50 lines):"
                        kubectl logs -n ${K8S_NAMESPACE} \
                            -l app=postgres \
                            --tail=50 || true
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                echo "🧹 Cleaning up..."
                sh '''
                    # Remove local images (optional)
                    # docker rmi ${FRONTEND_REPO}:${BUILD_TAG} || true
                    # docker rmi ${BACKEND_REPO}:${BUILD_TAG} || true
                    
                    # Logout from ECR
                    docker logout ${ECR_REGISTRY} || true
                '''
            }
        }
        
        success {
            script {
                echo "✅ Pipeline completed successfully!"
                sh '''
                    export KUBECONFIG=${KUBE_CONFIG}
                    echo "🎉 Deployment successful!"
                    echo "Application is running at: http://task-manager.local"
                    echo "Build Tag: ${BUILD_TAG}"
                    kubectl get all -n ${K8S_NAMESPACE}
                '''
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed!"
                sh '''
                    export KUBECONFIG=${KUBE_CONFIG}
                    echo "Failed Build: ${BUILD_TAG}"
                    echo "Recent pod events:"
                    kubectl describe pod -n ${K8S_NAMESPACE} | tail -50 || true
                '''
            }
        }
        
        unstable {
            echo "⚠️  Pipeline is unstable - check logs"
        }
    }
}
