# 🚀 Future Improvements
NACL for EC2

## Automated Data Export
- Implement Glue job for automated data export from Athena to training bucket
- Components needed:
  - AWS Glue Job with Python script
  - EventBridge rule for scheduling
  - IAM role permissions update
  - S3 bucket permissions
- Features to include:
  - Daily automated exports
  - Compression for storage efficiency
  - Partitioned output
  - Error handling and monitoring
