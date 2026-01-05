{ config, pkgs, ... }:

{
  imports = [
    # Import the monitoring module from the flake
    # monitoring.nixosModules.${system}.monitoring
  ];

  services.monitoring = {
    enable = true;

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
}
