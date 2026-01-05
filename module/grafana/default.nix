{ config, lib, ... }:

with lib;

{
  imports = [
    ./grafana.nix
  ];

  options.services.grafana.customerConfigs = mkOption {
    type = types.listOf types.attrs;
    default = [];
    internal = true;
    description = "Customer configurations passed from the monitoring module";
  };

  options.services.grafana.root_domain = mkOption {
    type = types.str;
    default = "";
    internal = true;
    description = "Root domain needed for nginx configuration";
    example = "example.com";
  };
}

