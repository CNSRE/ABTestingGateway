---
-- @classmod abtesting.adapter.policy
-- @release 0.0.1
local modulename = "abtestingadminactionruntime"

local _M = { _version = "0.0.1" }
local mt = { __index = _m }

local systemConf    = require('config.config').ab
local ERRORINFO		= require('misc.errcode').info
local handler       = require('misc.handler').handler
local utils         = require('misc.utils')
local log			= require('misc.log')
local errorinfo     = require('misc.errcode').info
local cjson         = require('cjson.safe')

local prefixConf    = systemConf.prefixConf
local divtypes      = systemConf.divtypes
local fields        = systemConf.fields

local runtimeLib    = prefixConf.actionRuntimePrefix
local policyLib     = prefixConf.actionLibPrefix
local action_runtime_module = require('abtesting.adapter.action_runtime')
local policyModule  = require('abtesting.adapter.action_policy')

local doresp        = utils.doresp
local dolog         = utils.dolog
local doerror       = utils.doerror

local getPolicyId = function(policyID)
--    local policyID = tonumber(ngx.var.arg_policyid)
    local policyID = tonumber(policyID)

    if not policyID or policyID < 0 then
        local info = ERRORINFO.PARAMETER_TYPE_ERROR 
        local desc = "policyID invalid"
        local resp = doresp(info, desc)
        ngx.log(ngx.ERR, dolog(info, desc))
        ngx.say(resp)
        return nil 
    end
    return policyID
end

local getHostName = function(hostname)
--    local hostname = ngx.var.arg_hostname
    if not hostname or string.len(hostname) < 1 or hostname == ngx.null then
        local info = ERRORINFO.PARAMETER_TYPE_ERROR 
        local desc = 'arg hostname invalid: '
        local resp = doresp(info, desc)
        ngx.say(resp)
        return nil 
    end
    return hostname
end

_M.get = function(option)
    local database = option.db

    local hostname = getHostName( option.hostname )
	if not hostname then return end

    local pfunc = function()
        local action_runtime = action_runtime_module:new(database, runtimeLib)
        return action_runtime:get(hostname)
    end
    local status, info = xpcall(pfunc, handler)
    if not status then
        local resp = doerror(info)
        ngx.say(resp)
        return false
    end

	local runtime_policy = cjson.decode(info)

    local resp = doresp(ERRORINFO.SUCCESS, nil, runtime_policy or '')
    ngx.say(resp)
end

_M.del = function(option)
    local database = option.db

    local hostname = getHostName( option.hostname )
	if not hostname then return end

    local pfunc = function()
        local action_runtime = action_runtime_module:new(database, runtimeLib)
        return action_runtime:del(hostname)
    end
    local status, info = xpcall(pfunc, handler)
    if not status then
        local resp = doerror(info)
        ngx.say(resp)
        return false
    end

    local resp = doresp(ERRORINFO.SUCCESS)
    ngx.say(resp)
end

_M.set = function(option)
    local policyId = getPolicyId(option.id)
	if not policyId then return end

    local hostname = getHostName( option.hostname )
	if not hostname then return end

	local database = option.db
    local pfunc = function()
        local policyMod = policyModule:new(database, policyLib)
        local policy = policyMod:get(policyId)

		local prefix = hostname
        local action_runtime = action_runtime_module:new(database, runtimeLib)
		action_runtime:del(prefix)
		action_runtime:set(prefix, policy)
	end

    local status, info = xpcall(pfunc, handler)
    if not status then
        local resp = doerror(info)
        ngx.say(resp)
        return false
    end

    local resp = doresp(ERRORINFO.SUCCESS)
    ngx.say(resp)
end

return _M
