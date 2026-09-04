---
# monitoring-6pcf
title: bind-prometheus-exporters-alertmanager-localhost
status: completed
type: feature
priority: high
created_at: 2026-09-04T09:34:59Z
updated_at: 2026-09-04T10:15:26Z
parent: monitoring-pkc2
---

Bind Prometheus (`services.prometheus.listenAddress = "127.0.0.1"`), the node,
blackbox and vulnix exporters, and Alertmanager to `127.0.0.1`. Every scrape
target is already localhost, so nothing legitimate breaks and the public raw
ports become inert. Files: module/prometheus/prometheus.nix,
module/prometheus/alertmanager.nix, module/prometheus/exporters/*.

## Summary of Changes

Bound Prometheus, node + blackbox exporters and Alertmanager to 127.0.0.1; vulnix exporter flask app binds 127.0.0.1.
