# RedisOperator-haproxy-failover

Failover redis-sentinel switch.
Works in conjunction with the redis-operator project.

1. First, you need to install https://github.com/spotahome/redis-operator
2. Study values.yaml for your cluster conditions.
3. Then we install this project.
4. You will have the {{project name}}-headless service. All applications need to be configured for it. This service has an endpoint-headless, the ip address of which is changed by the {{project name}}-failover operator

The idea is not new, the logic of work is borrowed from patroni-operator 
