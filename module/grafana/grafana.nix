{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.grafana;
  customerConfigs = cfg.customerConfigs or [ ];
  root_domain = cfg.root_domain;

  # Filter customers that have dashboards configured (either path or individual files)
  customersWithDashboards = filter (customer:
    customer.dashboardsPath != null || (customer.dashboardFiles or [ ]) != [ ])
    customerConfigs;

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
  dashboardFilesFromPath = lib.foldl' lib.mergeAttrs { } (lib.concatMap
    (customer:
      let
        dashboardPath = customer.dashboardsPath;
        files = builtins.filter (file: lib.hasSuffix ".json" file)
          (builtins.attrNames (builtins.readDir dashboardPath));
      in map (file: {
        "grafana/dashboards/${customer.name}/${file}" = {
          source = "${dashboardPath}/${file}";
          mode = "0644";
          user = "grafana";
          group = "grafana";
        };
      }) files)
    (filter (customer: customer.dashboardsPath != null) customerConfigs));

  # Generate environment.etc entries from dashboardFiles (individual file list)
  dashboardFilesFromList = lib.foldl' lib.mergeAttrs { } (lib.concatMap
    (customer:
      map (dashFile: {
        "grafana/dashboards/${customer.name}/${dashFile.name}" = {
          source = dashFile.source;
          mode = "0644";
          user = "grafana";
          group = "grafana";
        };
      }) (customer.dashboardFiles or [ ])) customerConfigs);

  # Merge both sources
  dashboardFiles = lib.mergeAttrs dashboardFilesFromPath dashboardFilesFromList;

  oauth2Cfg = config.services.grafana-prometheus.oauth2Proxy;
  oauth2Addr = "http://127.0.0.1:4180";

  # A vhost for an internal backend, optionally protected by oauth2-proxy via
  # nginx auth_request. When auth is disabled the backend is proxied directly
  # (preserving the module's previous behaviour).
  authVhost = backendPort:
    if oauth2Cfg.enable then {
      enableACME = true;
      forceSSL = true;
      locations = {
        "/oauth2/" = {
          proxyPass = oauth2Addr;
          extraConfig = ''
            proxy_set_header X-Scheme                $scheme;
            proxy_set_header X-Auth-Request-Redirect $scheme://$host$request_uri;
          '';
        };
        "= /oauth2/auth" = {
          proxyPass = "${oauth2Addr}/oauth2/auth";
          extraConfig = ''
            proxy_set_header X-Scheme         $scheme;
            # nginx auth_request includes headers but not the body
            proxy_set_header Content-Length   "";
            proxy_pass_request_body           off;
          '';
        };
        "/" = {
          proxyPass = "http://127.0.0.1:${toString backendPort}";
          extraConfig = ''
            auth_request /oauth2/auth;
            error_page 401 = @redirectToAuth2ProxyLogin;

            # Pass the authenticated identity to the backend
            auth_request_set $user  $upstream_http_x_auth_request_user;
            auth_request_set $email $upstream_http_x_auth_request_email;
            proxy_set_header X-User  $user;
            proxy_set_header X-Email $email;

            # Propagate refreshed session cookies from oauth2-proxy
            auth_request_set $auth_cookie $upstream_http_set_cookie;
            add_header Set-Cookie $auth_cookie;
          '';
        };
        "@redirectToAuth2ProxyLogin" = {
          extraConfig = ''
            return 307 $scheme://$host/oauth2/start?rd=$scheme://$host$request_uri;
          '';
        };
      };
    } else {
      enableACME = true;
      forceSSL = true;
      locations."/" = { proxyPass = "http://127.0.0.1:${toString backendPort}"; };
    };

in {
  config = lib.mkIf config.services.grafana-prometheus.enable {
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
          datasources = [{
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://localhost:9090";
          }];
        };

        dashboards.settings = {
          apiVersion = 1;
          providers = dashboardProviders;
        };
      };

      declarativePlugins = with pkgs.grafanaPlugins; [ grafana-piechart-panel ];
    };

    # Nix store dashboards via environment.etc (symlinks, volgorde-onafhankelijk)
    environment.etc = dashboardFilesFromPath;

    # Agenix-sourced dashboards via activation script (na agenix sentinel)
    system.activationScripts.grafana-dashboards-agenix =
      lib.mkIf (lib.any (c: (c.dashboardFiles or [ ]) != [ ]) customerConfigs) {
        deps = [ "agenix" "users" "groups" ];
        text = lib.concatStrings (lib.concatMap (customer:
          let
            customerDir = "/etc/grafana/dashboards/${customer.name}";
            wantedFiles = lib.concatMapStringsSep " "
              (dashFile: lib.escapeShellArg dashFile.name)
              (customer.dashboardFiles or [ ]);
          in
          [ ''
            mkdir -p ${customerDir}

            # Remove dashboard files no longer present in configuration
            for existing in ${customerDir}/*.json; do
              [ -f "$existing" ] || continue
              filename=$(basename "$existing")
              case " ${wantedFiles} " in
                *" '$filename' "*) ;;
                *) rm -f "$existing" ;;
              esac
            done
          '' ]
          ++
          map (dashFile: ''
            cp ${lib.escapeShellArg (toString dashFile.source)} \
               ${customerDir}/${lib.escapeShellArg dashFile.name}
            chown grafana:grafana \
               ${customerDir}/${lib.escapeShellArg dashFile.name}
            chmod 0644 \
               ${customerDir}/${lib.escapeShellArg dashFile.name}
          '') (customer.dashboardFiles or [ ])
        ) customerConfigs);
      };

    networking.firewall.allowedTCPPorts = [ 3000 ];

    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      # Grafana keeps its own OAuth and is not fronted by oauth2-proxy.
      virtualHosts."grafana.${root_domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = { proxyPass = "http://127.0.0.1:3000"; };
      };

      # Prometheus and Alertmanager are protected by oauth2-proxy when enabled.
      virtualHosts."alertmanager.${root_domain}" = authVhost 9093;
      virtualHosts."prometheus.${root_domain}" = authVhost 9090;
    };
  };
}

