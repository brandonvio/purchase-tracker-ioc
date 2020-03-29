#############################################################
# Brandon Vicedomini
# Purchase Tracker IAC
#############################################################
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

locals {
  bucket_name = "${var.site_name}"
}

#############################################################
# S3 static website
#############################################################
data "template_file" "s3_public_policy" {
  template = "${file("policies/s3-public.json")}"
  vars = {
    bucket_name = local.bucket_name
  }
}

resource "aws_s3_bucket" "site_bucket" {
  bucket = local.bucket_name
  acl    = "public-read"
  policy = data.template_file.s3_public_policy.rendered
  website {
    index_document = "index.html"
    error_document = "index.html"
  }
  tags = {
    name : local.bucket_name
  }
}

output "s3_website_endpoint" {
  value = "${aws_s3_bucket.site_bucket.website_endpoint}"
}

resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.site_bucket.bucket_regional_domain_name
    origin_id   = local.bucket_name
  }

  enabled             = true
  default_root_object = "index.html"

  // All values are defaults from the AWS console.
  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.bucket_name
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  // Here we're ensuring we can hit this distribution using www.runatlantis.io
  // rather than the domain name CloudFront gives us.
  # aliases = [var.site_name]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # // Here's where our certificate is loaded in!
  # viewer_certificate {
  #   acm_certificate_arn = "${aws_acm_certificate.certificate.arn}"
  #   ssl_support_method  = "sni-only"
  # }
}

output "cloudfront_website_endpoint" {
  value = "${aws_cloudfront_distribution.distribution.domain_name}"
}
