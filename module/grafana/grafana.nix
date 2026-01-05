{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.grafana;
  customerConfigs = cfg.customerConfigs or [];
  root_domain  = cfg.root_domain;

  # Filter customers that have dashboards configured (either path or individual files)
  customersWithDashboards = filter (customer:
    customer.dashboardsPath != null || (customer.dashboardFiles or []) != []
  ) customerConfigs;

  # Provisioning providers: one per customer with dashboards
  dashboardProviders = map (customer: {
    name = customer.name;
    folder = customer.name;
    type = "file";
    disableDeletion = false;
    editable = true;
    options.path = "/etc/grafana/dashboards/${customer.name}";
  }) customersWithDashboards;

  # Generate environment.etc entries from dashboardsPath (directory scanning)
  dashboardFilesFromPath =
    lib.foldl' lib.mergeAttrs {} (
      lib.concatMap (customer:
        let
          dashboardPath = customer.dashboardsPath;
          files =
            builtins.filter (file: lib.hasSuffix ".json" file)
            (builtins.attrNames (builtins.readDir dashboardPath));
        in
        map (file: {
          "grafana/dashboards/${customer.name}/${file}" = {
            source = "${dashboardPath}/${file}";
            mode = "0644";
            user = "grafana";
            group = "grafana";
          };
        }) files
      ) (filter (customer: customer.dashboardsPath != null) customerConfigs)
    );

  # Generate environment.etc entries from dashboardFiles (individual file list)
  dashboardFilesFromList =
    lib.foldl' lib.mergeAttrs {} (
      lib.concatMap (customer:
        map (dashFile: {
          "grafana/dashboards/${customer.name}/${dashFile.name}" = {
            source = dashFile.source;
            mode = "0644";
            user = "grafana";
            group = "grafana";
          };
        }) (customer.dashboardFiles or [])
      ) customerConfigs
    );

  # Merge both sources
  dashboardFiles = lib.mergeAttrs dashboardFilesFromPath dashboardFilesFromList;

in
{
  services.grafana = {
    enable = true;

    settings.server = {
      http_port = 3000;
      domain = "${root_domain}";
      root_url = "https://grafana.${root_domain}:443";
      http_addr = "0.0.0.0";
    };

    provision = {
      enable = true;

      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://localhost:9090";
          }
        ];
      };

      dashboards.settings = {
        apiVersion = 1;
        providers = dashboardProviders;
      };
    };

    declarativePlugins = with pkgs.grafanaPlugins; [
      grafana-piechart-panel
    ];
  };

  # Plaats dashboards in /etc/grafana/dashboards/*
  environment.etc = dashboardFiles;

  networking.firewall.allowedTCPPorts = [ 3000 ];


  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."grafana.${root_domain}" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://0.0.0.0:3000";
      };
    };
  };
}

