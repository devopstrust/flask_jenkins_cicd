pipeline {
    agent any
    parameters {
        string(name: 'GITHUB_REPO', defaultValue: 'https://github.com/devopstrust/flask_jenkins_cicd.git', description: 'GitHub repository URL')
        string(name: 'BRANCH', defaultValue: 'main', description: 'Branch to build')
    }
    stages {
        stage('Debug Parameters') {
            steps {
                script {
                    echo "Using GITHUB_REPO: ${params.GITHUB_REPO}"
                    echo "Using BRANCH: ${params.BRANCH}"
                }
            }
        }
        stage('Checkout') {
            steps {
                git branch: "${params.BRANCH}", url: "${params.GITHUB_REPO}"
            }
        }
        stage('Trivy Scan') {
            steps {
                script {
                    echo "Running Trivy scans..."
                    def vulnStatus = sh(script: '''
                        ls -la app/
                        echo "Checking requirements.txt contents..."
                        cat app/requirements.txt
                        echo "Checking trivy-secret.yaml..."
                        cat secret-config/trivy-secret.yaml
                        docker run --rm -v $(pwd):/src aquasec/trivy:latest fs \
                        --secret-config /src/secret-config/trivy-secret.yaml \
                        --scanners vuln \
                        --no-progress \
                        --format table \
                        --debug \
                        --exit-code 1 \
                        /src/app/requirements.txt > trivy-vuln-report.txt 2>&1 || true
                        cat trivy-vuln-report.txt
                        grep -q "Total: [1-9]" trivy-vuln-report.txt && exit 1 || exit 0
                    ''', returnStatus: true)

                    def secretStatus = sh(script: '''
                        echo "Checking server.py contents..."
                        cat app/server.py
                        docker run --rm -v $(pwd):/src aquasec/trivy:latest fs \
                        --secret-config /src/secret-config/trivy-secret.yaml \
                        --scanners secret \
                        --no-progress \
                        --format table \
                        --debug \
                        --exit-code 1 \
                        /src/app/server.py > trivy-secret-report.txt 2>&1 || true
                        cat trivy-secret-report.txt
                        grep -q "Total: [1-9]" trivy-secret-report.txt && exit 1 || exit 0
                    ''', returnStatus: true)

                    // Архівація звітів
                    archiveArtifacts artifacts: 'trivy-vuln-report.txt,trivy-secret-report.txt', allowEmptyArchive: true

                    // Зупинка Pipeline, якщо знайдено проблеми
                    //if (vulnStatus != 0) {
                    //    error "Pipeline aborted due to vulnerabilities found in requirements.txt"
                    //}
                    //if (secretStatus != 0) {
                    //    error "Pipeline aborted due to secrets detected in server.py"
                    //}
                }
            }
        }
        stage('Stop Old Containers') {
            steps {
                script {
                    def running = sh(script: 'docker-compose ps -q', returnStdout: true).trim()
                    if (running) {
                        echo "Stopping old containers..."
                        sh 'docker-compose down'
                    } else {
                        echo "No old containers running."
                    }
                }
            }
        }
        stage('Build App and Deploy with Docker Compose') {
            steps {
                sh 'docker-compose up -d --build'
                sh 'sleep 5'
            }
        }
        stage('Scan Docker Image') {
    steps {
        script {
            echo "Scanning Docker image..."
            def imageStatus = sh(script: '''
                echo "Checking Docker daemon..."
                if ! docker info >/dev/null 2>&1; then
                    echo "ERROR: Cannot connect to Docker daemon!"
                    exit 1
                fi
                echo "Checking running containers..."
                docker ps -a
                echo "Checking available images..."
                docker images
                # Перевіряємо наявність trivy-secret.yaml (для діагностики)
                echo "Checking for trivy-secret.yaml..."
                ls -la secret-config/ || echo "secret-config/ directory not found"
                # Спробуємо знайти образ
                IMAGE_NAME=$(docker images -q ${JOB_NAME}_app | head -1)
                if [ -z "$IMAGE_NAME" ]; then
                    echo "ERROR: Docker image ${JOB_NAME}_app not found!"
                    docker images | grep app || true
                    exit 1
                fi
                docker run --rm -v $(pwd):/src -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image \
                --no-progress \
                --format table \
                --exit-code 1 \
                --severity HIGH,CRITICAL \
                ${JOB_NAME}_app > trivy-image-report.txt 2>&1 || true
                cat trivy-image-report.txt
                grep -q "Total: [1-9]" trivy-image-report.txt && exit 1 || exit 0
            ''', returnStatus: true)

            archiveArtifacts artifacts: 'trivy-image-report.txt', allowEmptyArchive: true

            //if (imageStatus != 0) {
            //    error "Pipeline aborted due to issues with Docker image ${JOB_NAME}_app"
            //}
        }
    }
}
        stage('Test Application') {
            steps {
                script {
                    def appContainer = sh(script: 'docker-compose ps -q app', returnStdout: true).trim()
                    if (!appContainer) {
                        error "App container is not running!"
                    }
                    sh "docker exec ${appContainer} pytest /app/tests/test_api.py -v"
                }
            }
        }
        stage('Restart App Container') {
            steps {
                sh 'docker-compose restart app'
            }
        }
        stage('Backup Images') {
            steps {
                sh 'docker save -o flask-app-backup.tar ${JOB_NAME}_app'
                archiveArtifacts artifacts: 'flask-app-backup.tar', allowEmptyArchive: true
            }
        }
    }
    post {
        always {
            sh 'docker-compose logs'
        }
        success {
            echo 'Pipeline completed successfully! Containers are running.'
        }
        failure {
            echo 'Pipeline failed. Check logs for details. Containers may still be running.'
        }
    }
}