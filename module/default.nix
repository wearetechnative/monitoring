{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.grafana-prometheus;

  customerModule = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Customer name (used for job naming and file paths)";
        example = "example";
      };

      probesFile = mkOption {
        type = types.path;
        description = "Path to the YAML file containing URLs to probe";
        example = "./customers/example/probes/urls.yaml";
      };

      alertRules = mkOption {
        type = types.listOf types.path;
        default = [];
        description = "List of alert rule files for this customer";
        example = [ ./customers/example/alerts/alert-ssl_expiration.yml ];
      };

      blackboxModule = mkOption {
        type = types.str;
        default = "http_2xx";
        description = "Blackbox exporter module to use";
      };

      refreshInterval = mkOption {
        type = types.str;
        default = "5m";
        description = "How often to refresh the probes file";
      };

      dashboardsPath = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to directory containing Grafana dashboard JSON files for this customer";
        example = "./dashboards/example";
      };

      dashboardFiles = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Dashboard filename (e.g., 'ssl-check.json')";
            };
            source = mkOption {
              type = types.path;
              description = "Path to the dashboard JSON file (can be an agenix secret path at runtime)";
            };
          };
        });
        default = [];
        description = ''
          List of individual dashboard files for this customer.
          Use this option when dashboards are stored as individual files (e.g., agenix secrets)
          instead of in a directory. Cannot be used together with dashboardsPath.
        '';
        example = lib.literalExpression ''
          [
            {
              name = "ssl-check.json";
              source = config.age.secrets.dashboard-ssl.path;
            }
          ]
        '';
      };

    };
  };

in {
  imports = [
    ./prometheus
    ./grafana
    ./oauth2-proxy
    (lib.mkAliasOptionModule [ "services" "monitoring" ] [ "services" "grafana-prometheus" ])
  ];

  options.services.grafana-prometheus = {
    enable = mkEnableOption "Prometheus and Grafana monitoring stack";

    customers = mkOption {
      type = types.listOf customerModule;
      default = [];
      description = "List of customers to monitor with their specific configurations";
      example = literalExpression ''
        [
          {
            name = "example";
            probesFile = ./customers/example/probes/urls.yaml;
            alertRules = [ ./customers/example/alerts/alert-ssl_expiration.yml ];
          }
          {
            name = "example1";
            probesFile = ./customers/example1/probes/urls.yaml;
            alertRules = [ ./customers/example1/alerts/alert-ssl_expiration.yml ];
          }
        ]
      '';
    };

    root_domain = mkOption {
      type = types.str;
      default = "";
      description = "Root domain needed for grafana nginx configuration";
      example = "example.com";
    };

    oauth2Proxy = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Protect the Prometheus and Alertmanager vhosts with oauth2-proxy
          (OIDC) via nginx `auth_request`. Reuses an external IdP (e.g. AWS
          Cognito) for SSO consistent with Grafana. The Grafana vhost is left
          untouched (it does its own OAuth).

          The consuming configuration must register an OIDC app client with the
          callback URLs `https://prometheus.<root_domain>/oauth2/callback` and
          `https://alertmanager.<root_domain>/oauth2/callback`.
        '';
      };

      oidcIssuerUrl = mkOption {
        type = types.str;
        default = "";
        description = "OIDC issuer URL of the identity provider.";
        example = "https://cognito-idp.eu-central-1.amazonaws.com/eu-central-1_abc123";
      };

      clientId = mkOption {
        type = types.str;
        default = "";
        description = "OIDC app client id for the monitoring oauth2-proxy.";
      };

      clientSecretFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to a file containing the OIDC client secret. Read at runtime via
          systemd credentials (e.g. an agenix secret path); never placed on the
          command line or in the Nix store.
        '';
        example = "/run/agenix/oauth2-proxy-client-secret";
      };

      cookieSecretFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to a file containing the oauth2-proxy cookie secret (a 16, 24 or
          32 byte value). Read at runtime via systemd credentials.
        '';
        example = "/run/agenix/oauth2-proxy-cookie-secret";
      };

      allowedGroups = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          Groups (from the OIDC groups claim) allowed to access Prometheus and
          Alertmanager. Empty means any user authenticated by the pool is
          allowed.
        '';
        example = [ "grafana-admin" ];
      };

      groupsClaim = mkOption {
        type = types.str;
        default = "groups";
        description = ''
          Name of the OIDC token claim carrying group membership. AWS Cognito
          exposes groups under `cognito:groups`.
        '';
        example = "cognito:groups";
      };
    };

    alertmanager = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Prometheus Alertmanager";
      };

      configuration = mkOption {
        type = types.attrs;
        default = {};
        description = ''
          Alertmanager configuration as a Nix attribute set.
          See https://prometheus.io/docs/alerting/latest/configuration/ for available options.

          Note: If you're using agenix or other secret management, configure secrets
          separately in your NixOS configuration and reference them in this configuration.
        '';
        example = literalExpression ''
          {
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
                    api_url_file = "/run/secrets/slack-webhook";
                  }
                ];
              }
            ];
          }
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    # Pass customer configurations to prometheus and grafana modules
    services.prometheus.customerConfigs = cfg.customers;
    services.grafana.customerConfigs = cfg.customers;
    services.grafana.root_domain = cfg.root_domain;

    # Pass alertmanager configuration
    services.prometheus.alertmanagerConfig = {
      enable = cfg.alertmanager.enable;
      configuration = cfg.alertmanager.configuration;
    };
  };
}
