# RedisOperator-haproxy-failover

Failover redis-sentinel switch.
Works in conjunction with the redis-operator project.

There are two failover enabled in this operator. Disable the unnecessary one.

1. haproxy-based
```
haproxy:
  enabled: true
```
`
master connection point {{project-name}}-ha:6379
`

haproxy can be used for small projects with low load and where there is no requirement to always hold the connection to redis

2. Based on a bash script failover.sh 
```
failover:
  enabled: true
```
`
master connection point {{project-name}}-headless:6379
`

The failover.sh solution is designed for heavy workloads. Since there is a direct connection to the service that does not have an IP but looks at the endpoint to which the IP master POD is assigned

1. First, you need to install https://github.com/spotahome/redis-operator
2. Study values.yaml for your cluster conditions.
3. Then we install this project.


The idea is not new, the logic of work is borrowed from patroni-operator 
