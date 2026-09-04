## 1. oauth2-proxy OIDC service (monitoring-xd1u)

- [x] 1.1 Create `module/oauth2-proxy/default.nix` and wire it from `module/default.nix`
- [x] 1.2 Configure `services.oauth2-proxy` with `provider = "oidc"`, `oidcIssuerUrl`, `clientID`, `email.domains = [ "*" ]`, `reverseProxy = true`, `setXauthrequest = true`, `httpAddress = "http://127.0.0.1:4180"`
- [x] 1.3 Read the OIDC client secret and cookie secret from file paths via `clientSecretFile` and `cookie.secretFile` (systemd `LoadCredential`)
- [x] 1.4 Set `cookie.domain = ".<root_domain>"` and `extraConfig.whitelist-domain = ".<root_domain>"` for SSO across subdomains
- [x] 1.5 Set `extraConfig.oidc-groups-claim` (default `groups`) and `extraConfig.allowed-group` from `allowedGroups` (only when non-empty)
- [x] 1.6 Set `trustedProxyIP = [ "127.0.0.1/32" ]` to silence the reverse-proxy warning and trust only the local nginx

## 2. Option surface (monitoring-ccp0)

- [x] 2.1 Add `services.grafana-prometheus.oauth2Proxy` options in `module/default.nix`: `enable`, `oidcIssuerUrl`, `clientId`, `clientSecretFile`, `cookieSecretFile`, `allowedGroups`, `groupsClaim`
- [x] 2.2 Add an assertion that when `oauth2Proxy.enable` is `true`, `oidcIssuerUrl`, `clientId`, `clientSecretFile` and `cookieSecretFile` are all set

## 3. nginx auth_request (monitoring-14bd)

- [x] 3.1 Protect `prometheus.<root_domain>` with a `/oauth2/` location, `= /oauth2/auth`, `auth_request /oauth2/auth`, and a `401 -> /oauth2/start?rd=...` redirect
- [x] 3.2 Protect `alertmanager.<root_domain>` the same way
- [x] 3.3 Point the protected backends at `127.0.0.1:9090` / `127.0.0.1:9093`; keep `enableACME`/`forceSSL`; leave the Grafana vhost unchanged
- [x] 3.4 Keep the vhosts unauthenticated (current behaviour) when `oauth2Proxy.enable = false`

## 4. Localhost binding (monitoring-6pcf)

- [x] 4.1 `services.prometheus.listenAddress = "127.0.0.1"`
- [x] 4.2 Node exporter `listenAddress = "127.0.0.1"`
- [x] 4.3 Blackbox exporter `listenAddress = "127.0.0.1"`
- [x] 4.4 Vulnix exporter flask app binds `127.0.0.1`
- [x] 4.5 Alertmanager `listenAddress = "127.0.0.1"`

## 5. Firewall (monitoring-dxjm)

- [x] 5.1 Remove `9090 9100 9115 9109` from `networking.firewall.allowedTCPPorts` in `module/prometheus/prometheus.nix`

## 6. Documentation (monitoring-ccp0)

- [x] 6.1 Document the oauth2-proxy option surface, required IdP app client + callback URLs, and the two secret files in `example-configuration.nix`
- [x] 6.2 Add/extend the README with the same

## 7. Verification

- [x] 7.1 `nix eval` a throwaway NixOS system that enables the stack + oauth2Proxy and assert the oauth2-proxy unit, nginx locations, listen addresses and firewall are correct
- [x] 7.2 Assert the module still evaluates with `oauth2Proxy.enable = false` (backwards compatibility)
- [x] 7.3 `openspec validate --strict`
