
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "edge-lab-s3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "lambda" {
  name                              = "edge-lab-lambda"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
  price_class     = "PriceClass_100"
  comment         = "edge-lab"

  origin {
    origin_id                = "s3-site"
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  origin {
    origin_id                = "lambda-img"
    domain_name              = replace(replace(aws_lambda_function_url.img.function_url, "https://", ""), "/", "")
    origin_access_control_id = aws_cloudfront_origin_access_control.lambda.id
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id           = "s3-site"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.geo.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.sec.id
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.site.arn
    }
  }

  ordered_cache_behavior { # no function: saves invocations
    path_pattern               = "/assets/*"
    target_origin_id           = "s3-site"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.sec.id
  }

  ordered_cache_behavior {
    path_pattern               = "/img/*"
    target_origin_id           = "lambda-img"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = aws_cloudfront_cache_policy.img.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.sec.id
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.img.arn
    }
  }

  ordered_cache_behavior {
    path_pattern               = "/img-raw/*"
    target_origin_id           = "lambda-img"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = aws_cloudfront_cache_policy.img_raw.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.sec.id
  }

  ordered_cache_behavior {
    path_pattern               = "/private/*"
    target_origin_id           = "s3-site"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.sec.id
    trusted_key_groups         = [aws_cloudfront_key_group.kg.id]
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate { cloudfront_default_certificate = true }
}

