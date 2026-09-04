{ config, lib, ... }:

with lib;

let
  cfg = config.services.prometheus;
  alertmanagerCfg = cfg.alertmanagerConfig or { enable = false; configuration = {}; };

in {
  config = mkIf alertmanagerCfg.enable {
    services.prometheus.alertmanager = {
      enable = true;
      port = 9093;
      # Only reachable via the authenticated nginx front door.
      listenAddress = "127.0.0.1";
      configuration = alertmanagerCfg.configuration;
    };
  };
}

