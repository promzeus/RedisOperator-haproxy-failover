# RedisOperator-haproxy-failover

Обязательно в кластер устанавливаем RedisOperator https://github.com/spotahome/redis-operator
```
kubectl create -f https://raw.githubusercontent.com/spotahome/redis-operator/master/example/operator/all-redis-operator-resources.yaml
или
helm install --name redisfailover charts/redisoperator
```

**Важно**
В текущем чарте, смотрите внимательно блок в values.yaml
```
clusterDomain: cluster.local
# if use resolver kubernetes change ip
resolvers: "169.254.25.10:53"
```
Отредактируйте под ваши условия локальный DNS и IP-порт Kubernetes localdns обычно это CoreDNS в kubespray
Это нужно для того, что-бы haproxy постоянно резолвил имена а не только при старте. Иначе после того как пересоздастся под у него сменится IP и Haproxy об этом не узнает!

подклчаться к {{.Release.Name}}-ha
master-port: 6379
slave-port: 6380