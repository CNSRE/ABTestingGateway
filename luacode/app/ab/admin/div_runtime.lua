---
-- @classmod abtesting.adapter.policy
-- @release 0.0.1
local modulename = "abtestingAdminDivRuntime"

local _M = { _VERSION = "0.0.1" }
local mt = { __index = _M }


local runtimeModule = require('abtesting.adapter.runtime')
local policyModule  = require('abtesting.adapter.policy')

local ERRORINFO		= require('misc.errcode').info
local systemConf    = require('config.config').ab
local handler       = require('misc.handler').handler
local utils         = require('misc.utils')
local log			= require('misc.log')
local ERRORINFO     = require('misc.errcode').info

local cjson         = require('cjson.safe')

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


local errhandler = function(info, desc)
    local response = doresp(info, desc)
    ngx.log(ngx.ERR, dolog(info, desc))
    ngx.say(response)
    return false 
end

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
    if not hostname or string.len(hostname) < 1 or hostname == ngx.null then
        return errhandler(ERRORINFO.PARAMETER_TYPE_ERROR,
                        'arg hostname invalid: ')        
    end
    return hostname
end

local getDivSteps = function()
    local divsteps = tonumber(ngx.var.arg_divsteps)
    return divsteps
end

_M.get = function(option)
    local database = option.db
	local hostname = option.hostname
	if not hostname then return end

--	local hostname = getHostName()
--	if not hostname then return end

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
	ngx.log(ngx.ERR, response)
    return true
end

_M.del = function(option)
    local database = option.db
	local hostname = option.hostname
	if not hostname then return end

--	local hostname = getHostName()
--	if not hostname then return end

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

	_M.groupset(option)

--	废掉runtimeset接口，只提供groupset接口
--
--    local policyId = getPolicyId()
--    local policyGroupId = getPolicyGroupId()
--    if policyId and policyId >= 0 then
--        _M.runtimeset(option, policyId)
--    elseif policyGroupId and policyGroupId >= 0 then
--        _M.groupset(option, policyGroupId)
--    else
--        return errhandler(ERRORINFO.PARAMETER_TYPE_ERROR,
--                        "policyId or policyGroupid invalid")               
--    end
end

-- _M.groupset = function(option, policyGroupId)
_M.groupset = function(option)
    local database = option.db
    local divsteps = getDivSteps()

	local hostname = option.hostname
    if not hostname or string.len(hostname) < 1
						or hostname == ngx.null then
        return errhandler(ERRORINFO.PARAMETER_TYPE_ERROR,
                        'arg hostname invalid: ')        
    end

	local policy_group_id = tonumber(option.id)
	if not policy_group_id or policy_group_id < 0 then
        return errhandler(ERRORINFO.PARAMETER_TYPE_ERROR,
                        "policyGroupid invalid")               
	end

    local pfunc = function()
        local runtimeGroupMod = runtimeGroupModule:new(database, runtimeLib)
        return runtimeGroupMod:set(hostname, policy_group_id, divsteps)
    end
    local status, info = xpcall(pfunc, handler)
    if not status then
        local response = doerror(info)
        ngx.say(response)
        return false
    end

    local resp = doresp(ERRORINFO.SUCCESS, 'set policy_group_id ['..policy_group_id..'] as runtime info of host ['..hostname..']' )
	ngx.log(ngx.ERR, resp)
    ngx.say(resp)
	return true
end

_M.runtimeset = function(option, policyId)
    local database = option.db
    local divsteps = 1

    local hostname = getHostName()
	if not hostname then return end

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
        -- ngx.log(ngx.ERR, "hello")
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
