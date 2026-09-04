## Context

Prometheus and Alertmanager have no native OIDC login (only HTTP basic auth), so
authentication must happen at the reverse proxy. nginx `auth_request` delegating
to `oauth2-proxy` is the standard NixOS pattern and lets the stack reuse the same
external IdP (AWS Cognito) that already fronts Grafana, giving a consistent SSO
experience.

## Goals

- Reuse an external OIDC IdP; no credentials stored in the module.
- Single oauth2-proxy instance serving both `prometheus.*` and `alertmanager.*`.
- Group-gated authorization via the OIDC groups claim.
- Metrics endpoints unreachable from the network except through the
  authenticated front door.
- Backwards compatible: default (`oauth2Proxy.enable = false`) keeps the current
  vhosts, only adding the localhost binding and firewall tightening.

## Decisions

### Reverse-proxy auth, not native

Prometheus/Alertmanager cannot do OIDC. `oauth2-proxy` + nginx `auth_request`
reuses Cognito and yields SSO consistent with Grafana. This is the upstream
NixOS-recommended approach and keeps the backends oblivious to auth.

### Secrets via systemd credentials, two separate files

The NixOS `services.oauth2-proxy` module renders `--client-secret-file` and
`--cookie-secret-file` from `clientSecretFile` and `cookie.secretFile` using
systemd `LoadCredential`. This maps cleanly onto two agenix secret files at the
consumer and never exposes secrets on the command line or in the store. We do
**not** use the single `keyFile` env-file approach, because the epic requires two
distinct secret paths.

### Single instance, cookie + whitelist domain

`--cookie-domain=.<root_domain>` scopes the session cookie to all subdomains and
`--whitelist-domain=.<root_domain>` allows the post-login `rd` redirect back to
either subdomain. oauth2-proxy runs in `--reverse-proxy` mode and derives the
per-request callback from the `X-Forwarded-*` headers set by nginx, so both
`https://prometheus.<domain>/oauth2/callback` and
`https://alertmanager.<domain>/oauth2/callback` work from one instance. Both
callback URLs must be registered on the IdP app client.

### Per-vhost oauth2 locations (not the nixpkgs nginx helper)

The nixpkgs `services.oauth2-proxy.nginx` helper centralizes `/oauth2/` on a
single domain. We instead add the `/oauth2/` and `= /oauth2/auth` locations to
each protected vhost so each subdomain owns its callback URL, matching the
documented two-callback-URL model and keeping the redirect on the same host.

### Groups claim configurable

`--oidc-groups-claim` defaults to `groups` but is exposed as `groupsClaim` so
Cognito consumers can set it to `cognito:groups`. `--allowed-group` is emitted
once per entry in `allowedGroups`; an empty list means "any authenticated user in
the pool" (authorization by pool membership only).

### Localhost binding + firewall

Every scrape target is already `localhost`, so binding Prometheus, the exporters
and Alertmanager to `127.0.0.1` breaks nothing and makes the raw ports inert even
before the firewall is tightened. Removing `9090 9100 9115 9109` from the
firewall is defense-in-depth. Grafana (port 3000, own OAuth) is out of scope and
unchanged.

## Risks / Trade-offs

- **Consumer must register two callback URLs** and provision two secrets. Covered
  in the docs and the assertion on required options.
- **`reverseProxy = true` trusts forwarded headers**: mitigated by
  `trustedProxyIP = [ "127.0.0.1/32" ]` and the localhost binding so only nginx
  can reach oauth2-proxy.
- **nixpkgs version skew**: the module is checked standalone against
  `nixos-unstable` but consumed under `nixos-25.11` via elastinix; the
  `services.oauth2-proxy` options used (`provider`, `oidcIssuerUrl`, `clientID`,
  `clientSecretFile`, `cookie.secretFile`, `email.domains`, `reverseProxy`,
  `setXauthrequest`, `httpAddress`, `extraConfig`, `trustedProxyIP`) exist in
  both.
