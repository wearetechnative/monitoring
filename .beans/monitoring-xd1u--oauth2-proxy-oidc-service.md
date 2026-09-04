---
# monitoring-xd1u
title: oauth2-proxy-oidc-service
status: completed
type: feature
priority: high
created_at: 2026-09-04T09:34:59Z
updated_at: 2026-09-04T10:15:26Z
parent: monitoring-pkc2
---

Add an `oauth2-proxy` NixOS service to the module. Provider = `oidc` against a
generic OIDC issuer. Read the groups claim via `--oidc-groups-claim` and
restrict with `--allowed-group`. Cookie secret and OIDC client secret are read
from file paths (agenix at the consumer). Set `--cookie-domain=.<root_domain>`
and `--whitelist-domain` so one instance serves both prometheus.* and
alertmanager.* and shares the login session (SSO with Grafana).

Suggested location: new `module/oauth2-proxy/` wired from `module/default.nix`.

## Summary of Changes

Added `module/oauth2-proxy/default.nix`: single `services.oauth2-proxy` OIDC instance (provider=oidc, reverse-proxy, setXauthrequest, 127.0.0.1:4180). Client + cookie secrets read from files via systemd LoadCredential. cookie-domain/whitelist-domain = .<root_domain> for SSO; oidc-groups-claim + allowed-group from options.
