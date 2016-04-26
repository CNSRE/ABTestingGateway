dygateway系统的配置参数主要包括

* 0.系统配置
* 1.ab灰度系统部分的配置参数
* 2.dyupsc动态upstream部分的配置参数
* 3.redis数据库读写配置

如下是repo中自带的一个nginx.conf demo。
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
		server localhost:8021;
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

	lua_code_cache on;
	lua_package_path "/usr/local/dygateway/luacode/ab/?.lua;/usr/local/dygateway/luacode/ab/lib/?.lua;/usr/local/dygateway/luacode/dyupsc/?.lua;;";
	lua_shared_dict sysConfig 1m;
	lua_shared_dict kv_upstream 10m;
	lua_shared_dict rt_locks 100k;
	lua_shared_dict up_locks 100k;

	lua_need_request_body on;

        # the size depends on the number of servers in upstream {}:
        lua_shared_dict dyupsc 1m;

        init_worker_by_lua_file '/usr/local/dygateway/luacode/dyupsc/admin/init_process_timer.lua';

	server {
		server_name localhost;
		listen 8030 backlog=16384;

		set $domain_name localhost;
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
			rewrite_by_lua_file '/usr/local/dygateway/luacode/ab/diversion/diversion.lua';

			proxy_pass http://$backend;

		}
                location /fake_location{
                
                        dyups_interface;
                }

                location = /ab_admin {
                    content_by_lua_file '/usr/local/dygateway/luacode/ab/admin/ab_action.lua';
                    
                }

                location = /dyupsc_admin {
                    content_by_lua_file '/usr/local/dygateway/luacode/dyupsc/admin/action.lua';
                }

		location /nginx_status {
			stub_status on;
			access_log   off;
			allow 127.0.0.1;
			deny all;
		}

#		location /status {
#			check_status;
#
#			access_log off;
#			allow 127.0.0.1;
#			deny all;
#		}   
   }
}


```

系统配置
=============
系统内部的代码依赖采用相对路径方式，而系统对nginx的依赖采用绝对路径方式。
因此在配置文件指定接口代码时采用绝对路径，比如当dygateway安装在/usr/local/目录下时，所有lua代码都在/usr/local/dygateway/luacode/文件夹下。比如绝对路径为：
```python
    init_worker_by_lua_file '/usr/local/dygateway/luacode/dyupsc/admin/init_process_timer.lua';

	location / {

		rewrite_by_lua_file '/usr/local/dygateway/luacode/ab/diversion/diversion.lua';
		proxy_pass http://$backend;
	}

    location = /ab_admin {
        content_by_lua_file '/usr/local/dygateway/luacode/ab/admin/ab_action.lua';                    
    }
    
    location = /dyupsc_admin {
        content_by_lua_file '/usr/local/dygateway/luacode/dyupsc/admin/action.lua';
    }
```
系统的内部依赖，只要正确指定了lualib path就可以
```python
	lua_package_path "/usr/local/dygateway/luacode/ab/?.lua;/usr/local/dygateway/luacode/ab/lib/?.lua;/usr/local/dygateway/luacode/dyupsc/?.lua;;";
```
如果相对lua 代码路径有所调整的话，需要修改这些路径依赖。

ab 灰度系统的配置参数
================
####ab 灰度系统的 domain_name 配置

domain_name十分重要，它是灰度系统的运行时策略前缀，如果为空或者与下发策略不一样，会导致系统找不到运行时信息，影响灰度策略的管理和分流功能。

```bash
	set domain_name localhost;
```

####ab 灰度系统的 redis 读写相关配置
```bash
	set $redis_host '127.0.0.1';		--本机redis的IP
	set $redis_port '6379';			--本机redis的port
	set $redis_uds '/tmp/redis.sock';	--本机redis的uds设置，优先使用uds
	set $redis_connect_timeout 10000;	
	set $redis_dbid 0;

	set $redis_pool_size 1000;		--lua-resty-redis的连接池大小
	set $redis_keepalive_timeout 90000; --(连接池keepalive_time, in ms)	
```
####ab 灰度系统的 策略和运行时信息 相关
灰度系统的 运行时信息 和 策略库 的前缀，在redis数据库中的key名前缀。采用统一的名称就好，在策略管理下发时，所有部署灰度系统都采用同一前缀的key。

```bash
	set $runtime_prefix 'ab:test:runtimeInfo';
	set $policy_prefix 	 'ab:test:policies';
```
####ab 灰度系统的 默认upstream配置
当做ab测试或者灰度时，大部分用户请求都是打向默认upstream的。另外，当分流功能出现错误，获取不到目标upstream时，也会转向默认upstream。
```bash
	set $default_backend 'stable';
	

	rewrite_by_lua_file '../diversion/diversion.lua';
	proxy_pass http://$backend;	
```
####ab 灰度系统的 系统缓存 和 缓存锁 配置
缓存的名字就是这个，lua代码里也是它。缓存kv_upstream的大小可以适当增大，避免抖动，缓存时间60s。缓存锁的的本质是一个shared-dict，就是在**系统缓存 配置**中的rt_locks和up_locks。
在这里改名，是想给系统提供一个不变的缓存锁名字，因此这部分配置名字要对应起来。
```bash
	lua_shared_dict sysConfig 1m;		--运行时信息的kv缓存	
	lua_shared_dict rt_locks 100k;		--缓存锁

	lua_shared_dict kv_upstream 10m;	--用户请求与目标upstream的kv缓存
	lua_shared_dict up_locks 100k;		--缓存锁

	set $shdict_expire 60;				--缓存失效时间


	set $rt_cache_lock rt_locks;   
	set $up_cache_lock up_locks;

	set $cache_expire 0.001 ;	--缓存锁死锁时间设置为1ms
```		

dyupsc动态upstream配置参数
====================
####动态upstream的 初始化 配置
```python
    lua_shared_dict dyupsc 1m;
    
    init_worker_by_lua_file '/usr/local/dygateway/luacode/dyupsc/admin/init_process_timer.lua';
```
####动态upstream的 接口配置

```python
    location /fake_location{
    
            dyups_interface;
    }
    
    location = /dyupsc_admin {
        content_by_lua_file '/usr/local/dygateway/luacode/dyupsc/admin/action.lua';
    }
```
