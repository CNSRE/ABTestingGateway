local modulename = "abtestingInit"
local _M = {}
_M._VERSION = '0.0.1'

-------------------manual config ---------------

local waf_admin_redis_host	= 'x.x.x.x'-- waf管理机的主库redis地址，默认'127.0.0.1'
local waf_admin_redis_port	= 6379			-- waf管理机的主库redis端口，默认6379
local waf_admin_clean_cycle	= 1800			-- waf管理机定期清除旧数据，默认1800s，半个小时
local waf_admin_clean_ipstat= 86400			-- waf管理机定期保持ip被封禁时段，保持一天

local waf_front_redis_host	= 'x.x.x.x'-- waf前端机的从库redis地址，默认'127.0.0.1'
local waf_front_redis_port	= 16379			-- waf前端机的从库redis端口，默认6379
local waf_front_banip_cycle		= 5			-- waf前端机从redis轮询封禁ip，默认5s一次
local waf_front_whiteip_cycle	= 30		-- waf前端机从redis轮询白名单ip，默认30s一次

local waf_upload_redis_host	= 'x.x.x.x'-- waf前端机的上报统计数据的redis地址，默认'127.0.0.1'
local waf_upload_redis_port	= 6379			-- waf前端机的上报统计数据的redis端口，默认6379
local waf_front_upload_cycle = 30			

local waf_shdict_banip		= 'banset'		-- waf前端机用于缓存封禁ip的nginx缓存，要求与nginx配置文件中的 lua_shared_dict [banset] 512m; 同名
local waf_shdict_stat		= 'banset'		-- waf前端机用于统计封禁次数的nginx缓存，目前将它与封禁ip缓存在一起
local waf_shdict_whitelist	= 'whitelist'	-- waf前端机用于缓存白名单ip的nginx缓存，预计有百万之多；与 lua_shared_dict [whitelist] 512m; 同名
local waf_shdict_banmutex	= 'banmutex'	-- waf前端机用于同步互斥锁的nginx缓存，与 lua_shared_dict [banmutex] 10m; 同名

-------------------config waf ---------------

local waf = {

	banlist				= 'banlist',		-- redis key	
	unbanlist			= 'unbanlist',		-- redis key
	baklist				= 'baklist',		-- redis key
	whitelist			= 'whitelist',		-- redis key	
	unwhitelist			= 'unwhitelist',	-- redis key	
	bakwhitelist		= 'bakwhitelist',	-- redis key	
	total_baned			= 'total_baned', 	-- redis key & shdict key
	current_ban			= 'cur_banlist',	-- redis key	

	shdict_banip		= waf_shdict_banip,
	shdict_stat			= waf_shdict_stat,
	shdict_whitelist	= waf_shdict_whitelist,
	banmutex			= waf_shdict_banmutex,

	loop_interval		= waf_front_banip_cycle		or 5,
	upload_interval		= waf_front_upload_cycle	or 30,
	whitelist_interval	= waf_front_whiteip_cycle	or 30,
	clean_interval		= waf_admin_clean_cycle		or 1800,
	ipstat_expire		= waf_admin_clean_ipstat	or 86400,
}

waf.admin_mode = waf_admin_mode

waf.mutex = {
	m_init_worker	= 'init_worker',
	m_update_ban	= 'upban'	,
	m_upload		= 'upload',
	m_whitelist		= 'whitelist',
	m_admin_clean	= 'admin_clean' ,
}

waf.redis_upload = {
	["host"]     = waf_upload_redis_host or '127.0.0.1',
	["port"]     = waf_upload_redis_port or 6379,
	["poolsize"] = 100,
	["idletime"] = 90000,
	["timeout"]  = 10000,
	["dbid"]     = 0
}

waf.redis_admin = {
	["host"]     = waf_admin_redis_host or '127.0.0.1',
	["port"]     = waf_admin_redis_port or 6379,
	["poolsize"] = 100,
	["idletime"] = 90000,
	["timeout"]  = 10000,
	["dbid"]     = 0
}

waf.redis_conf = {
	["host"]     = waf_front_redis_host or '127.0.0.1',
	["port"]     = waf_front_redis_port or 6379,
	["poolsize"] = 100,
	["idletime"] = 90000,
	["timeout"]  = 10000,
	["dbid"]     = 0
}

waf.loglv = {
	lv0 = ngx.CRIT,
	lv1 = ngx.ERR,		-- 错误
	lv2 = ngx.WARN,		-- 拦截结果
	lv3 = ngx.NOTICE,	-- 一般性通告：更新ip、更新白名单等
}

_M.waf = waf

-------------------manual config ---------------

local ab_cache_expire	= 60				-- ab的缓存时间，默认60s
local ab_redis_host		= '127.0.0.1'		-- ab_redis的ip，默认127.0.0.1
local ab_redis_port		= 6379				-- ab_redis的port，默认6379

local ab_mutex = 'ab_mutex'
local ab_runtime_cache = 'ab_runtime'
local ab_upstream_cache = 'ab_upstream'

-------------------config abtest ---------------
local ab = {}

ab.mutex = ab_mutex
ab.runtime_cache = ab_runtime_cache
ab.upstream_cache = ab_upstream_cache

ab.redisConf = {
	["uds"]      = '/tmp/redis.conf',
	["host"]     = ab_redis_host or '127.0.0.1',
	["port"]     = ab_redis_port or 6379,
	["poolsize"] = 500,
	["idletime"] = 90000,
	["timeout"]  = 10000,
	["dbid"]     = 0
}

ab.divtypes = {
    ["iprange"]     = 'ipParser',  
    ["uidrange"]    = 'uidParser',
    ["uidsuffix"]   = 'uidParser',
    ["uidappoint"]  = 'uidParser',
    ["arg_city"]    = 'cityParser',

    ["url"]         = 'urlParser',
	["arg_uid"]		= 'toutiaoUIDParser'
}   

ab.prefixConf = {
    ["policyLibPrefix"]		= 'ab:policies',
    ["policyGroupPrefix"]	= 'ab:policygroups',
    ["runtimeInfoPrefix"]	= 'ab:runtime',
    ["actionLibPrefix"]		= 'ab:actions',
    ["actionRuntimePrefix"]	= 'ab:runtime:action',
}

ab.prefix = {
    ["runtime"]	= 'ab:runtime',
}

ab.indices = {
    'first', 'second', 'third',
    'forth', 'fifth', 'sixth', 
    'seventh', 'eighth', 'ninth'
}

ab.cache = {
	expire = ab_cache_expire or 60,
}

ab.fields = {
    ['divModulename']       = 'divModulename',           
    ['divDataKey']          = 'divDataKey',
    ['userInfoModulename']  = 'userInfoModulename',
    ['acttype']             = 'acttype',
    ['actdata']             = 'actdata',

    ['divtype']             = 'divtype',
    ['divdata']             = 'divdata',
    ['idCount']             = 'idCount',
    ['divsteps']            = 'divsteps',
}

_M.ab = ab

return _M
