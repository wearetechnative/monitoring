{ config, pkgs, ... }:

{
  imports = [
    # Import the grafana-prometheus module from the flake
    # grafana-prometheus.nixosModules.${system}.grafana-prometheus
  ];

  services.grafana-prometheus = {
    enable = true;

    root_domain = "example.com";

    # Optional: protect the Prometheus and Alertmanager vhosts with oauth2-proxy
    # (OIDC) via nginx auth_request, reusing an external IdP (e.g. AWS Cognito)
    # for SSO consistent with Grafana. The Grafana vhost keeps its own OAuth.
    #
    # Before enabling, register an OIDC app client on the IdP with the callback
    # URLs:
    #   https://prometheus.example.com/oauth2/callback
    #   https://alertmanager.example.com/oauth2/callback
    # and provide two secret files (configure agenix separately):
    #   - the OIDC client secret
    #   - the oauth2-proxy cookie secret (16, 24 or 32 bytes)
    oauth2Proxy = {
      enable = true;
      oidcIssuerUrl =
        "https://cognito-idp.eu-central-1.amazonaws.com/eu-central-1_abc123";
      clientId = "your-app-client-id";
      clientSecretFile = "/run/agenix/oauth2-proxy-client-secret";
      cookieSecretFile = "/run/agenix/oauth2-proxy-cookie-secret";
      # AWS Cognito exposes groups under the `cognito:groups` claim.
      groupsClaim = "cognito:groups";
      # Only members of these groups may access Prometheus/Alertmanager.
      # Empty means any authenticated user in the pool is allowed.
      allowedGroups = [ "grafana-admin" ];
    };

    customers = [
      {
        name = "example";
        probesFile = ./module/prometheus/customers/example/probes/urls.yaml;
        alertRules = [
          ./module/prometheus/customers/example/alerts/alert-ssl_expiration.yml
        ];
        dashboardsPath = ./module/grafana/dashboards/example;  # Optional: Grafana dashboards
      }
      {
        name = "example1";
        probesFile = ./module/prometheus/customers/example1/probes/urls.yaml;
        alertRules = [
          ./module/prometheus/customers/example1/alerts/alert-ssl_expiration.yml
        ];
        dashboardsPath = ./module/grafana/dashboards/example1;
        blackboxModule = "http_2xx";  # Optional, defaults to "http_2xx"
        refreshInterval = "5m";        # Optional, defaults to "5m"
      }
    ];

    # Optional: Configure Alertmanager for notifications
    alertmanager = {
      enable = true;
      configuration = {
        global.resolve_timeout = "5m";

        route = {
          receiver = "slack-notifications";
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "3h";
        };

        receivers = [
          {
            name = "slack-notifications";
            slack_configs = [
              {
                send_resolved = true;
                channel = "#alerts";
                # Reference your secret file (configure agenix separately)
                api_url_file = "/run/secrets/slack-webhook";
                text = ''
                  {{ range .Alerts }}
                  *{{ .Annotations.summary }}*
                  {{ .Annotations.description }}
                  {{ end }}
                '';
              }
            ];
          }
        ];
      };
    };
  };

  # Example: Configure secrets with agenix (if using agenix)
  # age.secrets.slack-webhook = {
  #   file = ./secrets/slack-webhook.age;
  #   path = "/run/secrets/slack-webhook";
  #   owner = "alertmanager";
  #   group = "alertmanager";
  #   mode = "0400";
  # };
  #
  # oauth2-proxy secrets — read via systemd credentials, so the files only need
  # to be readable by root; oauth2-proxy loads them through LoadCredential.
  # age.secrets.oauth2-proxy-client-secret = {
  #   file = ./secrets/oauth2-proxy-client-secret.age;
  #   path = "/run/agenix/oauth2-proxy-client-secret";
  # };
  # age.secrets.oauth2-proxy-cookie-secret = {
  #   file = ./secrets/oauth2-proxy-cookie-secret.age;
  #   path = "/run/agenix/oauth2-proxy-cookie-secret";
  # };
  # Generate a cookie secret with:
  #   openssl rand -base64 32 | head -c 32
}
