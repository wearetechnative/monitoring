---
# monitoring-dxjm
title: close-raw-firewall-ports-9090-9100-9115-9109
status: completed
type: task
priority: normal
created_at: 2026-09-04T09:34:59Z
updated_at: 2026-09-04T10:15:26Z
parent: monitoring-pkc2
---

Remove `9090 9100 9115 9109` from `networking.firewall.allowedTCPPorts` in
`module/prometheus/prometheus.nix:40`. Defense-in-depth on top of localhost
binding — these ports serve no function since all scrapes are localhost.

## Summary of Changes

Removed 9090 9100 9115 9109 from networking.firewall.allowedTCPPorts in module/prometheus/prometheus.nix.
