---
# monitoring-ccp0
title: options-and-docs-oauth2-proxy
status: completed
type: task
priority: normal
created_at: 2026-09-04T09:34:59Z
updated_at: 2026-09-04T10:15:26Z
parent: monitoring-pkc2
---

Expose the oauth2-proxy option surface on `services.grafana-prometheus`
(module/default.nix): enable, oidcIssuerUrl, clientId, clientSecretFile,
cookieSecretFile, allowedGroups. Update `example-configuration.nix` and README
with the option surface, required IdP app client + callback URLs
(`https://{prometheus,alertmanager}.<domain>/oauth2/callback`), and the two
secret files.

## Summary of Changes

Added services.grafana-prometheus.oauth2Proxy option surface (enable, oidcIssuerUrl, clientId, clientSecretFile, cookieSecretFile, allowedGroups, groupsClaim) with required-option assertions; documented in example-configuration.nix and new README.md (callback URLs + two secret files).
