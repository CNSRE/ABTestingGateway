local runtimeModule = require('abtesting.adapter.runtime')
local redisModule   = require('abtesting.utils.redis')
local systemConf    = require('abtesting.utils.init')
local handler	    = require('abtesting.error.handler').handler
local ERRORINFO	    = require('abtesting.error.errcode').info
local cjson         = require('cjson.safe')
local utils         = require('abtesting.utils.utils')
local resty_lock    = require("resty.lock")

local redisConf	    = systemConf.redisConf
local prefixConf    = systemConf.prefixConf
local divConf       = systemConf.divConf
local cacheConf     = systemConf.cacheConf

local runtimeInfoLib    = prefixConf.runtimeInfoPrefix
local domainname        = prefixConf.domainname

local shdict_expire     = divConf.shdict_expire or 60
local default_backend   = divConf.default_backend

local cache_expire      = cacheConf.timeout or 0.001
local rt_cache_lock     = cacheConf.runtimeInfoLock

local dolog = utils.dolog	

local sysConfig	  = ngx.shared.sysConfig
local kv_upstream = ngx.shared.kv_upstream

local getRewriteInfo = function()
    return 'redirect to upstream http://'..ngx.var.backend
end

local doredirect = function() 
    local ok  = ERRORINFO.SUCCESS
    local err = 'redirect to upstream http://'..ngx.var.backend
    dolog(ok, err)
end

local isNULL = function(v)
    return not v or v == ngx.null
end

local areNULL = function(...)
    local t = {...}
    if not next(t) then
        return true
    end
    for k, v in pairs(t) do
        if isNULL(v) then
            return true
        end
    end
    return false 
end

local isSwitchOff = function(...)
    local t = {...}
    if not next(t) then
        return true
    end
    for k, v in pairs(t) do
        if v == -1 then
            return true
        end
    end
    return false
end

local red
local setKeepalive = function(red) 
    local ok, err = red:keepalivedb()  
    if not ok then
        local errinfo = ERRORINFO.REDIS_KEEPALIVE_ERROR
        local errdesc = err
        dolog(errinfo, errdesc)
        return
    end
end

--====================================================
--获取当前domain的运行时
--		分流模块名			divModulename
--		分流策略库名		divDataKey
--		用户特征提取模块名	userInfoModulename

local k_divModname      = runtimeInfoLib .. ':' .. domainname .. 'divModulename'
local k_divData         = runtimeInfoLib .. ':' .. domainname .. 'divDataKey'
local k_userinfoModname = runtimeInfoLib .. ':' .. domainname .. 'userInfoModulename'
local divModule, divPolicy, userInfoModname

divModname      = sysConfig:get(k_divModname)
divPolicy       = sysConfig:get(k_divData)
userInfoModname = sysConfig:get(k_userinfoModname)

--step 1: read from cache
if areNULL(divModname, divPolicy, userInfoModname) then
-- setp 2: acquire the lock
    local opts = {["timeout"] = tonumber(cache_expire)}
    local lock = resty_lock:new(rt_cache_lock, opts)
    local elapsed, err = lock:lock(userInfo)
    if not elapsed then
        -- lock failed acquired
        -- but go on. This action just set a fence for all but this request
    end
    
    -- setp 3: read from cache again
    divModname      = sysConfig:get(k_divModname)
    divPolicy       = sysConfig:get(k_divData)
    userInfoModname = sysConfig:get(k_userinfoModname)

    if areNULL(divModname, divPolicy, userInfoModname) then
    	-- step 4: fetch from redis
        if not red then
            red = redisModule:new(redisConf)
            local ok, err = red:connectdb()
            if not ok then
                local errinfo = ERRORINFO.REDIS_CONNECT_ERROR
                dolog(errinfo, err, getRewriteInfo())
                local ok, err = lock:unlock()
                return
            end
        end
    
    	local pfunc = function() 
            local runtimeMod    =  runtimeModule:new(red.redis, runtimeInfoLib)
            local runtimeInfo   =  runtimeMod:get(domainname)
            return runtimeInfo
    	end
    	local status, info = xpcall(pfunc, handler)
    	if not status then
            local errinfo  = info[1]
            local errstack = info[2] 
            local err, desc = errinfo[1], errinfo[2]
            dolog(err, desc, getRewriteInfo(), errstack)
            local ok, err = lock:unlock()
            return
    	end
    
    	divModname      = info[1]
    	divPolicy       = info[2]
    	userInfoModname = info[3]
    
    	if areNULL(divModname, divPolicy, userInfoModname) then
            local errinfo = ERRORINFO.RUNTIME_BLANK_ERROR
            local errdesc = 'runtimeInfo blank'
            
            sysConfig:set(k_divModname, -1, shdict_expire)
            sysConfig:set(k_divData, -1, shdict_expire)
            sysConfig:set(k_userinfoModname, -1, shdict_expire)
            local ok, err = lock:unlock()
            
            if red then setKeepalive(red) end
                dolog(errinfo, errdesc, getRewriteInfo())
            return
    	else
            sysConfig:set(k_divModname, divModname, shdict_expire)
            sysConfig:set(k_divData, divPolicy, shdict_expire)
            sysConfig:set(k_userinfoModname, userInfoModname, shdict_expire)
            local ok, err = lock:unlock()
    	end
    end

elseif isSwitchOff(divModname, divPolicy, userInfoModname) then
    -- switchoff, so goto default upstream
    doredirect()
    return
else
    -- maybe userful
end

--====================================================
--准备工作:
--		分流模块		divModule
--		用户特征提取模块	userInfoModule
--获取用户信息:
--		用户信息		userInfo
local userInfoMod
local diversionMod
local userInfo

local pfunc = function()
    userInfoMod  = require(userInfoModname)
    diversionMod = require(divModname)
    userInfo = userInfoMod:get()
end
local ok, info = xpcall(pfunc, handler)
if not ok then
    local errinfo   = info[1]
    local errstack  = info[2] 
    local err, desc = errinfo[1], errinfo[2]
    dolog(err, desc, getRewriteInfo(), errstack)
    if red then setKeepalive(red) end
    return
end

if not userInfo then
    local errinfo = ERRORINFO.USERINFO_BLANK_ERROR
    local errdesc = userInfoModulename
    dolog(errinfo, errdesc, getRewriteInfo())
    if red then setKeepalive(red) end
    return
end
------------------分流准备工作结束--------------------
--====================================================

local upstream, err = kv_upstream:get(userInfo)
if not upstream then

    if not red then
        red = redisModule:new(redisConf)
        local ok, err = red:connectdb()
        if not ok then
            local errinfo = ERRORINFO.REDIS_CONNECT_ERROR
            dolog(errinfo, err, getRewriteInfo())
            return
        end
    end
    
    local pfunc = function()
        local divModule = diversionMod:new(red.redis, divPolicy)
        local upstream  = divModule:getUpstream(userInfo) 
        return upstream
    end
    local status, backend = xpcall(pfunc, handler)
    if not status then
        local info      = backend
        local errinfo   = info[1]
        local errstack  = info[2] 
        local err, desc = errinfo[1], errinfo[2]
        dolog(err, desc, getRewriteInfo(), errstack)
        return
    end
    
    upstream = backend
end

if upstream then
    ngx.var.backend = upstream
else
    upstream = default_backend
end

kv_upstream:set(userInfo, upstream, shdict_expire)
doredirect()
--------------------分流结果结束----------------------
--====================================================

--====================================================
---------------------后续处理-------------------------
---如果本次请求使用过redis,设置redis对象的keepalive---
------------------------------------------------------
if red then
    setKeepalive(red)
end

