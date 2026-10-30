
resource "aws_s3_bucket" "site" {
  bucket        = "edge-lab-site-${random_id.s.hex}"
  force_destroy = true
}

resource "aws_s3_bucket" "originals" {
  bucket        = "edge-lab-originals-${random_id.s.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "all" {
  for_each                = { site = aws_s3_bucket.site.id, originals = aws_s3_bucket.originals.id }
  bucket                  = each.value
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "site" {
  bucket     = aws_s3_bucket.site.id
  depends_on = [aws_s3_bucket_public_access_block.all]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect   = "Allow", Principal = { Service = "cloudfront.amazonaws.com" }, Action = "s3:GetObject",
        Resource = "${aws_s3_bucket.site.arn}/*",
      Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn } } },
      # ListBucket makes missing keys return 404 instead of 403
      { Effect   = "Allow", Principal = { Service = "cloudfront.amazonaws.com" }, Action = "s3:ListBucket",
        Resource = aws_s3_bucket.site.arn,
      Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn } } }
    ]
  })
}