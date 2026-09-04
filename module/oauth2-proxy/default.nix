{ config, lib, ... }:

with lib;

let
  cfg = config.services.grafana-prometheus.oauth2Proxy;
  root_domain = config.services.grafana-prometheus.root_domain;
in
{
  config = mkIf (config.services.grafana-prometheus.enable && cfg.enable) {

    assertions = [
      {
        assertion = cfg.oidcIssuerUrl != "";
        message = "services.grafana-prometheus.oauth2Proxy.oidcIssuerUrl must be set when oauth2Proxy is enabled.";
      }
      {
        assertion = cfg.clientId != "";
        message = "services.grafana-prometheus.oauth2Proxy.clientId must be set when oauth2Proxy is enabled.";
      }
      {
        assertion = cfg.clientSecretFile != null;
        message = "services.grafana-prometheus.oauth2Proxy.clientSecretFile must be set when oauth2Proxy is enabled.";
      }
      {
        assertion = cfg.cookieSecretFile != null;
        message = "services.grafana-prometheus.oauth2Proxy.cookieSecretFile must be set when oauth2Proxy is enabled.";
      }
      {
        assertion = root_domain != "";
        message = "services.grafana-prometheus.root_domain must be set when oauth2Proxy is enabled.";
      }
    ];

    services.oauth2-proxy = {
      enable = true;
      provider = "oidc";
      oidcIssuerUrl = cfg.oidcIssuerUrl;
      clientID = cfg.clientId;

      # Secrets are read from files via systemd LoadCredential — never on the
      # command line or in the Nix store.
      clientSecretFile = cfg.clientSecretFile;
      cookie.secretFile = cfg.cookieSecretFile;

      # Any user authenticated by the pool passes the e-mail check; real
      # authorization is done via the groups claim below.
      email.domains = [ "*" ];

      # Behind nginx: trust only the local reverse proxy and emit the
      # X-Auth-Request-* headers used by auth_request.
      reverseProxy = true;
      trustedProxyIP = [ "127.0.0.1/32" ];
      setXauthrequest = true;
      httpAddress = "http://127.0.0.1:4180";

      # One instance serving both subdomains + SSO with the Grafana session.
      cookie.domain = ".${root_domain}";

      extraConfig = {
        whitelist-domain = ".${root_domain}";
        oidc-groups-claim = cfg.groupsClaim;
      } // optionalAttrs (cfg.allowedGroups != [ ]) {
        allowed-group = cfg.allowedGroups;
      };
    };
  };
}
