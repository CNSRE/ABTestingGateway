nginx.conf的配置过程
===========================

dygateway主要基于ngx_lua开发，需要在nginx配置文件中做大量配置，以配合lua代码实现功能，因此nginx.conf中的配置相当多。首先介绍下配置文件的结构：

dygateway配置文件结构示意
-------------------------

* nginx.conf: 总nginx配置文件

```bash
    http {
        1. 设置lua路径相关
        2. lua code相关配置
        3. nginx的一些通用配置

        include "upstream.conf";
        include "default.conf";
        include "s1.conf";
        include "s2.conf";
    }
```

* default.conf：dygateway的管理相关配置

```bash
    server {
            # ab管理接口            
            location ab_admin {
            
            }

            # dynamic upstream管理接口
            location dyupsc_admin {
            
            }
    }
```

* virtual server conf：单个virtual host配置

```bash
    #s1.conf：virtual host配置

    # 设置ngx_lua级别的cache

    lua_shared_dict abc_sysConfig 1m;
    lua_shared_dict kv_abc_upstream 100m;

    server {

        # 分流接口 /abc
        location /abc {
            set $hostkey        api.weibo.cn.abc;
            set $sysConfig      abc_sysConfig;
            set $kv_upstream    kv_abc_upstream;

            set $backend    'default_upstream'';
            rewrite_by_lua_file "luacode/ab/diversion.lua";
            proxy_pass http://$backend;
        }
    }
```

nginx配置过程
---------------------------------

* ***Step*** 1.  在nginx.conf中，http配置块里，添加如下配置。该配置在nginx全局有效。

```bash
#打开lua的代码缓存
lua_code_cache on;

#lua代码的路径
lua_package_path "/usr/local/dygateway/luacode/ab/?.lua;/usr/local/dygateway/luacode/ab/lib/?.lua;/usr/local/dygateway/luacode/ab/lib/lua-resty-core/lib/?.lua;/usr/local/dygateway/luacode/dyupsc/?.lua;;";

#ngx_lua获取post数据配置
lua_need_request_body on;

#dyupsc所需的配置
lua_shared_dict dyupsc 5m;
lua_shared_dict pull_lock 1m;
lua_shared_dict dump_lock 1m;
init_worker_by_lua_file '/usr/local/dygateway/luacode/init//init_process_timer.lua';

# dygateway的upstream配置文件，这个路径非常重要，dyups将nginx的upstream情况dump到这个文件中。
include /etc/nginx/ups/upstream.conf;
```
* 注：
    * 关于 /etc/nginx/ups/upstream.conf，该文件和所在目录的权限因为777，使得nobody用户可读可写!!!

    ```lua
    -- 在dyups的lua代码中，dygateway/luacode/dyupsc/utils/init.lua中
    
    _M.dumpConf = { 
        -- dump_path is dump runtime nginx upstream conf and save to $dump_path.
        ["dump_path"]        = '/etc/nginx/ups/upstream.conf',
    }
    
    -- dump_path 要与nginx.conf中一致
    ```

* ***Step*** 2.  在管理server的server配置块内添加：

```bash
# ab管理功能需要读写redis数据库，所以需要配置
set $redis_host '127.0.0.1';		--本机redis的IP
set $redis_port '6379';			--本机redis的port
set $redis_uds '/tmp/redis.sock';	--本机redis的uds设置，优先使用uds
set $redis_connect_timeout 10000;      --设置连接超时时间	
set $redis_dbid 0;                     --设置选择redis db0作为存储库

set $redis_pool_size 1000;		--lua-resty-redis的连接池大小
set $redis_keepalive_timeout 90000;    --(连接池keepalive_time, in ms)	

# ab管理功能配置
location = /ab_admin {
    content_by_lua_file '/usr/local/dygateway/luacode/ab/admin/ab_action.lua';
}

# 模块要求需要有这个配置，虽然不美观，但是需要加上
location /fake_location{
    dyups_interface;
}

# dyups管理功能配置
location = /dyupsc_admin {
    content_by_lua_file '/usr/local/dygateway/luacode/dyupsc/admin/dyupstream_action.lua';
}

```

* ***Step*** 3. virtual host s1.conf配置

```bash

# location / 的 运行时信息缓存
lua_shared_dict root_sysConfig 1m;
# location / 的 info:upstream 缓存
lua_shared_dict kv_root_upstream 100m;


# location /abc 的 运行时信息缓存
lua_shared_dict abc_sysConfig 1m;
# location /abc 的 info:upstream 缓存
lua_shared_dict kv_abc_upstream 100m;

server {
    listen 8030 backlog=16384;
    server_name api.weibo.cn;

    set $redis_host '127.0.0.1';
    set $redis_port '6379';
    set $redis_uds '/tmp/redis.sock';
    set $redis_connect_timeout 10000;
    set $redis_dbid 0;
    set $redis_pool_size 1000;
    set $redis_keepalive_timeout 90000;     #(keepalive_time, in ms)

    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Connection "";
    proxy_http_version 1.1;


    location / {
        # 指定该接口的HOST，用于配置运行时信息：api.weibo.cn，（可任意取名，只要进入本loction，运行时信息以此值为key，为本location设置运行时信息时，也以此值为key，需要约定好）
        set $hostkey $server_name;

        # 指定sysConfig的名字，与 缓存名字 root_sysConfig 一样(可任意取名，不要与别的lua_shared_dict冲突即可，但要与之前声明的shared_dict名字一样:root_sysConfig)
        set $sysConfig root_sysConfig;
        # 指定kv_upstream 的名字 与 缓存名字 kv_root_upstream 一样
        set $kv_upstream kv_root_upstream;
        
        # 设置默认upstream（该upstrema必须存在于upstream.conf，并且应该考虑到大部分请求将分流至默认upstream）
        set $backend 'stable';

        rewrite_by_lua_file '/usr/local/dygateway/luacode/ab/diversion/diversion.lua';

        # http后跟着的必须是一个变量，以$开头的变量。否则dyups功能失效
        proxy_pass http://$backend;
    }
 
    location /abc {

        # 指定该接口的HOST，用于配置运行时信息：api.weibo.cn.abc
        set $hostkey $server_name.abc;

        set $sysConfig abc_sysConfig;
        set $kv_upstream kv_abc_upstream;
        
        set $backend 'stable';

        rewrite_by_lua_file '/usr/local/dygateway/luacode/ab/diversion/diversion.lua';
        proxy_pass http://$backend;
    }
}

```
* ***Step*** 4. upstream.conf配置

```bash
    #必须要有默认upstream

    upstream stable {
        server 1
        server 2
        ...
    }

    #以及其他upstream
    upstream bar {
    
    }

    upstream foo {
    
    }
```


