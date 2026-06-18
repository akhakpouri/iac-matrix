# ---------------------------------------------------------------------------
# Custom domain + TLS for the commerce API.
#
#   commerce.godevmatrix.me  --(alias A)-->  ALB  --(:443, ACM cert)-->  tasks
#
# The godevmatrix.me hosted zone is managed outside this workspace; we only read
# it (by id) and write two kinds of record into it: the ACM validation records
# and the api alias record. The ACM cert must be in the ALB's region (us-east-1).
# ---------------------------------------------------------------------------

# Certificate for the API hostname. DNS validation (no email), so issuance is
# fully automatable as long as we can write the validation records below.
resource "aws_acm_certificate" "commerce" {
  domain_name       = var.api_hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# One validation record per domain on the cert (just one here, but the for_each
# handles SANs too). AWS tells us the name/type/value to publish; we write them
# into the hosted zone so ACM can confirm we control the domain.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.commerce.domain_validation_options : dvo.domain_name => {
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

# Blocks until the cert is actually issued. The HTTPS listener references this
# resource's certificate_arn (not the raw cert) so it won't be created until
# validation completes.
resource "aws_acm_certificate_validation" "commerce" {
  certificate_arn         = aws_acm_certificate.commerce.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# The public record. An ALIAS A record (not a literal A or CNAME) is the correct
# way to point a hostname at an ALB — Route 53 resolves it to the ALB's current
# IPs, which rotate. evaluate_target_health lets Route 53 see the ALB's health.
resource "aws_route53_record" "api" {
  zone_id = var.hosted_zone_id
  name    = var.api_hostname
  type    = "A"

  alias {
    name                   = aws_lb.commerce_alb.dns_name
    zone_id                = aws_lb.commerce_alb.zone_id
    evaluate_target_health = true
  }
}
