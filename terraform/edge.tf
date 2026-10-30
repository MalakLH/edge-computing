
resource "aws_cloudfront_key_value_store" "cfg" { name = "edge-lab-config" }

resource "aws_cloudfront_function" "site" {
  name                         = "edge-lab-site"
  runtime                      = "cloudfront-js-2.0"
  publish                      = true
  code                         = file("${path.module}/../edge/site-request.js")
  key_value_store_associations = [aws_cloudfront_key_value_store.cfg.arn]
}

resource "aws_cloudfront_function" "img" {
  name    = "edge-lab-img"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = file("${path.module}/../edge/img-request.js")
}