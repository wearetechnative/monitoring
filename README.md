# grafana-prometheus

A NixOS module that bundles Grafana, Prometheus, Alertmanager and a set of
exporters (node, blackbox, vulnix) into a single `services.grafana-prometheus`
option surface, and publishes them behind nginx on `grafana.<domain>`,
`prometheus.<domain>` and `alertmanager.<domain>`.

See [`example-configuration.nix`](./example-configuration.nix) for a complete
example.

## Enabling

```nix
services.grafana-prometheus = {
  enable = true;
  root_domain = "example.com";
  customers = [ /* ... */ ];
};
```

## Authentication (oauth2-proxy / OIDC)

By default the `grafana.<domain>` vhost carries Grafana's own OAuth, while the
`prometheus.<domain>` and `alertmanager.<domain>` vhosts are **unauthenticated**.
Enable `oauth2Proxy` to put Prometheus and Alertmanager behind an OIDC identity
provider (e.g. AWS Cognito) via nginx `auth_request`, giving SSO consistent with
Grafana:

```nix
services.grafana-prometheus.oauth2Proxy = {
  enable = true;
  oidcIssuerUrl =
    "https://cognito-idp.eu-central-1.amazonaws.com/eu-central-1_abc123";
  clientId = "your-app-client-id";
  clientSecretFile = "/run/agenix/oauth2-proxy-client-secret";
  cookieSecretFile = "/run/agenix/oauth2-proxy-cookie-secret";
  groupsClaim = "cognito:groups";   # AWS Cognito groups claim
  allowedGroups = [ "grafana-admin" ];
};
```

### Options

| Option             | Type          | Default    | Description                                                        |
| ------------------ | ------------- | ---------- | ------------------------------------------------------------------ |
| `enable`           | bool          | `false`    | Protect Prometheus + Alertmanager with oauth2-proxy.               |
| `oidcIssuerUrl`    | str           | `""`       | OIDC issuer URL of the identity provider.                          |
| `clientId`         | str           | `""`       | OIDC app client id.                                                |
| `clientSecretFile` | path          | `null`     | File with the OIDC client secret (read via systemd credentials).   |
| `cookieSecretFile` | path          | `null`     | File with the cookie secret, 16/24/32 bytes.                       |
| `allowedGroups`    | list of str   | `[]`       | Groups allowed access. Empty = any authenticated pool member.      |
| `groupsClaim`      | str           | `"groups"` | OIDC claim carrying groups (`cognito:groups` for AWS Cognito).     |

### Identity provider setup

Register a dedicated OIDC app client and add **both** callback URLs:

- `https://prometheus.<root_domain>/oauth2/callback`
- `https://alertmanager.<root_domain>/oauth2/callback`

A single oauth2-proxy instance serves both subdomains: the session cookie is
scoped to `.<root_domain>` (`--cookie-domain`) and back-redirects are allowed
across the domain (`--whitelist-domain`), so one login covers Prometheus,
Alertmanager and the Grafana session.

### Secrets

Provide two files (e.g. via agenix). They are read at runtime through systemd
`LoadCredential`, so they are never placed on the command line or in the Nix
store:

- **OIDC client secret** → `clientSecretFile`
- **Cookie secret** → `cookieSecretFile` (generate with
  `openssl rand -base64 32 | head -c 32`)

## Network hardening

Prometheus, the node/blackbox/vulnix exporters and Alertmanager bind to
`127.0.0.1`. Every scrape target is localhost, so the raw ports
(`9090 9100 9115 9109`) are **not** opened on the firewall — the only external
access path is the authenticated nginx vhost on 443.
