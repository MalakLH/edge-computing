output "domain" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "bucket" {
  value = aws_s3_bucket.site.bucket
}

output "originals" {
  value = aws_s3_bucket.originals.bucket
}

output "kvs_arn" {
  value = aws_cloudfront_key_value_store.cfg.arn
}

output "public_key_id" {
  value = aws_cloudfront_public_key.k.id
}

output "img_function_url" {
  value = aws_lambda_function_url.img.function_url
}