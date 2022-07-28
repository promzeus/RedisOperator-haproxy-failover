#!/bin/bash

function getMasterIP() {
    # echo "get sentinel master ip"
    MASTER_IP=$(echo "SENTINEL get-master-addr-by-name {{.Values.sentinel.masterSet }}" |nc rfs-{{ .Release.Name }}-node 26379 |grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' |sed "s/$(printf '\r')\$//")
}

function getKubeEndpointIP() {
    # echo "get kube endpoint ip"
    KUBE_IP=$(kubectl get ep/{{ .Release.Name }}-headless -ojsonpath="{.subsets..addresses..ip}")
}

function setKubeEndpointIP() {
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Endpoints
metadata:
  name: {{ .Release.Name }}-headless
  labels:
    k8s-app: {{ .Release.Name }}-headless
subsets:
- addresses:
  - ip: "$MASTER_IP"
  ports:
  - name: {{ .Release.Name }}-headless
    port: 6379
    protocol: TCP
EOF
}

while :
do

DATE=$(date +"%Y-%m-%d %H:%M:%S")

getMasterIP
getKubeEndpointIP

if [ -z $MASTER_IP ]; then
        echo "$DATE sentinel master ip is empty, sleep 10s"
        echo MasterIP: $MASTER_IP
    else
        # echo "$DATE sentinel master ip is not empty, run check kube endpoint ip"
    if [ -z $KUBE_IP ]; then
            echo "$DATE kube endpoint ip is empty, sleep 10s"
            echo KubeEndpointIP: $KUBE_IP
        else
            # echo "$DATE kube endpoint ip is not empty, run check master ip == kube ip"
            if [ "$MASTER_IP" == "$KUBE_IP" ]; then
                echo "$DATE  Nothing to change. Sentinel master ip:$MASTER_IP is equal to kube endpoint ip:$KUBE_IP, sleep 10s"
            else
                echo "$DATE sentinel master ip is not equal to kube endpoint ip"
                echo "$DATE Run set $MASTER_IP to kube epoint"
                setKubeEndpointIP
                echo MasterIP: ${MASTER_IP}
                echo KubeEndpointIP: ${KUBE_IP}
        fi
    fi
fi

sleep 10

done