---
-- @classmod abtesting.adapter.policy
-- @release 0.0.1
local modulename = "abtestingAdminRuntime"

local _M = { _VERSION = "0.0.1" }
local mt = { __index = _M }

local ERRORINFO	= require('abtesting.error.errcode').info

local runtimeModule = require('abtesting.adapter.runtime')
local policyModule  = require('abtesting.adapter.policy')
local redisModule   = require('abtesting.utils.redis')
local systemConf    = require('abtesting.utils.init')
local handler       = require('abtesting.error.handler').handler
local utils         = require('abtesting.utils.utils')
local log			= require('abtesting.utils.log')
local ERRORINFO     = require('abtesting.error.errcode').info
local cjson         = require('cjson.safe')

local redisConf     = systemConf.redisConf
local prefixConf    = systemConf.prefixConf
local runtimeLib    = prefixConf.runtimeInfoPrefix
local policyLib     = prefixConf.policyLibPrefix
local domain_name   = prefixConf.domainname
local divtypes      = systemConf.divtypes
local fields        = systemConf.fields

local runtimeGroupModule = require('abtesting.adapter.runtimegroup')
local policyGroupModule  = require('abtesting.adapter.policygroup')
local policyGroupLib     = prefixConf.policyGroupPrefix


local doresp        = utils.doresp
local dolog         = utils.dolog
local doerror       = utils.doerror

local getPolicyId = function()
    local policyID = tonumber(ngx.var.arg_policyid)
    return policyID
end

local getPolicyGroupId = function()
    local policyGroupId = tonumber(ngx.var.arg_policygroupid)
    return policyGroupId
end

local getHostName = function()
    local hostname = ngx.var.arg_hostname
    return hostname
end

local getDivSteps = function()
    local divsteps = tonumber(ngx.var.arg_divsteps)
    return divsteps
end

_M.get = function(option)
    local db = option.db
    local database = db.redis

    local hostname = getHostName()
    if not hostname or string.len(hostname) < 1 or hostname == ngx.null then
        local info = ERRORINFO.PARAMETER_TYPE_ERROR 
        local desc = 'arg hostname invalid: '
        local response = doresp(info, desc)
        log:errlog(dolog(info, desc))
        ngx.say(response)
        return nil 
    end

    local pfunc = function()
        local runtimeGroupMod = runtimeGroupModule:new(database, runtimeLib)
        return runtimeGroupMod:get(hostname)
    end
    local status, info = xpcall(pfunc, handler)
    if not status then
        local response = doerror(info)
        ngx.say(response)
        return false
    end

    local response = doresp(ERRORINFO.SUCCESS, nil, info)
    ngx.say(response)
    return true
end

_M.del = function(option)
    local db = option.db
    local database = db.redis

    local hostname = getHostName()
    if not hostname or string.len(hostname) < 1 or hostname == ngx.null then
        local info = ERRORINFO.PARAMETER_TYPE_ERROR 
        local desc = 'arg hostname invalid: '
        local response = doresp(info, desc)
        log:errlog(dolog(info, desc))
        ngx.say(response)
        return nil 
    end

    local pfunc = function()
        local runtimeGroupMod = runtimeGroupModule:new(database, runtimeLib)
        return runtimeGroupMod:del(hostname)
    end
    local status, info = xpcall(pfunc, handler)
    if not status then
        local response = doerror(info)
        ngx.say(response)
        return false
    end

    local response = doresp(ERRORINFO.SUCCESS)
    ngx.say(response)
    return true
end

_M.set = function(option)
    local policyId = getPolicyId()
    local policyGroupId = getPolicyGroupId()

    if policyId and policyId >= 0 then
        _M.runtimeset(option, policyId)
    elseif policyGroupId and policyGroupId >= 0 then
        _M.groupset(option, policyGroupId)
    else
        local info = ERRORINFO.PARAMETER_TYPE_ERROR 
        local desc = "policyId or policyGroupid invalid"
        local response = doresp(info, desc)
        log:errlog(dolog(info, desc))
        ngx.say(response)
        return nil 
    end
end

_M.groupset = function(option, policyGroupId)
    local db = option.db
    local database = db.redis

    local hostname = getHostName()
    local divsteps = getDivSteps()

    if not hostname or string.len(hostname) < 1 or hostname == ngx.null then
        local info = ERRORINFO.PARAMETER_TYPE_ERROR 
        local desc = 'arg hostname invalid: '
        local response = doresp(info, desc)
        log:errlog(dolog(info, desc))
        ngx.say(response)
        return nil 
    end

    local pfunc = function()
        local runtimeGroupMod = runtimeGroupModule:new(database, runtimeLib)
        runtimeGroupMod:del(hostname)
        return runtimeGroupMod:set(hostname, policyGroupId, divsteps)
    end
    local status, info = xpcall(pfunc, handler)
    if not status then
        local response = doerror(info)
        ngx.say(response)
        return false
    end

    local response = doresp(ERRORINFO.SUCCESS)
    ngx.say(response)
    return true

end

_M.runtimeset = function(option, policyId)
    local db = option.db
    local database = db.redis

    local hostname = getHostName()
    local divsteps = 1

    if not hostname or string.len(hostname) < 1 or hostname == ngx.null then
        local info = ERRORINFO.PARAMETER_TYPE_ERROR 
        local desc = 'arg hostname invalid: '
        local response = doresp(info, desc)
        log:errlog(dolog(info, desc))
        ngx.say(response)
        return nil 
    end

    local pfunc = function()
        local runtimeGroupMod = runtimeGroupModule:new(database, runtimeLib)
        return runtimeGroupMod:del(hostname)
    end
    local status, info = xpcall(pfunc, handler)
    if not status then
        local response = doerror(info)
        ngx.say(response)
        return false
    end

    local pfunc = function()
        local policyMod = policyModule:new(database, policyLib)
        local policy = policyMod:get(policyId)

        local divtype = policy.divtype
        local divdata = policy.divdata

        if divtype == ngx.null or divdata == ngx.null then
            error{ERRORINFO.POLICY_BLANK_ERROR, 'policy NO '..policyId}
        end

        if not divtypes[divtype] then

        end

        local prefix             = hostname .. ':first'
        local divModulename      = table.concat({'abtesting', 'diversion', divtype}, '.')
        local divDataKey         = table.concat({policyLib, policyId, fields.divdata}, ':')
        local userInfoModulename = table.concat({'abtesting', 'userinfo', divtypes[divtype]}, '.')
        local runtimeMod         = runtimeModule:new(database, runtimeLib) 
        runtimeMod:set(prefix, divModulename, divDataKey, userInfoModulename)

        local divSteps           = runtimeLib .. ':' .. hostname .. ':' .. fields.divsteps
        local ok, err = database:set(divSteps, 1)
        if not ok then error{ERRORINFO.REDIS_ERROR, err} end
    end

    local status, info = xpcall(pfunc, handler)
    if not status then
        local response = doerror(info)
        ngx.say(response)
        return false
    end


    local response = doresp(ERRORINFO.SUCCESS)
    ngx.say(response)
    return true
end



return _M
