local config	= require('config.config').ab
local redis		= require('misc.redis')
local utils		= require('misc.utils')
local handler	= require('misc.handler').handler
local ERRORINFO	= require('misc.errcode').info
local lockmod	= require("misc.resty.lock")
local cjson		= require('cjson.safe')
local getHost	= utils.getHost

local opts		= {timeout = 0.01}
local redis_conf = config.redisConf

local cache = ngx.shared[config.runtime_cache]

local prefix = config.prefix.runtime
local indices = config.indices
local fields = config.fields 

local isNULL = function(v)
    return not v or v == ngx.null
end

local areNULL = function(v1, v2, v3)
    if isNULL(v1) or isNULL(v2) or isNULL(v3) then
        return true
    end
    return false 
end

local get_cache = function(cache, hostkey)

	local prefix = prefix .. ':' .. hostkey

	local k_step = prefix .. ':' .. fields.divsteps
	local divsteps = cache:get(k_step)
	divsteps = tonumber(divsteps)
	if not divsteps then return end

    local runtimegroup = {}
    for i = 1, divsteps do
        local idx = indices[i]
        local div_modkey	= prefix .. ':'..idx..':'..fields.divModulename
        local datakey		= prefix .. ':'..idx..':'..fields.divDataKey
        local info_modkey	= prefix .. ':'..idx..':'..fields.userInfoModulename

        local div_modname, err1	= cache:get(div_modkey)
        local div_datakey, err2	= cache:get(datakey)
        local info_modname,err3	= cache:get(info_modkey)

		if areNULL(div_modname, div_datakey, info_modname) then
            return false
        end

        local runtime = {}
        runtime[fields.divModulename  ] = div_modname
        runtime[fields.divDataKey     ] = div_datakey
        runtime[fields.userInfoModulename] = info_modname
        runtimegroup[idx] = runtime
    end

    return divsteps, runtimegroup
end

local set_cache = function(cache, hostkey, divsteps, runtimegroup)

	local prefix = prefix .. ':' .. hostkey
    local expire = config.cache.expire or 60

    for i = 1, divsteps do
        local idx = indices[i]

        local k_divModname      = prefix .. ':'..idx..':'..fields.divModulename
        local k_divDataKey      = prefix .. ':'..idx..':'..fields.divDataKey
        local k_userInfoModname = prefix .. ':'..idx..':'..fields.userInfoModulename

        local runtime = runtimegroup[idx]
        local ok1, err1 = cache:set(k_divModname, runtime[fields.divModulename], expire)
        local ok2, err2 = cache:set(k_divDataKey, runtime[fields.divDataKey], expire)
        local ok3, err3 = cache:set(k_userInfoModname, runtime[fields.userInfoModulename], expire)
        if areNULL(ok1, ok2, ok3) then 
			ngx.log(ngx.ERR, '[ab] ', 'Caution set shdict error for ', cjson.encode({err1, err2, err3}))
			return false 
		end

    end

    local k_divsteps = prefix ..':'..fields.divsteps
    local ok, err = cache:set(k_divsteps, divsteps, config.cache.expire)
    if not ok then 
		ngx.log(ngx.ERR, '[ab] ', 'Caution set shdict error for ', err)
		return false 
	end

    return true
end

local get_redis = function(database, hostname)
	local module	= require('abtesting.adapter.runtimegroup')
    local runtime	= module:new(database, prefix)
    return runtime:get(hostname)
end

----------------------diversion runtime module------------------------

local _M = {}

local mt = {__index = _M}

_M.new = function(self, hostname)
	self.hostname = hostname
	self.mutex = hostname .. ':runtime'
	self.lock = lockmod:new(config.mutex, opts)
	self.cache = ngx.shared[config.runtime_cache]

	return setmetatable(self, mt)
end

_M.get = function(self)

	local hostname = self.hostname
    --step 1: read frome cache
	local divsteps, runtimegroup = get_cache(self.cache, hostname)
	if divsteps == -1 then
		ngx.log(ngx.INFO, 'div swtich off')
		return			-- div switch off
	elseif divsteps then 
--		ngx.log(ngx.ERR, 'divstep = ', divsteps, '\truntimeinfo = ', cjson.encode(runtimeInfo))
		return divsteps, runtimegroup
	end
	ngx.log(ngx.ERR, 'fetch cache 1')

    --step 2: if step 1 fail, then acquire the lock
	local lock = self.lock
	local ok, err = lock:lock(self.mutex)
	if not ok then
		-- just wait for 0.01s
	end

	ngx.log(ngx.ERR, 'fetch cache 2')

    -- setp 3: read from cache again
	local divsteps, runtimegroup = get_cache(self.cache, hostname)
	if divsteps == -1 then
		ngx.log(ngx.ERR, 'div swtich off')
		lock:unlock()
		return			-- div switch off
	elseif divsteps then 
		ngx.log(ngx.ERR, 'divstep = ', divsteps, '\truntimeinfo = ', cjson.encode(runtimeInfo))
		lock:unlock()
		return divsteps, runtimegroup
	end

    -- step 4: fetch from redis
	local db, err = redis:getClient(redis_conf)
	if not db then
		ngx.log(ngx.ERR, '[ab] ', 'Redis Caution ', 'connect error for ', err)
		lock:unlock()
		return 
	end

    local runtimeInfo   = get_redis(db, hostname)
    local divsteps		= runtimeInfo.divsteps
    local runtimegroup	= runtimeInfo.runtimegroup

	ngx.log(ngx.ERR, 'divstep = ', divsteps, '\truntimeinfo = ', cjson.encode(runtimeInfo))
	set_cache(self.cache, hostname, divsteps, runtimegroup)
	lock:unlock()

	return divsteps, runtimegroup

end

return _M
