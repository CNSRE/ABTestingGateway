* redis的ip&port配置要与nginx.conf中一致，同时补充几点redis的优化配置


```bash
port 6379
unixsocket /tmp/redis.sock
unixsocketperm 766

timeout 0
tcp-keepalive 120
tcp-backlog 20000

maxclients 262144
```

