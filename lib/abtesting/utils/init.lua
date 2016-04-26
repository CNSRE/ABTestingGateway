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
    ["arg_city"]    = 'cityParser',

    ["url"]         = 'urlParser'
}   

_M.prefixConf = {
    ["policyLibPrefix"]     = 'ab:policies',
    ["policyGroupPrefix"]   = 'ab:policygroups',
    ["runtimeInfoPrefix"]   = 'ab:runtimeInfo',
    ["domainname"]          = ngx.var.domain_name,
}

_M.divConf = {
    ["default_backend"]     = ngx.var.default_backend,
    ["shdict_expire"]       = 60,   -- in s
--    ["shdict_expire"]       = ngx.var.shdict_expire,
}

_M.cacheConf = {
    ['timeout']             = ngx.var.lock_expire,
    ['runtimeInfoLock']     = ngx.var.rt_cache_lock,
    ['upstreamLock']        = ngx.var.up_cache_lock,
}

_M.indices = {
    'first', 'second', 'third',
    'forth', 'fifth', 'sixth', 
    'seventh', 'eighth', 'ninth'
}

_M.fields = {
    ['divModulename']       = 'divModulename',           
    ['divDataKey']          = 'divDataKey',
    ['userInfoModulename']  = 'userInfoModulename',
    ['divtype']             = 'divtype',
    ['divdata']             = 'divdata',
    ['idCount']             = 'idCount',
    ['divsteps']            = 'divsteps'
}

_M.loglv = {

    ['err']					= ngx.ERR, 
	['info']				= ngx.INFO,           ['warn']				  = ngx.WARN,      
    ['debug']				= ngx.DEBUG,           
}

return _M
