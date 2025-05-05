FROM python:3.10-slim

# Install dependencies
RUN pip install --no-cache-dir \
    pandas \
    numpy \
    scikit-learn \
    xgboost \
    boto3 \
    skl2onnx \
    onnx

# Copy training code
COPY train.py /opt/ml/code/train.py
WORKDIR /opt/ml/code

# Set entry point for SageMaker or local container
ENTRYPOINT ["python", "train.py"]

