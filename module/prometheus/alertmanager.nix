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
      configuration = alertmanagerCfg.configuration;
    };
  };
}

