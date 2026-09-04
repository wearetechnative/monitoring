## ADDED Requirements

### Requirement: oauth2-proxy authentication option surface
The module SHALL expose an `services.grafana-prometheus.oauth2Proxy` option group
with: `enable` (bool, default `false`), `oidcIssuerUrl` (str), `clientId` (str),
`clientSecretFile` (path), `cookieSecretFile` (path), `allowedGroups`
(list of str, default `[]`), and `groupsClaim` (str, default `groups`).

#### Scenario: Options available
- **WHEN** the `grafana-prometheus` module is imported
- **THEN** `services.grafana-prometheus.oauth2Proxy.enable` and the other listed
  options are defined and settable

#### Scenario: Required options asserted when enabled
- **WHEN** `services.grafana-prometheus.oauth2Proxy.enable = true` but
  `oidcIssuerUrl`, `clientId`, `clientSecretFile` or `cookieSecretFile` is unset
- **THEN** evaluation fails with an assertion naming the missing configuration

### Requirement: oauth2-proxy OIDC service
When `oauth2Proxy.enable` is `true`, the module SHALL configure a single
`services.oauth2-proxy` instance with `provider = "oidc"`, the configured issuer
URL and client id, `reverseProxy = true`, `setXauthrequest = true`, and
`httpAddress` on `127.0.0.1`. The OIDC client secret and cookie secret SHALL be
read from the configured file paths via systemd credentials (never placed on the
command line or in the Nix store).

#### Scenario: oauth2-proxy unit configured
- **WHEN** `oauth2Proxy.enable = true`
- **THEN** a `oauth2-proxy` systemd service exists using the OIDC provider,
  listening on `127.0.0.1:4180`, loading the client and cookie secrets from the
  configured files

#### Scenario: SSO across subdomains
- **WHEN** `oauth2Proxy.enable = true` with `root_domain = "example.com"`
- **THEN** oauth2-proxy is configured with cookie domain `.example.com` and
  whitelist domain `.example.com` so a login on one subdomain is valid on the
  other

#### Scenario: Group-based authorization
- **WHEN** `allowedGroups = [ "grafana-admin" ]`
- **THEN** oauth2-proxy restricts access to members of `grafana-admin` using the
  configured `groupsClaim`

#### Scenario: Any authenticated user when no groups configured
- **WHEN** `allowedGroups = []`
- **THEN** oauth2-proxy allows any user authenticated by the pool (no group
  restriction)

### Requirement: Authenticated Prometheus and Alertmanager vhosts
When `oauth2Proxy.enable` is `true`, the `prometheus.<root_domain>` and
`alertmanager.<root_domain>` nginx vhosts SHALL require authentication via
`auth_request` delegating to oauth2-proxy, expose a `/oauth2/` location proxied to
oauth2-proxy, and redirect unauthenticated requests (HTTP 401) to
`/oauth2/start?rd=...` on the same host. `enableACME` and `forceSSL` SHALL be
preserved. The Grafana vhost SHALL be unchanged.

#### Scenario: Unauthenticated request redirected to login
- **WHEN** an unauthenticated request hits `prometheus.<root_domain>/`
- **THEN** nginx `auth_request` returns 401 and the request is redirected to
  `/oauth2/start?rd=<original-url>`

#### Scenario: Both subdomains protected
- **WHEN** `oauth2Proxy.enable = true`
- **THEN** both `prometheus.<root_domain>` and `alertmanager.<root_domain>` carry
  the `auth_request` directive and the `/oauth2/` location

#### Scenario: Grafana untouched
- **WHEN** `oauth2Proxy.enable = true`
- **THEN** the `grafana.<root_domain>` vhost has no `auth_request` added by this
  module

### Requirement: Backwards-compatible default
When `oauth2Proxy.enable` is `false` (the default), the Prometheus and
Alertmanager vhosts SHALL keep their current unauthenticated behaviour and no
oauth2-proxy service SHALL be created.

#### Scenario: Auth disabled
- **WHEN** `oauth2Proxy.enable = false`
- **THEN** no `oauth2-proxy` systemd service exists and the vhosts have no
  `auth_request` directive

### Requirement: Localhost binding of metrics endpoints
The module SHALL bind Prometheus, the node/blackbox/vulnix exporters and
Alertmanager to `127.0.0.1`, so they are unreachable on the public interface.
This SHALL apply regardless of the `oauth2Proxy.enable` value.

#### Scenario: Prometheus bound to localhost
- **WHEN** the stack is enabled
- **THEN** `services.prometheus.listenAddress` is `127.0.0.1` and the node,
  blackbox and vulnix exporters and Alertmanager listen on `127.0.0.1`

### Requirement: Metrics ports removed from the firewall
The module SHALL NOT open ports `9090`, `9100`, `9115` or `9109` in the NixOS
firewall, since all scrape targets are localhost.

#### Scenario: Raw ports closed
- **WHEN** the stack is enabled
- **THEN** `networking.firewall.allowedTCPPorts` contains none of
  `9090 9100 9115 9109`
