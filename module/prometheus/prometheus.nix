{ pkgs, lib, ... }:

{
  services.prometheus = {
    enable = true;
    port = 9090;
    retentionTime = "60d";
    checkConfig = false;

    exporters.node.enable = true;

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
    alertmanagers = [
      {
        static_configs = [{ targets = [ "localhost:9093" ]; }];
      }
    ];

    # Algemene regels of alerts
#    ruleFiles = [ ./alerts/alert-rules.yml ];
  };

  networking.firewall.allowedTCPPorts = [ 9090 9100 9115 9109];
}

