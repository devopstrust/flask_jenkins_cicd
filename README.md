```markdown
# CI/CD Pipeline for Python Flask Application with Monitoring

A robust CI/CD pipeline for a Python Flask application, leveraging Jenkins, Docker, and Trivy for security, with Prometheus, Grafana, and cAdvisor for monitoring.

---

## Overview

This project provides a comprehensive CI/CD pipeline for a Python Flask application, orchestrated with **Jenkins** and deployed using **Docker Compose**. It integrates **Trivy** for security scanning to detect vulnerabilities and secrets, ensuring a secure deployment. The pipeline is complemented by a monitoring stack featuring **Prometheus**, **Grafana**, and **cAdvisor** for real-time performance observability.

---

## System Requirements

- **Jenkins** with plugins:
  - Docker Pipeline
  - Git
  - Pipeline
- **Docker** and **Docker Compose**
- **Python** 3.12 or higher
- **Prometheus**, **Grafana**, and **cAdvisor**
- **Trivy** (via Docker image `aquasec/trivy:latest`)

---

## Repository Structure

The repository is organized as follows:

- **`app/`**: Source code for the Flask application
  - `requirements.txt`: Python dependencies
  - `server.py`: Main application code
  - `tests/`: Unit tests
- **`scripts/`**: Automation scripts (e.g., backup, restart) used in the pipeline
- **`.dockerignore`**: Exclusions for Docker builds
- **`Dockerfile`**: Multi-stage Docker configuration (optimized image size: ~70MB vs. ~1GB)
- **`docker-compose.yml`**: Local deployment configuration with monitoring
- **`Jenkinsfile`**: CI/CD pipeline definition with parameterized stages
- **`prometheus.yml`**: Prometheus configuration
- **`alerts.yml`**: Alerting rules for Prometheus
- **`.trivyignore`**: file is a plain text file read by Trivy to exclude specific vulnerabilities (by CVE ID) or secret patterns from scan results.
- **`secret-config/trivy-secret.yaml`**: Trivy configuration for detecting secrets (e.g., AWS keys)

---

## CI/CD Pipeline Setup

### 1. Install Jenkins

Set up Jenkins on a local machine or virtual machine.

#### Prerequisites

- Verify Java installation:
  ```bash
  java -version
  ```

If Java is not installed:
```bash
sudo apt update
sudo apt install openjdk-17-jdk -y
java -version
```

**Installation Steps**

Add the Jenkins repository key:
```bash
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
```

Add the Jenkins repository:
```bash
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
/etc/apt/sources.list.d/jenkins.list > /dev/null
```

Install Jenkins:
```bash
sudo apt update
sudo apt install jenkins -y
```

Verify Jenkins status:
```bash
sudo systemctl status jenkins
```

Ensure the service is active (running).  
> **Note:** cAdvisor in this project uses port `8085` to avoid conflicts.

**Configuration**

Install Jenkins plugins: Docker Pipeline, Git, Pipeline.

Grant Jenkins access to Docker:
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

Ensure the Docker socket is accessible (this project uses `/var/run/docker.socks`).
---
### 2. Configure the Project

Clone the repository:
```bash
git clone https://github.com/devopstrust/flask_jenkins_cicd.git
```

In Jenkins:

- Create a new **Pipeline** project.
- Point it to the `Jenkinsfile` in the repository.
---
### 3. Run the Pipeline

Trigger the pipeline via the Jenkins UI.

**Pipeline Stages:**

1. **Debug Parameters**: Displays repository and branch parameters.  
2. **Checkout**: Clones the specified Git branch.  
3. **Trivy Scan**:
   - Scans `app/requirements.txt` for vulnerabilities.
   - Scans `app/server.py` for secrets using rules in `secret-config/trivy-secret.yaml`.
4. **Stop Old Containers**: Terminates existing Docker Compose containers.  
5. **Build App and Deploy with Docker Compose**: Builds and deploys the application.  
6. **Scan Docker Image**: Scans the built Docker image for vulnerabilities using Trivy.  
7. **Test Application**: Runs unit tests with `pytest`.  
8. **Restart App Container**: Restarts the application container.  
9. **Backup Images**: Saves the Docker image as a backup artifact.

---

## Security Scanning with Trivy

Trivy is a critical component of the pipeline, ensuring the application and its dependencies are secure.

### File System Scans

**Vulnerabilities in Dependencies:**

- **Target**: `app/requirements.txt`  
- **Command**:
  ```bash
  docker run --rm -v $(pwd):/src aquasec/trivy:latest fs \
    --secret-config /src/secret-config/trivy-secret.yaml \
    --scanners vuln \
    --no-progress \
    --format table \
    --debug \
    /src/app/requirements.txt
  ```

> **Outcome**: The pipeline fails if vulnerabilities are detected.

**Secrets in Code:**

- **Target**: `app/server.py`  
- **Command**:
  ```bash
  docker run --rm -v $(pwd):/src aquasec/trivy:latest fs \
    --secret-config /src/secret-config/trivy-secret.yaml \
    --scanners secret \
    --no-progress \
    --format table \
    --debug \
    /src/app/server.py
  ```

**Configuration (`secret-config/trivy-secret.yaml`):**

```yaml
rules:
  - id: rule1
    category: general
    title: Generic Rule
    severity: HIGH
    regex: (?i)(?P<key>(secret))(=|:).{0,5}['"](?P<secret>[0-9a-zA-Z\-_=]{8,64})['"]
    allow-rules:
      - id: skip-text
        description: skip text files
        path: .*\.txt
enable-builtin-rules:
  - aws-access-key-id
  - aws-account-id
  - aws-secret-access-key
disable-allow-rules:
  - usr-dirs
```

> **Outcome**: The pipeline fails if secrets are detected.

---

## Docker Image Scan

- **Target**: Built Docker image (`${JOB_NAME}_app`)  
- **Purpose**: Detects vulnerabilities in the image’s OS and libraries.  
- **Command**:
  ```bash
  docker run --rm -v $(pwd):/src -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image \
    --scanners vuln \
    --no-progress \
    --format table \
    --exit-code 1 \
    --severity HIGH,CRITICAL \
    ${JOB_NAME}_app
  ```

> **Focus**: HIGH and CRITICAL severity vulnerabilities.  
> **Outcome**: The pipeline halts if vulnerabilities are found, ensuring only secure images are deployed.

---

## Monitoring Setup

### 1. Launch the Stack

Deploy the application and monitoring services:
```bash
docker-compose up -d
```

This starts:

- Flask application  
- Prometheus  
- Grafana  
- cAdvisor

### 2. Configure Grafana

- Access Grafana: [http://localhost:3000](http://localhost:3000)  
- Default credentials: `admin/admin`  
- Add Prometheus as a data source: `http://prometheus:9090`

Create a dashboard with these metrics:

- **CPU Usage (Total):**
  ```prometheus
  sum(rate(container_cpu_usage_seconds_total{container_label_com_docker_compose_service="app"}[5m]))
  ```

- **Memory Usage:**
  ```prometheus
  container_memory_usage_bytes{container_label_com_docker_compose_service="app"}
  ```

### 3. Configure Alerts

Defined in `alerts.yml`:

- **HighCPUUsage**: Triggers if CPU usage exceeds 80% for 2 minutes.
- **HighMemoryUsage**: Triggers if memory usage exceeds 500MB for 2 minutes.

Monitor alerts in Prometheus UI: [http://localhost:9090](http://localhost:9090)

---

## Automation Scripts

- **Backup Docker Image**:
  ```bash
  ./scripts/backup.sh
  ```

- **Restart Container**:
  ```bash
  ./scripts/restart.sh
  ```

---

## Verification

Check the following endpoints:

- **Application**: [http://localhost:5000/api](http://localhost:5000/api)
- **Prometheus**: [http://localhost:9090](http://localhost:9090)
- **Grafana**: [http://localhost:3000](http://localhost:3000)

---

## Stress Testing

Simulate load on the application container:

1. **Find the container ID**:
   ```bash
   docker ps | grep app
   ```

2. **Install stress-ng**:
   ```bash
   docker exec -it <container_id> apk add stress-ng
   ```

3. **Run a CPU stress test**:
   ```bash
   docker exec -it <container_id> stress-ng --cpu 2 --timeout 300s
   ```

---

## Troubleshooting

### Jenkins Logs

- Review build logs for detailed error messages.

### Docker Socket

Ensure `/var/run/docker.sock` is accessible:
```bash
sudo chown jenkins:docker /var/run/docker.sock
sudo usermod -aG docker jenkins
```

### Trivy Configuration

- Verify `secret-config/trivy-secret.yaml` exists:
  ```bash
  ls -la secret-config/
  ```

- Check Trivy logs for file path or permission issues.

### Image Name

- Confirm the Docker image name in `docker-compose.yml` matches `${JOB_NAME}_app`:
  ```bash
  docker images
  ```

- Update the pipeline if necessary.

### Trivy Errors

- Verify Docker daemon connectivity:
  ```bash
  docker -H unix:///var/run/docker.sock info
  ```

- Ensure `trivy-secret.yaml` is present for secret scans.

---

## Contributing

We welcome contributions! Please:

- Submit issues or pull requests to: [github.com/devopstrust/flask_jenkins_cicd](https://github.com/devopstrust/flask_jenkins_cicd)
- Test changes in a local Jenkins environment before submission.

---

## License

This project is licensed under the MIT License.
```