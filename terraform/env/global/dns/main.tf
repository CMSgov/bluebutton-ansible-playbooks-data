#
# DNS addresses used for migrating between the HealthAPT and the CCS environments
#

locals {
  base_domain = "bfscloud.net"

  # Internal lb domains
  dpcwelb01   = "internal-dpcwelb01-2074070868.us-east-1.elb.amazonaws.com"
  pdcw10lb01  = "internal-pdcw10lb01-1951212262.us-east-1.elb.amazonaws.com"
  tsbb10lb01  = "internal-tsbb10lb01-758855236.us-east-1.elb.amazonaws.com"

  ccs_prod    = ""
  ccs_prod-sbx = ""
  ccs_test    = ""

  lb_info = {
    prod      = object({apt=local.pdcw10lb01, apt_zone="Z35SXDOTRQ7X7K", ccs=local.ccs_prod, ccs_zone="Z26RNL4JYFTOTI"}),
    prod-sbx  = object({apt=local.dpcwelb01, apt_zone="Z35SXDOTRQ7X7K", ccs=local.ccs_prod-sbx, ccs_zone="Z26RNL4JYFTOTI"}),
    test      = object({apt=local.tsbb10lb01, apt_zone="Z35SXDOTRQ7X7K", ccs=local.ccs_test, ccs_zone="Z26RNL4JYFTOTI"})
  }

  # Each domain is listed here
  #
  # Weight can vary from 0 to 100. 0 being 0 traffic to CCS. 
  #
  subdomains  = [
    object({name="prod", env="prod", weight=0}),
    object({name="prod-stg1", env="prod", weight=0}),
    object({name="prod-sbx", env="prod-sbx", weight=0}),
    object({name="prod-sbx-stg1", env="prod-sbx", weight=0}),
    object({name="test", env="test", weigth=100})
  ]

  common_tags = {application="bfd", business="oeda"}
}

# Setup outside of this scripts
data "aws_route53_zone" "base" {
  name = local.base_domain
}

# Sub-domains
#
resource "aws_route53_record" "health_apt" {
  count   = length(local.subdomains)
  zone_id = data.aws_route53_zone.id
  name    = "${local.subdomains[count.index].name}.${local.base_domain}"
  type    = "A"

  set_identifier = "health_apt"
  weighted_routing_policy {
    weight = max(100 - local.subdomains[count.index].weight, 0)
  }

  alias {
    name                   = lb_info[subdomains[count.index].env].apt
    zone_id                = lb_info[subdomains[count.index].env].apt_zone
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "ccs" {
  count   = length(local.subdomains)
  zone_id = data.aws_route53_zone.id
  name    = "${local.subdomains[count.index].name}.${local.base_domain}"
  type    = "A"
  
  set_identifier = "ccs"
  weighted_routing_policy {
    weight = max(local.subdomains[count.index].weight, 0)
  }

  alias {
    name                   = lb_info[subdomains[count.index].env].ccs
    zone_id                = lb_info[subdomains[count.index].env].ccs_zone
    evaluate_target_health = true
  }
}