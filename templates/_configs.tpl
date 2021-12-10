{{/* vim: set filetype=mustache: */}}

{{- define "config-haproxy.cfg" }}
{{- if .Values.haproxy.customConfig }}
{{ tpl .Values.haproxy.customConfig . | indent 4 }}
{{- else }}
    defaults REDIS
      mode tcp
      timeout connect {{ .Values.haproxy.timeout.connect }}
      timeout server {{ .Values.haproxy.timeout.server }}
      timeout client {{ .Values.haproxy.timeout.client }}
      timeout check {{ .Values.haproxy.timeout.check }}

    {{- if .Values.haproxy.resolvers}}
    resolvers kubdns
      nameserver dns1 {{ .Values.haproxy.resolvers }}
      hold valid 30s
      hold nx 10s
      hold refused 8s
      hold obsolete 30m
      accepted_payload_size 8192
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
    {{- $fullName := include "redis.fullname" . }}
    {{- $replicas := int (toString .Values.redis.replicas) }}
    # {{- $masterGroupName := include "redis.masterGroupName" . }}

    #master
    frontend ft_redis_master
      bind *:{{ $root.Values.redis.redisPort }}
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
      server R{{ $i }} rfr-{{ $fullName }}-node-{{ $i }}.rfr-{{ $fullName }}-node.{{$root.Release.Namespace}}.svc.{{ $root.Values.haproxy.clusterDomain }}:{{ $root.Values.redis.redisPort }} check {{ if $root.Values.haproxy.resolvers}}resolvers kubdns{{- end}} inter {{ $root.Values.haproxy.checkInterval }} fall 1 rise 1
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
      tcp-check expect  string role:slave
      tcp-check send QUIT\r\n
      tcp-check expect string +OK
      {{- range $i := until $replicas }}
      server R{{ $i }} rfr-{{ $fullName }}-node-{{ $i }}.rfr-{{ $fullName }}-node.{{$root.Release.Namespace}}.svc.{{ $root.Values.haproxy.clusterDomain }}:{{ $root.Values.redis.redisPort }} check {{ if $root.Values.haproxy.resolvers}}resolvers kubdns{{- end}} inter {{ $root.Values.haproxy.checkInterval }} fall 1 rise 1
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
# {{- end }}

{{- define "config-haproxy_init.sh" }}
    HAPROXY_CONF=/data/haproxy.cfg
    cp /readonly/haproxy.cfg "$HAPROXY_CONF"
    {{- $root := . }}
    {{- $fullName := include "redis.fullname" . }}
    {{- $replicas := int (toString .Values.redis.replicas) }}
    {{- range $i := until $replicas }}
    for loop in $(seq 1 10); do
      getent hosts rfr-{{ $fullName }}-node-{{ $i }}.rfr-{{ $fullName }}-node.{{$root.Release.Namespace}}.svc.{{ $root.Values.haproxy.clusterDomain }} && break
      echo "Waiting for service rfr-{{ $fullName }}-node-{{ $i }} to be ready ($loop) ..." && sleep 1
    done
    ANNOUNCE_IP{{ $i }}=$(getent hosts "rfr-{{ $fullName }}-node-{{ $i }}.rfr-{{ $fullName }}-node.{{$root.Release.Namespace}}.svc.{{ $root.Values.haproxy.clusterDomain }}" | awk '{ print $1 }')
    if [ -z "$ANNOUNCE_IP{{ $i }}" ]; then
      echo "Could not resolve the announce ip for rfr-{{ $fullName }}-node-{{ $i }}"
      exit 1
    fi
    sed -i "s/REPLACE_ANNOUNCE{{ $i }}/$ANNOUNCE_IP{{ $i }}/" "$HAPROXY_CONF"
    
    cat /data/haproxy.cfg
    {{- end }}
{{- end }}