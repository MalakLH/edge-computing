
resource "aws_cloudfront_public_key" "k" {
  name        = "edge-lab-key"
  encoded_key = file("${path.module}/../keys/public_key.pem")
}

resource "aws_cloudfront_key_group" "kg" {
  name  = "edge-lab-kg"
  items = [aws_cloudfront_public_key.k.id]
}