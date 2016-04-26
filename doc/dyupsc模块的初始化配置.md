dyupsc模块的初始化相关配置
------------------------------

主要是在文件  dyupsc/utils/init.lua：　　　　

```nginx  
local _M = { 
    _VERSION = '0.01'
}


_M.redisConf = { 
    -- redis ip, using redis publish upstream operation command.
    ["redis_host"]            = '127.0.0.1',
    ["redis_port"]            = '6379',
}

_M.shareConf = { 
    -- cmd_share is save upstream operation command.
    ['cmd_share']             = 'dyupsc',
    -- cmd_internal is very $cmd_internal msec checker cmd_share and running upstream operation command.
    ['cmd_interval']          = 2000,
}

_M.lockConf = { 
    -- pull_lock is control one worker pull operation info.
    ['pull_lock']        = 'pull_lock',
    -- dump_lock is make one worker dump nginx conf very time.
    ['dump_lock']        = 'dump_lock',
}


_M.dumpConf = { 
    -- dump_path is dump runtime nginx upstream conf and save to $dump_path.
    ["dump_path"]        = '/etc/nginx/ups/upstream.conf',
}

_M.pullConf = { 
    -- topic_name is redis subscribe topic.
    ["topic_name"]         = 'dynamic_upstream_info',
    -- cluster_pull is on means support cluster else is off not support cluster manage upstream operation.
    ["cluster_pull"]       = 'off',
}

```

dyupsc模块配置注意：

* 1. `dump_path` 是nginx配置文件include的upstream.conf文件的路径，使/etc/nginx/ups和/etc/nginx/ups/upstream.conf的权限为777，保证nobody用户可读可写。
* 2. `cluster_pull`是个开关，目前使用redis的pub/sub机制做下发的，单机情况下设置为`off`表示关闭.

