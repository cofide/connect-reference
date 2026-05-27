# base/dns

Terragrunt unit that creates a Route53 hosted zone. The zone name and name servers are used by cert-manager (DNS01 challenges), ExternalDNS, the SPIRE OIDC discovery provider, and the Connect trust bundle CloudFront distribution.

## Required configuration

`zone_name` has no default and must be set in `common.local.hcl`:

```hcl
locals {
  zone_name = "control-plane.example.com"
}
```

## Cloudflare NS delegation (optional)

If the parent domain is managed in Cloudflare, this unit can automatically create NS delegation records pointing the subdomain at the Route53 name servers. Set the Cloudflare zone ID and subdomain name in `common.local.hcl` and export your API token before applying:

```hcl
locals {
  zone_name              = "control-plane.example.com"
  cloudflare_zone_id     = "abc123def456abc123def456abc123de"
  cloudflare_record_name = "control-plane"
}
```

```sh
export CLOUDFLARE_API_TOKEN=<token>
terragrunt apply
```

If the parent domain is managed elsewhere, apply the unit without the Cloudflare variables and create the NS records manually using the `name_servers` output.
