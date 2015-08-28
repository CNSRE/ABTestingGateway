local modulename = "abtestingInit"
local _M = {}

_M._VERSION = '0.0.1'

_M.redisConf = {
    ["uds"]      = ngx.var.redis_uds   ,
    ["host"]     = ngx.var.redis_host,
    ["port"]     = ngx.var.redis_port,
    ["poolsize"] = ngx.var.redis_pool_size,
    ["idletime"] = ngx.var.redis_keepalive_timeout , 
    ["timeout"]  = ngx.var.redis_connect_timeout,
    ["dbid"]     = ngx.var.redis_dbid,
}

_M.divtypes = {
    ["iprange"]     = 'ipParser',  
    ["uidrange"]    = 'uidParser',
    ["uidsuffix"]   = 'uidParser',
    ["uidappoint"]  = 'uidParser',
    ["arg_city"]    = 'cityParser'
}

_M.prefixConf = {
    ["policyLibPrefix"]     = ngx.var.policy_prefix,
    ["runtimeInfoPrefix"]   = ngx.var.runtime_prefix,
    ["domainname"]          = ngx.var.server_name,
}

_M.divConf = {
    ["default_backend"]     = ngx.var.default_backend;
    ["shdict_expire"]       = ngx.var.shdict_expire;
}

_M.cacheConf = {
    ['timeout']             = ngx.var.lock_expire,
    ['runtimeInfoLock']     = ngx.var.rt_cache_lock,
    ['upstreamLock']        = ngx.var.up_cache_lock,
}

return _M
