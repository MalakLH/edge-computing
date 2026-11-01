
'''

A signed URL is an ordinary URL with additional security parameters attached to it. 
These parameters prove that the URL was signed using an authorized private key and specify when 
the permission expires. If someone tries to access it without authorization, CloudFront should reject the request.

'''

import datetime
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from botocore.signers import CloudFrontSigner
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding


def main():

    project_root = Path(__file__).resolve().parent.parent
    load_dotenv(project_root / ".env")
    
    if len(sys.argv) < 2:
        print(
            'Usage: python scripts/sign_url.py '
            '"https://YOUR_DOMAIN/private/file.pdf" [seconds]'
        )
        sys.exit(1)

    url = sys.argv[1]
    lifetime = int(sys.argv[2]) if len(sys.argv) > 2 else 300

    if lifetime <= 0:
        print("Error: URL lifetime must be greater than zero.")
        sys.exit(1)

    key_id = os.getenv("CF_KEY_ID")
    if not key_id:
        print("Error: CF_KEY_ID environment variable is not set.")
        sys.exit(1)

    private_key_path = Path("keys/private_key.pem")
    if not private_key_path.is_file():
        print(f"Error: private key not found: {private_key_path}")
        sys.exit(1)

    with private_key_path.open("rb") as key_file:
        private_key = serialization.load_pem_private_key(
            key_file.read(),
            password=None,
        )

    def rsa_signer(message):
        return private_key.sign(
            message,
            padding.PKCS1v15(),
            hashes.SHA1(),
        )

    expires = datetime.datetime.now(
        datetime.timezone.utc
    ) + datetime.timedelta(seconds=lifetime)

    signer = CloudFrontSigner(key_id, rsa_signer)

    signed_url = signer.generate_presigned_url(
        url,
        date_less_than=expires,
    )

    print(signed_url)


if __name__ == "__main__":
    main()
