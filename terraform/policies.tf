
data "aws_cloudfront_cache_policy" "optimized" { name = "Managed-CachingOptimized" }

resource "aws_cloudfront_origin_request_policy" "geo" {
  name = "edge-lab-geo"
  cookies_config { cookie_behavior = "none" }
  query_strings_config { query_string_behavior = "none" }
  headers_config {
    header_behavior = "whitelist"
    headers { items = ["CloudFront-Viewer-Country"] }
  }
}

resource "aws_cloudfront_cache_policy" "img" {
  name        = "edge-lab-img-normalized"
  min_ttl     = 0
  default_ttl = 86400
  max_ttl     = 31536000
  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = false
    enable_accept_encoding_brotli = false
    cookies_config { cookie_behavior = "none" }
    headers_config {
      header_behavior = "whitelist"
      headers { items = ["x-img-fmt"] }
    }
    query_strings_config {
      query_string_behavior = "whitelist"
      query_strings { items = ["w"] }
    }
  }
}

resource "aws_cloudfront_cache_policy" "img_raw" { # deliberately naive, for the benchmark
  name        = "edge-lab-img-raw"
  min_ttl     = 0
  default_ttl = 86400
  max_ttl     = 31536000
  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = false
    enable_accept_encoding_brotli = false
    cookies_config { cookie_behavior = "none" }
    headers_config { header_behavior = "none" }
    query_strings_config { query_string_behavior = "all" }
  }
}

resource "aws_cloudfront_response_headers_policy" "sec" {
  name = "edge-lab-security"
  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_type_options { override = true }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    content_security_policy {
      content_security_policy = "default-src 'self'; img-src 'self' data:"
      override                = true
    }
  }
}