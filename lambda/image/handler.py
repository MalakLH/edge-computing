import base64, io, os, re
import boto3
from botocore.exceptions import ClientError
from PIL import Image

s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET"]
NAME = re.compile(r"^[A-Za-z0-9_-]+\.(jpg|jpeg|png)$")

def clamp_width(raw, default=640):

    try:
        return max(16, min(int(raw), 2000))
    
    except (TypeError, ValueError):
        return default

def handler(event, context):

    name = event["rawPath"].rsplit("/", 1)[-1]

    if not NAME.match(name):                      # blocks path traversal
        return {"statusCode": 400, "body": "bad name"}
    
    qs = event.get("queryStringParameters") or {}
    hdr = event.get("headers") or {}
    w = clamp_width(qs.get("w"))

    fmt = "webp" if (hdr.get("x-img-fmt") or qs.get("fmt")) == "webp" else "jpeg"

    try:
        body = s3.get_object(Bucket=BUCKET, Key=name)["Body"].read()
    
    except ClientError:
        return {"statusCode": 404, "body": "not found"}
    
    img = Image.open(io.BytesIO(body)).convert("RGB")
    img.thumbnail((w, w * 10))
    buf = io.BytesIO()
    img.save(buf, fmt.upper(), quality=80)

    return {
        "statusCode": 200, "isBase64Encoded": True,
        "headers": {"content-type": f"image/{fmt}",
                    "cache-control": "public, max-age=31536000, immutable"},
        "body": base64.b64encode(buf.getvalue()).decode(),
    }