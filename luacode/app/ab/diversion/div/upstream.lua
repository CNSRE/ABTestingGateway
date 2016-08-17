local config	= require('config.config').ab
local redis		= require('misc.redis')
local utils		= require('misc.utils')
local handler	= require('misc.handler').handler
local ERRORINFO	= require('misc.errcode').info
local lockmod	= require("misc.resty.lock")
local cjson		= require('cjson.safe')
local opts		= {timeout = 0.01}

local redis_conf = config.redisConf
local cache = ngx.shared[config.upstream_cache]

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

local getUserInfo = function(runtime)
    local userInfoModname = runtime[fields.userInfoModulename]
    local userInfoMod     = require(userInfoModname)
    local userInfo        = userInfoMod:get()
    return userInfo
end

local getUpstream = function(runtime, database, userInfo)
    local divModname = runtime[fields.divModulename]
    local policy     = runtime[fields.divDataKey]
    local divMod     = require(divModname)
    local divModule  = divMod:new(database, policy)
    local upstream   = divModule:getUpstream(userInfo) 
    return upstream
end

----------------------diversion runtime module------------------------

local _M = {}

local mt = {__index = _M}

_M.new = function(self, hostname)
	self.hostname = hostname
	self.mutex = hostname .. ':upstream'
	self.lock = lockmod:new(config.mutex, opts)
	self.cache = ngx.shared[config.upstream_cache]

	return setmetatable(self, mt)
end

_M.get = function(self, divsteps, runtimegroup)

	local hostname = self.hostname
	local cache = self.cache

    local usertable = {}
    for i = 1, divsteps do
        local idx = indices[i]
        local runtime = runtimegroup[idx]
        local info = getUserInfo(runtime)

        if info and info ~= '' then
            usertable[idx] = info
        end
    end

	ngx.log(ngx.INFO, 'userinfo\t', cjson.encode(usertable))

	local upstable = {}
	for i = 1, divsteps do
	    local idx   = indices[i]
	    local info  = usertable[idx]
		if info ~= nil then
			local userinfo = hostname .. ':' .. info
			local upstream = cache:get(userinfo)
			upstable[idx] = upstream
		end
	end

	ngx.log(ngx.INFO, 'first fetch: upstable in cache\t', cjson.encode(upstable))

    for i = 1, divsteps do
        local idx = indices[i]
        local ups = upstable[idx]
        if ups == -1 then
			if i == divsteps then
				local info = "usertable has no upstream in cache 1, proxypass to default upstream"
				ngx.log(ngx.INFO, info)
				return nil
			end
            -- continue
        elseif ups == nil then
            break

			-- 为什么break，举例子,用户请求 
			-- location /div -H 'X-Log-Uid:39' -H 'X-Real-IP:192.168.1.1'
			-- 分流后缓存中 39->-1, 192.168.1.1-> beta2
			-- 下一请求：
			-- location /div?city=BJ -H 'X-Log-Uid:39' -H 'X-Real-IP:192.168.1.1'
			-- 该请求应该是  39-> -1, BJ->beta1, 192.168.1.1->beta2，
			-- 然而cache中是 39->-1, 192.168.1.1->beta2，
			-- 如果此分支不break的话，将会分流到beta2上，这是错误的。
        else
			local info = "get upstream ["..ups.."] according to ["
							..idx.."] userinfo ["..usertable[idx].."] in cache 1"
			ngx.log(ngx.INFO, info)
            return ups
        end
    end

	local lock = self.lock
	local ok, err = lock:lock(self.mutex)
	if not ok then
		-- just wait for 0.01s
	end

    for i = 1, divsteps do
        local idx = indices[i]
        local ups = upstable[idx]
        if ups == -1 then
			if i == divsteps then
				local info = "usertable has no upstream in cache 2, proxypass to default upstream"
				ngx.log(ngx.INFO, info)
				lock:unlock()
				return nil
			end
        elseif ups == nil then
            break
        else
			local info = "get upstream ["..ups.."] according to ["
							..idx.."] userinfo ["..usertable[idx].."] in cache 2"
			ngx.log(ngx.INFO, info)
			lock:unlock()
            return ups
        end
    end

	local db, err = redis:getClient(redis_conf)
	if not db then
		ngx.log(ngx.ERR, '[ab] ', 'Redis Caution ', 'connect error for ', err)
		lock:unlock()
		return 
	end

	for i = 1, divsteps do
		local idx = indices[i]
		local runtime = runtimegroup[idx]
		local userinfo = usertable[idx]

		if userinfo then
			local info = hostname .. ':' .. userinfo

			local upstream = getUpstream(runtime, db, userinfo)
			if not upstream then
				self.cache:set(info, -1, config.cache.expire)
				ngx.log(ngx.INFO, 'fetch userinfo [', info, '] from db, get [nil]')
			else
				self.cache:set(info, upstream, config.cache.expire)
				lock:unlock()

				ngx.log(ngx.INFO, 'fetch userinfo [', userinfo, '] from db, get [', upstream, ']')
				ngx.log(ngx.ERR, "get upstream ["..upstream.."] according to ["	..idx.."] userinfo ["..usertable[idx].."] in db")
				return upstream
			end
		end
	end

	return nil

end

return _M
