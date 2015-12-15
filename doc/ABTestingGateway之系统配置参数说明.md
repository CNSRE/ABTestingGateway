目前灰度系统的配置参数主要包括：

	1. 管理和分流功能的相关配置
	2. redis数据库读写配置

在repo中的**utils/conf/nginx.conf**文件是一个灰度系统的最小配置。
```python
worker_processes auto;

pid   logs/nginx-uid.pid;
error_log logs/error.log ;

events {
	worker_connections  32768;
	accept_mutex off;
	multi_accept on;
}

http {
	include       mime.types;

	log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
		'$status $body_bytes_sent "$http_referer" '
		'"$http_user_agent" "$http_x_forwarded_for"'
		' $request_time $upstream_response_time';
	access_log logs/access.log main;

	sendfile        on;

#        keepalive_timeout  0;
#        keepalive_requests 0;

	upstream stable{
		keepalive 1000;
		server localhost:8040;
	}

	upstream beta1 {
		keepalive 1000;
		server localhost:8020;
	}

	upstream beta2 {
		keepalive 1000;
		server localhost:8021;
	}

	upstream beta3 {
		keepalive 1000;
		server 127.1.0.1:8022;

#		check interval=3000 rise=2 fall=5 timeout=1000 type=http;
#		check_http_send "HEAD / HTTP/1.0\r\n\r\n";
#		check_http_expect_alive http_2xx http_3xx;
	}

	upstream beta4 {
		keepalive 1000;
		server localhost:8023;
	}

	lua_code_cache off;
	lua_package_path "../lib/?.lua;;";
	lua_shared_dict sysConfig 1m;
	lua_shared_dict kv_upstream 10m;
	lua_shared_dict rt_locks 100k;
	lua_shared_dict up_locks 100k;

	lua_need_request_body on;

	server {
		server_name localhost;
		listen 8030 backlog=16384;

		set $redis_host '127.0.0.1';
		set $redis_port '6379';
		set $redis_uds '/tmp/redis.sock';
		set $redis_connect_timeout 10000;
		set $redis_dbid 0;

		set $redis_pool_size 1000;
		set $redis_keepalive_timeout 90000;     #(keepalive_time, in ms)

		set $runtime_prefix 'ab:test:runtimeInfo';
		set $policy_prefix  'ab:test:policies';

		set $default_backend 'stable';
		set $shdict_expire 60;

		set $rt_cache_lock rt_locks;    #set name of cache locks, should be same as lua_shared_dict
		set $up_cache_lock up_locks;
		set $lock_expire 0.001 ;	#wait for cache_lock 0.001 seconds

		location / {
			proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
			proxy_set_header Host $http_host;
			proxy_set_header X-Real-IP $remote_addr;
			proxy_set_header Connection "";
			proxy_http_version 1.1;

			set $backend $default_backend;
			rewrite_by_lua_file '../diversion/diversion.lua';

			proxy_pass http://$backend;
		}
		location = /admin/policy/set {
			content_by_lua_file '../admin/policy/set.lua'; 
		}
		location = /admin/policy/get {
			content_by_lua_file '../admin/policy/get.lua'; 
		}
		location = /admin/policy/del {
			content_by_lua_file '../admin/policy/del.lua'; 
		}
		location = /admin/policy/check {
			content_by_lua_file '../admin/policy/check.lua'; 
		}

		location = /admin/runtime/set {
			content_by_lua_file '../admin/runtime/set.lua'; 
		}
		location = /admin/runtime/get {
			content_by_lua_file '../admin/runtime/get.lua'; 
		}
		location = /admin/runtime/del {
			content_by_lua_file '../admin/runtime/del.lua'; 
		}

		location /nginx_status {
			stub_status on;
			access_log   off;
			allow 127.0.0.1;
			deny all;
		}

		location /status {
			check_status;

			access_log off;
			allow 127.0.0.1;
			deny all;
		}   
   }
}
```

####主机名 server_name 配置

主机名十分重要，一来是7层服务器的主机名，二来是灰度系统的运行时策略库前缀。
server_name可以配置多个，灰度系统将取用第一个作为运行时信息前缀。

```bash
	server_name localhost
```

####灰度系统的 redis 读写相关配置
```bash
	set $redis_host '127.0.0.1';		--本机redis的IP
	set $redis_port '6379';			--本机redis的port
	set $redis_uds '/tmp/redis.sock';	--本机redis的uds设置，优先使用uds
	set $redis_connect_timeout 10000;	
	set $redis_dbid 0;

	set $redis_pool_size 1000;		--lua-resty-redis的连接池大小
	set $redis_keepalive_timeout 90000; --(连接池keepalive_time, in ms)	
```
####灰度系统的 策略和运行时信息 相关
灰度系统的 运行时信息 和 策略库 的前缀，在redis数据库中的key名前缀。

```bash
	set $runtime_prefix 'ab:test:runtimeInfo';
	set $policy_prefix 	 'ab:test:policies';
```
####灰度系统的 默认upstream配置
```bash
	set $default_backend 'http://stable';
	set $backend $default_backend;
	rewrite_by_lua_file '../diversion/diversion.lua';

	proxy_pass http://$backend;	
```
####灰度系统的 系统缓存 配置
```bash
	lua_shared_dict sysConfig 1m;		--运行时信息的kv缓存	
	lua_shared_dict rt_locks 100k;		--缓存锁

	lua_shared_dict kv_upstream 10m;	--用户请求与目标upstream的kv缓存
	lua_shared_dict up_locks 100k;		--缓存锁

	set $shdict_expire 60;				--缓存失效时间
```

####灰度系统的 系统缓存锁 配置

缓存锁配置。缓存锁的的本质是一个shared-dict，就是在**系统缓存 配置**中的rt_locks和up_locks。
在这里改名，是想给系统提供一个不变的缓存锁名字。
```bash
	set $rt_cache_lock rt_locks;   
	set $up_cache_lock up_locks;
```
缓存锁死锁时间

```bash
	set $cache_expire 0.001 ;
```		