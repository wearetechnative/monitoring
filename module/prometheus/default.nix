{ config, lib, ... }:

with lib;

let
  cfg = config.services.prometheus;
  customerConfigs = cfg.customerConfigs or [];

  # Generate scrape config for each customer
  customerScrapeConfigs = map (customer: {
    job_name = "blackbox-${customer.name}";
    metrics_path = "/probe";
    params.module = [ customer.blackboxModule ];

    file_sd_configs = [
      {
        files = [ "/etc/prometheus/customers/${customer.name}/probes/urls.yaml" ];
        refresh_interval = customer.refreshInterval;
      }
    ];

    relabel_configs = [
      { source_labels = [ "__address__" ]; target_label = "__param_target"; }
      { source_labels = [ "__param_target" ]; target_label = "instance"; }
      { target_label = "__address__"; replacement = "localhost:9115"; }
    ];
  }) customerConfigs;

  # Flatten all alert rules from all customers
  allAlertRules = flatten (map (customer: customer.alertRules) customerConfigs);

  # Generate environment.etc entries for each customer's probes file
  customerEtcFiles = listToAttrs (map (customer: {
    name = "prometheus/customers/${customer.name}/probes/urls.yaml";
    value = {
      source = customer.probesFile;
      mode = "0644";
      user = "prometheus";
      group = "prometheus";
    };
  }) customerConfigs);

in {
  options.services.prometheus = {
    customerConfigs = mkOption {
      type = types.listOf types.attrs;
      default = [];
      internal = true;
      description = "Customer configurations passed from the monitoring module";
    };

    alertmanagerConfig = mkOption {
      type = types.attrs;
      default = { enable = false; configuration = {}; };
      internal = true;
      description = "Alertmanager configuration passed from the monitoring module";
    };
  };

  config = {
    imports = [
      ./prometheus.nix
      ./alertmanager.nix
      ./exporters/blackbox.nix
      ./exporters/vulnix.nix
    ];

    services.prometheus = {
      scrapeConfigs = mkAfter customerScrapeConfigs;
      ruleFiles = mkAfter allAlertRules;
    };

    environment.etc = customerEtcFiles;

    services.vulnix-exporter.enable = true;
    services.vulnix-exporter.port = 9109;
    services.vulnix-exporter.interval = "monthly";
  };
}

