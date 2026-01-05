{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.monitoring;

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
  ];

  options.services.monitoring = {
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
