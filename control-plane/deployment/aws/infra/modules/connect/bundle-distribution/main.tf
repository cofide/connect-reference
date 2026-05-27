/**
 * # connect/bundle-distribution
 *
 * Creates a CloudFront distribution backed by the Connect trust bundle S3 bucket,
 * providing a stable public HTTPS URL from which workload SPIRE servers can fetch
 * trust bundles. Also creates an ACM certificate in us-east-1 (required by
 * CloudFront) and Route53 alias records for the distribution domain.
 */

# --- ACM certificate (us-east-1, required by CloudFront) ---

resource "aws_acm_certificate" "bundle" {
  provider = aws.us_east_1

  domain_name       = var.bundle_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.bundle.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "bundle" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.bundle.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}

# --- CloudFront ---

resource "aws_cloudfront_origin_access_control" "bundle" {
  name                              = var.bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "bundle_bucket" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${var.bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudfront_distribution.bundle.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "bundle" {
  bucket = var.bucket_name
  policy = data.aws_iam_policy_document.bundle_bucket.json
}

resource "aws_cloudfront_distribution" "bundle" {
  enabled         = true
  is_ipv6_enabled = true
  price_class     = var.price_class
  aliases         = [var.bundle_domain]

  origin {
    domain_name              = var.bucket_regional_domain_name
    origin_id                = "s3-bundle"
    origin_access_control_id = aws_cloudfront_origin_access_control.bundle.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-bundle"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    # Reference the validation resource (not the cert directly) so Terraform
    # waits for DNS validation to complete before creating the distribution.
    acm_certificate_arn      = aws_acm_certificate_validation.bundle.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  custom_error_response {
    # S3 returns 403 (not 404) for missing objects in private buckets to avoid
    # revealing whether keys exist. Map to 404 so callers get a meaningful response.
    # response_page_path is required alongside response_code by the CloudFront API;
    # CloudFront falls back to its built-in error page when the path doesn't exist,
    # which is acceptable since bundle clients only check the status code.
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# --- Route53 alias records ---

resource "aws_route53_record" "bundle_a" {
  zone_id = var.hosted_zone_id
  name    = var.bundle_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.bundle.domain_name
    zone_id                = aws_cloudfront_distribution.bundle.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "bundle_aaaa" {
  zone_id = var.hosted_zone_id
  name    = var.bundle_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.bundle.domain_name
    zone_id                = aws_cloudfront_distribution.bundle.hosted_zone_id
    evaluate_target_health = false
  }
}
