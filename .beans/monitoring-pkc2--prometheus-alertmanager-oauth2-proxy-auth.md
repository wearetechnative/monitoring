---
# monitoring-pkc2
title: prometheus-alertmanager-oauth2-proxy-auth
status: completed
type: epic
priority: high
created_at: 2026-09-04T09:34:44Z
updated_at: 2026-09-04T10:16:17Z
---

Add authenticated access to Prometheus and Alertmanager in the
`grafana-prometheus` monitoring module. Today the module publishes
`prometheus.<domain>` and `alertmanager.<domain>` nginx vhosts with **no
authentication** (`module/grafana/grafana.nix`), and `module/prometheus/
prometheus.nix` opens raw ports `9090 9100 9115 9109` on the host firewall.
Every scrape target is `localhost`, so those ports serve no function and are
pure attack surface.

## Goal

Introduce an `oauth2-proxy` service (OIDC provider) and protect the Prometheus
and Alertmanager vhosts with nginx `auth_request`. Authorization is group-gated
via the OIDC `groups` claim. Bind Prometheus, its exporters and Alertmanager to
`127.0.0.1` so the raw ports become inert, and drop them from the firewall.

## Design decisions (from exploration)

- **Reverse-proxy auth, not native.** Prometheus/Alertmanager have no OIDC
  login; only HTTP basic auth. `oauth2-proxy` + nginx `auth_request` reuses an
  external IdP (e.g. AWS Cognito) and gives SSO consistent with Grafana.
- **Single oauth2-proxy for both subdomains** via `--cookie-domain=.<domain>`.
- **Localhost binding neutralizes the open ports** even before firewall changes.
- **Provider config stays generic** (issuer URL, client id, secret path, cookie
  secret path, allowed groups) — no Cognito specifics baked into the module.

## Related

- elastinix wrapper epic `prometheus-alertmanager-cognito-auth`
  (`elastinix-wx2c`) exposes these options through
  `elastinix.services.grafana-prometheus`.
- Consumed by `improvement_it-iit_servers` epic
  `improvement_it-iit_servers-0wk2` (IIT monitoring host, AWS Cognito).

## Summary of Changes

All child stories implemented and archived under openspec change 2026-09-04-add-prometheus-alertmanager-oauth2-auth. Prometheus/Alertmanager now behind oauth2-proxy (OIDC) with nginx auth_request, localhost binding of all metrics endpoints, and firewall tightening. Committed as f758f11133532aa8c08accec97c0170bb0209ded.
