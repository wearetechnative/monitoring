## Why

The `grafana-prometheus` module today publishes the `prometheus.<domain>` and
`alertmanager.<domain>` nginx vhosts with **no authentication**
(`module/grafana/grafana.nix`), and `module/prometheus/prometheus.nix` opens raw
ports `9090 9100 9115 9109` on the host firewall. Every scrape target is
`localhost`, so those ports serve no function and are pure attack surface.
Anyone who can reach the host can read all metrics and silence/fire alerts.

Bean: `monitoring-pkc2` (epic `prometheus-alertmanager-oauth2-proxy-auth`).

## What Changes

- New `oauth2-proxy` OIDC service (`module/oauth2-proxy/`) that authenticates
  against a generic OIDC issuer (e.g. AWS Cognito), reads a configurable groups
  claim, and restricts access to an allowed-groups list.
- Prometheus and Alertmanager nginx vhosts protected with `auth_request`
  delegating to oauth2-proxy, with per-vhost `/oauth2/` locations and a
  `401 -> /oauth2/start?rd=...` redirect. Grafana vhost is left unchanged (it
  does its own OAuth).
- A single oauth2-proxy instance serves both subdomains via
  `--cookie-domain=.<root_domain>` and `--whitelist-domain`, giving SSO across
  prometheus, alertmanager and the Grafana session.
- Prometheus, the node/blackbox/vulnix exporters and Alertmanager bound to
  `127.0.0.1`, neutralizing the public raw ports.
- Raw ports `9090 9100 9115 9109` removed from
  `networking.firewall.allowedTCPPorts` (defense-in-depth on top of the
  localhost binding).
- New `services.grafana-prometheus.oauth2Proxy` option surface plus updated
  `example-configuration.nix` and README.

## Capabilities

### New Capabilities

- `grafana-prometheus-auth`: reverse-proxy OIDC authentication and group-based
  authorization for the Prometheus and Alertmanager vhosts, with localhost
  binding and firewall hardening of the metrics ports.

### Modified Capabilities

<!-- none -->

## Impact

- **monitoring**: new `module/oauth2-proxy/default.nix`; option surface in
  `module/default.nix`; auth vhosts in `module/grafana/grafana.nix`; localhost
  binding in `module/prometheus/prometheus.nix`,
  `module/prometheus/alertmanager.nix`, `module/prometheus/exporters/*`;
  firewall change in `module/prometheus/prometheus.nix`; docs in
  `example-configuration.nix` and `README`.
- **Consumers**: must create a dedicated OIDC app client with callback URLs
  `https://prometheus.<domain>/oauth2/callback` and
  `https://alertmanager.<domain>/oauth2/callback`, and provide two secret files
  (OIDC client secret, cookie secret). Backwards compatible: with
  `oauth2Proxy.enable = false` (default) behaviour is unchanged except the
  localhost binding and firewall tightening.
- **elastinix**: wrapper epic `elastinix-wx2c` exposes these options through
  `elastinix.services.grafana-prometheus`.
