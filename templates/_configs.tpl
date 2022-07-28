{{- define "config-haproxy.cfg" }}
{{- if .Values.haproxy.customConfig }}
{{ tpl .Values.haproxy.customConfig . | indent 4 }}
{{- else }}
    global
      log stdout format iso daemon notice

    defaults REDIS
      mode tcp
      timeout connect {{ .Values.haproxy.timeout.connect }}
      timeout server {{ .Values.haproxy.timeout.server }}
      timeout client {{ .Values.haproxy.timeout.client }}
      timeout check {{ .Values.haproxy.timeout.check }}

    {{- if .Values.haproxy.resolvers}}
    resolvers kubdns
      nameserver ns1 {{ .Values.haproxy.resolvers }}
      nameserver ns2 coredns.kube-system.svc.cluster.local:53
      hold valid 30s
      hold other 30s
      hold nx 30s
      hold refused 30s
      hold obsolete 60s
      accepted_payload_size 8192

      # Whether to add nameservers found in /etc/resolv.conf
      parse-resolv-conf
      # How many times to retry a query
      resolve_retries 5
      # How long to wait between retries when no valid response has been received
      timeout retry 3s
      # How long to wait for a successful resolution
      timeout resolve 5s
    {{- end }}
    
    listen health_check_http_url
      bind :8888
      mode http
      monitor-uri /healthz
      option      dontlognull

    listen stats # Define a listen section called "stats"
      bind :7000 # Listen on localhost:9000
      mode http
      stats enable  # Enable stats page
      # stats hide-version  # Hide HAProxy version
      stats realm Haproxy\ Statistics  # Title text for popup window
      stats uri / # Stats URI

    {{- $root := . }}
    {{- $fullName := include ".fullname" . }}
    {{- $replicas := int (toString .Values.redis.replicas) }}

    #master
    frontend ft_redis_master
      bind *:{{ $root.Values.redis.redisPort }}
      log global
      use_backend bk_redis_master
    {{- if .Values.haproxy.readOnly.enabled }}
    #slave
    frontend ft_redis_slave
      bind *:{{ .Values.haproxy.readOnly.port }}
      use_backend bk_redis_slave
    {{- end }}
    # Check all redis servers to see if they think they are master
    backend bk_redis_master
      {{- if .Values.haproxy.stickyBalancing }}
      balance source
      hash-type consistent
      {{- end }}
      mode tcp
      log global
      option tcp-check
      tcp-check connect
      {{- if .Values.auth }}
      tcp-check send "AUTH ${AUTH}"\r\n
      tcp-check expect string +OK
      {{- end }}
      tcp-check send PING\r\n
      tcp-check expect string +PONG
      tcp-check send info\ replication\r\n
      tcp-check expect string role:master
      tcp-check send QUIT\r\n
      tcp-check expect string +OK
      {{- range $i := until $replicas }}
      server R{{ $i }} rfr-{{ $fullName }}-node-{{ $i }}.rfr-{{ $fullName }}-node.{{$root.Release.Namespace}}.svc.{{ $root.Values.haproxy.clusterDomain }}:{{ $root.Values.redis.redisPort }} check {{ if $root.Values.haproxy.resolvers}}resolvers kubdns{{- end}} resolve-prefer ipv4 inter {{ $root.Values.haproxy.checkInterval }} fall 3 rise 1
      {{- end }}
    {{- if .Values.haproxy.readOnly.enabled }}
    backend bk_redis_slave
      {{- if .Values.haproxy.stickyBalancing }}
      balance source
      hash-type consistent
      {{- end }}
      mode tcp
      option tcp-check
      tcp-check connect
      {{- if .Values.auth }}
      tcp-check send AUTH\ REPLACE_AUTH_SECRET\r\n
      tcp-check expect string +OK
      {{- end }}
      tcp-check send PING\r\n
      tcp-check expect string +PONG
      tcp-check send info\ replication\r\n
      tcp-check expect string role:slave
      tcp-check send QUIT\r\n
      tcp-check expect string +OK
      {{- range $i := until $replicas }}
      server R{{ $i }} rfr-{{ $fullName }}-node-{{ $i }}.rfr-{{ $fullName }}-node.{{$root.Release.Namespace}}.svc.{{ $root.Values.haproxy.clusterDomain }}:{{ $root.Values.redis.redisPort }} check {{ if $root.Values.haproxy.resolvers}}resolvers kubdns{{- end}} resolve-prefer ipv4 inter {{ $root.Values.haproxy.checkInterval }} fall 3 rise 1
      {{- end }}
    {{- end }}
    {{- if .Values.haproxy.metrics.enabled }}
    frontend metrics
      mode http
      bind *:{{ .Values.haproxy.metrics.port }}
      option http-use-htx
      http-request use-service prometheus-exporter if { path {{ .Values.haproxy.metrics.scrapePath }} }
    {{- end }}
{{- if .Values.haproxy.extraConfig }}
    # Additional configuration
{{ .Values.haproxy.extraConfig | indent 4 }}
{{- end }}
{{- end }}
{{- end }}