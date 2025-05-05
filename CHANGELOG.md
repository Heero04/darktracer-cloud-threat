# 📌 Changelog 

## [v0.6] - 2025-04-25

### Implemented (Phase 7 Continued – Honeypot Offensive Lab Expansion & Logging)

- 🐍 **OpenCanary Deployment** (Amazon Linux 2):
  - Installed via `pip3 install opencanary`
  - Created config using `opencanaryd --copyconfig`
  - Symlinked `twistd` binary to resolve execution errors
  - Downgraded `urllib3` to avoid OpenSSL 1.0.x compatibility issue
  - Launched OpenCanary daemon successfully (`opencanaryd --start`)
  - Verified log generation in `/var/tmp/opencanary.log`

- 🔥 **Attack Simulation from Kali (Phase 5 Offensive Validation)**:
  - Kali EC2 initiated targeted scans:
    - `nmap -sS -Pn $HONEYPOT`
    - `nmap -A -Pn $HONEYPOT`
    - `hydra -l root -P rockyou.txt ssh://$HONEYPOT`
  - Detected:
    - Port 21 (FTP): Open
    - Port 80: Closed (expected)

## [v0.5] - 2025-04-25

### Integrated (Phase 6 - Athena Data Pipeline)
- Created Lambda function (`darktracer-athena-unload-<env>`) for automated data processing
- Implemented daily scheduled execution using CloudWatch Events/EventBridge
- Configured Lambda environment with workspace-aware resource naming
- Set up IAM roles and policies for Athena, S3, and CloudWatch access
- Added Python script for Athena query execution and data unloading:
  - COUNT query to check for data presence
  - UNLOAD operation with SNAPPY compression and partitioning
  - Error handling and logging implementation
  - Cleanup procedures for Athena query results
- Established S3 data paths:
  - Query results: `s3://<project>-training-bucket-<env>/athena-results/`
  - Unloaded data: `s3://<project>-training-bucket-<env>/input/`
- Implemented CloudWatch logging with 14-day retention
- Added workspace-specific tagging for resource management


## [v0.4] - 2025-04-23  

### Integrated (Phase 5 – Offensive Lab Deployment: Kali + Honeypot Testing)
- Deployed **Kali Linux EC2 instance** in Terraform using Kali AMI (cloud version, t3.micro)
- Created SSH key pair and configured secure access (`chmod 400`) for private key
- Added Terraform outputs for public and private IPs of both Kali and Honeypot instances
- Configured **Kali EC2 security group** to allow SSH only from operator’s public IP
- Created **Honeypot EC2 security group** allowing all inbound traffic from Kali's **security group**, not public IP
- Deployed EC2 Honeypot with correct SG + subnet configuration

## [v0.3] - 2025-04-19  

### Integrated (Phase 4 – SageMaker ML Training Pipeline)  
- Created Terraform-managed S3 bucket for training data and model output (`darktracer-training-bucket-<env>`)  
- Enabled versioning and encryption on training bucket  
- Generated Athena UNLOAD output to `/input/` path in S3 for SageMaker consumption  
- Verified and configured S3 bucket permissions for SageMaker role  
- Built SageMaker-compatible Docker image and pushed to ECR (`darktracer-file-processor`)  
- Configured IAM role (`sagemaker-execution-role`) with necessary `s3:*` and `ecr:*` permissions  
- Attached custom inline policy for ECR and S3 access  
- Validated container entrypoint and training script behavior inside SageMaker  
- Successfully launched multiple SageMaker training jobs via CLI with dynamic job naming  
- Set up training config (`sagemaker-training-config.json`) to point to custom image and Athena-exported input  
- Used CLI and Terraform (`null_resource`) to launch and test job lifecycle  
- Captured training logs in CloudWatch and confirmed container behavior  
- Output model artifacts delivered to versioned `/output/` path in S3  

## [v0.2] - 2025-04-14  

### Integrated (Phase 3 – Log Pipeline)  
- Kinesis Firehose Delivery Stream: CloudWatch logs → S3  
- IAM Role for Firehose with S3 and CloudWatch permissions  
- Subscription filter from `/aws/vpc/flowlogs/...` to Firehose  
- Subscription filter from `/darktracer/honeypot/messages` to Firehose  
- S3 log archive bucket with versioning, encryption, and public access block  
- Flow logs and Honeypot logs confirmed in CloudWatch and S3  
- Firehose delivery errors resolved and logs validated  
- VPC Endpoint for Firehose removed (not supported) and noted for future exploration  

## [v0.1] - 2025-04-13

### Added
- Terraform base project structure and variable scaffolding
- Support for isolated workspaces using `terraform.workspace`
- VPC with custom CIDR block and public subnet
- Internet Gateway and routing for external access
- Security Group allowing inbound SSH (22) and HTTP (80) only
- Network ACLs restricting traffic to honeypot-specific ports
- EC2 Honeypot instance (Amazon Linux 2) with dynamic tagging
- Workspace-based resource naming for `dev`, `prod`, etc.
- Public IP output for honeypot EC2 instance
- SSH access to EC2 validated using key pair

---

### Implemented (Phase 1 & 2 Completion)
- CloudWatch Agent installed on EC2 via user-data script
- SSM Parameter Store used for agent configuration (`CWA_config`)
- IAM Role with scoped permissions for SSM & CloudWatch Agent
- CloudWatch Log Group: `/darktracer/honeypot/messages`
- CloudTrail created with multi-region support & encrypted S3 bucket
- Secure S3 bucket for CloudTrail logs with logging & versioning
- VPC Flow Logs enabled for entire VPC (traffic type: ALL)
- IAM Role and CloudWatch Log Group for Flow Logs
- Log group `/aws/vpc/flowlogs/darktracer-dev` confirmed receiving data