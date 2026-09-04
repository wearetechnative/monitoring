{ pkgs, lib, config, ... }:

{
  config = lib.mkIf config.services.grafana-prometheus.enable {
    services.prometheus = {
      enable = true;
      port = 9090;
      # Only reachable via the authenticated nginx front door; every scrape
      # target is localhost so nothing legitimate needs the public interface.
      listenAddress = "127.0.0.1";
      retentionTime = "60d";
      checkConfig = false;

      exporters.node.enable = true;
      exporters.node.listenAddress = "127.0.0.1";

      globalConfig.scrape_interval = "30s";

      # Basis-scrapes voor Prometheus zelf en de node exporter
      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [{ targets = [ "localhost:9090" ]; }];
        }
        {
          job_name = "node";
          static_configs = [{ targets = [ "localhost:9100" ]; }];
        }
        {
          job_name = "vulnix";
          static_configs = [{ targets = [ "localhost:9109" ]; }];
        }

      ];

      # Laat klantmodules extra scrapes toevoegen
      alertmanagers =
        [{ static_configs = [{ targets = [ "localhost:9093" ]; }]; }];

      # Algemene regels of alerts
      #    ruleFiles = [ ./alerts/alert-rules.yml ];
    };

    # Prometheus, the exporters and Alertmanager bind to 127.0.0.1 and every
    # scrape target is localhost, so the former raw ports (9090 9100 9115 9109)
    # serve no function and are not opened on the firewall. Access is only via
    # the authenticated nginx vhosts (443).
  };
}

