{ config, pkgs, lib, ... }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.prometheus-client
    ps.flask
  ]);

  # Python script wordt als bestand in /bin geplaatst
  vulnixExporter = pkgs.writeTextFile {
    name = "vulnix-exporter.py";
    destination = "/bin/vulnix-exporter.py";
    executable = true;
text = ''
  #!/usr/bin/env python3

import json
import socket
from flask import Flask, Response
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST, Gauge

app = Flask(__name__)

# Dynamisch endpoint (hostname)
endpoint = socket.gethostname()

# Prometheus metrics with labels
g_total = Gauge("vulnix_vulnerabilities_total", "Total vulnerabilities", ["endpoint"])
g_crit  = Gauge("vulnix_critical_total", "Critical vulnerabilities", ["endpoint"])
g_high  = Gauge("vulnix_high_total", "High vulnerabilities", ["endpoint"])
g_med   = Gauge("vulnix_medium_total", "Medium vulnerabilities", ["endpoint"])
g_low   = Gauge("vulnix_low_total", "Low vulnerabilities", ["endpoint"])

@app.route("/metrics")
def metrics():
    try:
        with open("/var/lib/vulnix/vulnix.json") as f:
            vulns = json.load(f)

        g_total.labels(endpoint).set(len(vulns))
        g_crit.labels(endpoint).set(sum(1 for v in vulns if v.get("severity") == "CRITICAL"))
        g_high.labels(endpoint).set(sum(1 for v in vulns if v.get("severity") == "HIGH"))
        g_med.labels(endpoint).set(sum(1 for v in vulns if v.get("severity") == "MEDIUM"))
        g_low.labels(endpoint).set(sum(1 for v in vulns if v.get("severity") == "LOW"))

    except Exception as e:
        print("error:", e)

    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.route("/vulnix.json")
def vulnix_json():
    try:
        with open("/var/lib/vulnix/vulnix.json") as f:
            return Response(f.read(), mimetype="application/json")
    except FileNotFoundError:
        return Response("{}", mimetype="application/json")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(${toString config.services.vulnix-exporter.port}))
'';

  };

in {
  options.services.vulnix-exporter = {
    enable = lib.mkEnableOption "Enable vulnix monitoring exporter";

    port = lib.mkOption {
      type = lib.types.int;
      default = 9109;
      description = "Port on which the Vulnix Prometheus exporter listens";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "monthly";
      description = "Calendar interval for vulnix JSON refresh";
    };
  };

  config = lib.mkIf config.services.vulnix-exporter.enable {

    environment.systemPackages = [
      pkgs.vulnix
      pkgs.osv-scanner
      pythonEnv
    ];

    # 1. Vulnix JSON generator
    systemd.services.vulnix-json = {
      description = "Generate vulnix JSON";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          ${pkgs.coreutils}/bin/mkdir -p /var/lib/vulnix
          ${pkgs.vulnix}/bin/vulnix --system --json > /var/lib/vulnix/vulnix.json
        '';
      };
    };

    systemd.timers.vulnix-json = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = config.services.vulnix-exporter.interval;
        Persistent = true;
      };
    };

    # 2. Exporter service
    systemd.services.vulnix-exporter = {
      description = "Vulnix Exporter (JSON + Prometheus)";
      after = [ "network.target" "vulnix-json.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${pythonEnv}/bin/python3 ${vulnixExporter}/bin/vulnix-exporter.py";
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}

