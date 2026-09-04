---
# monitoring-14bd
title: nginx-auth-request-prometheus-alertmanager
status: completed
type: feature
priority: high
created_at: 2026-09-04T09:34:59Z
updated_at: 2026-09-04T10:15:26Z
parent: monitoring-pkc2
---

Protect the `prometheus.${root_domain}` and `alertmanager.${root_domain}` nginx
vhosts (module/grafana/grafana.nix) with `auth_request` delegating to
oauth2-proxy. Add the `/oauth2/` location (proxy_pass to oauth2-proxy),
`auth_request /oauth2/auth;`, and the 401 -> `/oauth2/start?rd=...` redirect on
`location /`. Keep `enableACME`/`forceSSL`. Grafana vhost stays unchanged (it
does its own OAuth).

## Summary of Changes

`module/grafana/grafana.nix`: prometheus.* and alertmanager.* vhosts gain /oauth2/, = /oauth2/auth, auth_request /oauth2/auth and a 401 -> /oauth2/start?rd=... redirect when oauth2Proxy is enabled; backends proxied to 127.0.0.1. Grafana vhost unchanged. Unauthenticated behaviour preserved when disabled.
