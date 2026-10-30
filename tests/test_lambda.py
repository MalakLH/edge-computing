
import os
import io
import base64
from unittest.mock import patch

from PIL import Image

# Set the environment variable before importing the handler.
os.environ["BUCKET"] = "local-test-bucket"

import sys
from pathlib import Path

LAMBDA_DIR = Path(__file__).resolve().parents[1] / "lambda" / "image"
sys.path.insert(0, str(LAMBDA_DIR))

import handler


# Create a fake original image in memory.
original = Image.new("RGB", (1200, 800), color="blue")
original_buffer = io.BytesIO()
original.save(original_buffer, format="JPEG")
original_buffer.seek(0)


# Simulate the S3 get_object response.
fake_s3_response = {
    "Body": io.BytesIO(original_buffer.getvalue())
}

# Simulate a request from CloudFront.
event = {
    "rawPath": "/img/photo1.jpg",
    "queryStringParameters": {"w": "320"},
    "headers": {"x-img-fmt": "webp"}
}


# Replace the real S3 call with our fake response.
with patch.object(handler.s3, "get_object", return_value=fake_s3_response):

    response = handler.handler(event, None)

    print("Status:", response["statusCode"])
    print("Content-Type:", response["headers"]["content-type"])

    # Decode the returned image.
    image_bytes = base64.b64decode(response["body"])
    result = Image.open(io.BytesIO(image_bytes))

    print("Image format:", result.format)
    print("Image dimensions:", result.size)

    assert response["statusCode"] == 200
    assert result.format == "WEBP"
    assert result.width <= 320

    print("SUCCESS: Image processing works!")

bad_event = {
    "rawPath": "/img/../../secret.txt",
    "queryStringParameters": {},
    "headers": {}
}

response = handler.handler(bad_event, None)

print("Invalid filename status:", response["statusCode"])
assert response["statusCode"] == 400