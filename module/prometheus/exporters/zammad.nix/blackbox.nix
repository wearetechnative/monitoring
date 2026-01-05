{ pkgs, ... }:
{
  services.prometheus.exporters.blackbox = {
    enable = true;
    port = 9115;
    configFile = pkgs.writeText "blackbox.yml" ''
      modules:
        http_2xx:
          prober: http
          timeout: 15s
          http:
            fail_if_not_ssl: true
            ip_protocol_fallback: false
            method: GET
            no_follow_redirects: false
            preferred_ip_protocol: "ip4"
            valid_http_versions:
              - "HTTP/1.1"
              - "HTTP/2.0"
    '';
  };

  systemd.services.prometheus-blackbox-exporter.serviceConfig.Environment = [
    "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
  ];
}

