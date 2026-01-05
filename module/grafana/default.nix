{ config, lib, ... }:

with lib;

{
  options.services.grafana.customerConfigs = mkOption {
    type = types.listOf types.attrs;
    default = [];
    internal = true;
    description = "Customer configurations passed from the monitoring module";
  };

  config = {
    imports = [
      ./grafana.nix
    ];
  };
}

