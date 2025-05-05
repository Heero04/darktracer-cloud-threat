from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
import os
import pandas as pd
import boto3
import joblib
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType


def download_from_s3(bucket, prefix, local_dir):
    """Download files from S3 to local directory"""
    print(f"Attempting to download from s3://{bucket}/{prefix} to {local_dir}")
    s3 = boto3.client('s3')
    os.makedirs(local_dir, exist_ok=True)

    try:
        response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)

        if 'Contents' not in response:
            raise FileNotFoundError(f"No files found in s3://{bucket}/{prefix}")

        for obj in response['Contents']:
            if obj['Key'].endswith('.csv'):
                local_file = os.path.join(local_dir, os.path.basename(obj['Key']))
                print(f"Downloading s3://{bucket}/{obj['Key']} to {local_file}")
                s3.download_file(bucket, obj['Key'], local_file)
                print(f"Successfully downloaded {local_file}")
    except Exception as e:
        print(f"Error downloading from S3: {str(e)}")
        raise


def upload_to_s3(local_path, bucket, prefix):
    """Upload ONNX model directly to S3"""
    print(f"Uploading ONNX model to S3...")
    s3 = boto3.client('s3')

    try:
        s3_key = os.path.join(prefix, os.path.basename(local_path))
        print(f"Uploading {local_path} to s3://{bucket}/{s3_key}")
        s3.upload_file(local_path, bucket, s3_key)
        print(f"Successfully uploaded model to s3://{bucket}/{s3_key}")

    except Exception as e:
        print(f"Error uploading to S3: {str(e)}")
        raise


# Configuration
input_dir = "/opt/ml/input/data/training"
output_dir = "/opt/ml/model"
bucket = "darktracer-training-bucket-dev"
input_prefix = "input/"
output_prefix = "output"

# Ensure local directories exist
os.makedirs(output_dir, exist_ok=True)
os.makedirs(input_dir, exist_ok=True)

# Download data from S3
download_from_s3(bucket=bucket, prefix=input_prefix, local_dir=input_dir)

# Load data from .csv files
csv_files = [f for f in os.listdir(input_dir) if f.endswith(".csv")]
dfs = []
for file_name in csv_files:
    file_path = os.path.join(input_dir, file_name)
    print(f"Reading: {file_path}")
    df = pd.read_csv(file_path)
    dfs.append(df)

data = pd.concat(dfs, ignore_index=True)
print("Training data shape:", data.shape)

# Create label column based on destination port (FTP attack example)
data['label'] = data['dst_port'].apply(lambda x: 1 if x == 21 else 0)

# Prepare features and target variable
X = data.drop(columns=['label']).select_dtypes(include=['number'])
y = data['label']

# Train/test split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Train a simple RandomForest model
model = RandomForestClassifier()
model.fit(X_train, y_train)

# Evaluate model accuracy
accuracy = model.score(X_test, y_test)
print(f"Validation Accuracy: {accuracy:.4f}")

# Convert model to ONNX format
onnx_output_path = os.path.join(output_dir, "model.onnx")
initial_type = [("input", FloatTensorType([None, X.shape[1]]))]
onnx_model = convert_sklearn(model, initial_types=initial_type)
with open(onnx_output_path, "wb") as f:
    f.write(onnx_model.SerializeToString())
print(f"Model saved in ONNX format to {onnx_output_path}")

# Upload ONNX model to S3
upload_to_s3(
    local_path=onnx_output_path,
    bucket=bucket,
    prefix=output_prefix
)

