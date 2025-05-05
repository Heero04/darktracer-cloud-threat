# ===========================================================
#                     DarkTracer Cloud Threat
#                     IAM Configuration File
# ===========================================================
# Description: Defines all IAM roles and policies for the DarkTracer cloud threat detection system
# 
# Last Updated: YYYY-MM-DD
# ===========================================================

# ----------------------------------------------------------
#                EC2 and CloudWatch Configuration
# ----------------------------------------------------------
# Includes:
# - EC2 instance role for CloudWatch Agent and SSM
# - Instance profile for EC2
# - CloudWatch Agent policy attachment
# - SSM Core policy attachment
# - VPC Flow Logs permissions
# ----------------------------------------------------------

resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "${var.project_name}-ec2-role-${terraform.workspace}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.project_name}-instance-profile-${terraform.workspace}"
  role = aws_iam_role.ec2_cloudwatch_role.name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_core_policy" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "vpc_flow_logs_inline" {
  name = "${var.project_name}-vpcflow-inline-${terraform.workspace}"
  role = aws_iam_role.vpc_flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ],
        Resource = "*"
      }
    ]
  })
}

# ----------------------------------------------------------
#            S3 Output Access Configuration
# ----------------------------------------------------------
# Includes:
# - Output bucket access policies
# - Task role attachments
# - S3 write permissions
# ----------------------------------------------------------

resource "aws_iam_policy" "output_s3_access" {
  name = "${var.project_name}-s3-output-access-${terraform.workspace}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ],
        Resource = [
          "arn:aws:s3:::darktracer-cleaned-logs-dev",
          "arn:aws:s3:::darktracer-cleaned-logs-dev/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "allow_s3_write_output" {
  name = "AllowPutObjectToCleanBucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject"
        ],
        Resource = [
          "arn:aws:s3:::darktracer-cleaned-logs-dev/*"
        ]
      }
    ]
  })
}
# ----------------------------------------------------------
#            SageMaker ECR Configuration
# ----------------------------------------------------------
# Includes:
# - SageMaker ECR pull permissions
# - ECR authorization and access
# - Repository access configuration
# ----------------------------------------------------------

resource "aws_iam_policy" "sagemaker_ecr_pull" {
  name        = "${var.project_name}-sagemaker-ecr-pull-${terraform.workspace}"
  description = "Allow SageMaker to pull custom image from ECR"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = "arn:aws:ecr:us-east-1:469440861178:repository/darktracer-file-processor"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "sagemaker_ecr_policy_attach" {
  name       = "${var.project_name}-sagemaker-ecr-policy-${terraform.workspace}"
  roles      = [aws_iam_role.sagemaker_execution.name]
  policy_arn = aws_iam_policy.sagemaker_ecr_pull.arn
}

# ----------------------------------------------------------
#            Lambda Threat Analyzer Configuration
# ----------------------------------------------------------
# Includes:
# - WAF permissions
# - SNS publishing permissions
# - CloudWatch logs access
# ----------------------------------------------------------

#----------------------------------------------------------
# IAM Policy for Lambda WAF Access
# - Defines permissions for Lambda to interact with WAF
# - Allows updating IP sets and managing WAF rules
#----------------------------------------------------------
resource "aws_iam_role_policy" "lambda_waf_policy" {
  name = "${var.project_name}-lambda-waf-policy-${terraform.workspace}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetIPSet",
          "wafv2:UpdateIPSet",
          "wafv2:ListIPSets",
          "wafv2:ListTagsForResource",
          "wafv2:TagResource",
          "wafv2:UntagResource"
        ]
        Resource = [
          aws_wafv2_ip_set.blocked_ips.arn,
          "${aws_wafv2_ip_set.blocked_ips.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource"
        ]
        Resource = [
          aws_wafv2_web_acl.threat_acl.arn,
          "${aws_wafv2_web_acl.threat_acl.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "wafv2:ListResourcesForWebACL",
          "wafv2:ListWebACLs"
        ]
        Resource = "*"
      }
    ]
  })
}



#----------------------------------------------------------
# IAM Role and Policy Configuration for Bedrock Lambda
# Purpose: Defines permissions for Lambda to interact with Bedrock and S3
# Components: IAM Role and Policy with specific service permissions
#----------------------------------------------------------

#----------------------------------------------------------
# Lambda Execution Role
# - Creates IAM role for Lambda function
# - Enables Lambda service to assume this role
#----------------------------------------------------------
resource "aws_iam_role" "bedrock_lambda_role" {
  name = "${var.project_name}-bedrock-lambda-role-${terraform.workspace}"

  # Trust policy allowing Lambda service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

#----------------------------------------------------------
# Lambda IAM Policy
# - Defines permissions for the Lambda function
# - Includes access to:
#   1. Amazon Bedrock for model invocation
#   2. S3 for log file operations
#   3. CloudWatch for logging
#----------------------------------------------------------
# IAM Role for Lambda
resource "aws_iam_role" "athena_lambda_role" {
  name = "${var.project_name}-athena-unload-role-${terraform.workspace}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "athena_lambda_policy" {
  name = "${var.project_name}-athena-unload-policy-${terraform.workspace}"
  role = aws_iam_role.athena_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:DeleteNamedQuery"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          # Training bucket permissions (destination)
          "arn:aws:s3:::${var.project_name}-training-bucket-${terraform.workspace}/*",
          "arn:aws:s3:::${var.project_name}-training-bucket-${terraform.workspace}",
          # Logs bucket permissions (source)
          "arn:aws:s3:::${var.project_name}-logs-${terraform.workspace}/*",
          "arn:aws:s3:::${var.project_name}-logs-${terraform.workspace}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetPartitions"
        ]
        Resource = "*"
      },
      {
        Action = [
          "sagemaker:InvokeEndpoint"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Add this to your iam.tf file

# IAM Policy for Lambda WAF and SNS Access
# Add or update this policy in your iam.tf
resource "aws_iam_role_policy" "lambda_waf_sns_policy" {
  name = "${var.project_name}-lambda-waf-sns-policy-${terraform.workspace}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetIPSet",
          "wafv2:UpdateIPSet",
          "wafv2:ListIPSets",
          "wafv2:ListTagsForResource",
          "wafv2:TagResource",
          "wafv2:UntagResource"
        ]
        # Use wildcard to ensure access to all WAF resources
        Resource = [
          "arn:aws:wafv2:*:${data.aws_caller_identity.current.account_id}:regional/ipset/*/*",
          "arn:aws:wafv2:*:${data.aws_caller_identity.current.account_id}:regional/webacl/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.threat_alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Make sure your lambda_role has the basic execution role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM role for SageMaker
resource "aws_iam_role_policy" "sagemaker_exec_policy" {
  name = "sagemaker-exec-policy"
  role = aws_iam_role.sagemaker_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:s3:::darktracer-training-bucket-dev/output/*"
      },
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "sts:GetServiceBearerToken",
        Resource = "*",
        Condition = {
          StringEquals = {
            "sts:AWSServiceName" = "ecr.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "sagemaker_exec" {
  name = "sagemaker-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "sagemaker.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}
