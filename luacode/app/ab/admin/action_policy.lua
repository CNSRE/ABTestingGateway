
local modulename = "abtestingAdminAction"

local _M = { _VERSION = "0.0.1" }
local mt = { __index = _M }

local systemConf    = require('config.config').ab
local ERRORINFO		= require('misc.errcode').info
local handler       = require('misc.handler').handler
local utils         = require('misc.utils')
local log			= require('misc.log')
local ERRORINFO     = require('misc.errcode').info
local cjson         = require('cjson.safe')

local prefixConf    = systemConf.prefixConf
local actionLib		= prefixConf.actionLibPrefix
local domain_name   = prefixConf.domainname
local divtypes      = systemConf.divtypes
local fields        = systemConf.fields

local action_module = require('abtesting.adapter.action_policy')

local doresp        = utils.doresp
local dolog         = utils.dolog
local doerror       = utils.doerror


local getPolicy = function(request_body)

--    local request_body  = ngx.var.request_body

    if not request_body then
        -- ERRORCODE.PARAMETER_NONE
        local errinfo   = ERRORINFO.PARAMETER_NONE
        local desc      = 'request_body or post data'
        local resp  = doresp(errinfo, desc)
        log:errlog(dolog(errinfo, desc))
        ngx.say(resp)
        return nil
    end
	return request_body
end

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

_M.check = function(option)

	local database = option.db
	local policy = getPolicy( option.policy )
	if not policy then return end


	local pfunc = function()
        local actionmod = action_module:new(database, actionLib)
        return actionmod:check(policy)
	end
    local ok, ret, err = xpcall(pfunc, handler)
    if not ok then
        local resp = doerror(ret)
        ngx.say(resp)
        return false
    end

	local resp
	if not ret then
		resp = doresp(ERRORINFO.POLICY_PARAMETER_ERROR, err)
	else
		resp = doresp(ERRORINFO.SUCCESS)
	end
    ngx.say(resp)
end


_M.set = function(option)
	local database = option.db
	local policy = getPolicy( option.policy )
	if not policy then return end

	-- 先check
	local pfunc = function()
        local actionmod = action_module:new(database, actionLib)
        return actionmod:check(policy)
	end
    local ok, ret, err = xpcall(pfunc, handler)
    if not ok then
        local resp = doerror(ret)
        ngx.say(resp)
        return
    end
	if not ret then
	    local resp = doresp(ERRORINFO.POLICY_PARAMETER_ERROR, err)
	    ngx.log(ngx.ERR, resp)
	    ngx.say(resp)
	    return 
	end
	
	local pfunc = function()
        local actionmod = action_module:new(database, actionLib)
        return actionmod:set(policy)
	end
    local status, info = xpcall(pfunc, handler)
    if not status then
        local resp = doerror(info)
        ngx.say(resp)
        return false
    end

    local data = 'the id of new policy is '..info
    local resp = doresp(ERRORINFO.SUCCESS, data)
    ngx.say(resp)
end

_M.get = function(option)
    local database = option.db

	local policyid = getPolicyId(option.id)
	if not policyid then return end

    local pfunc = function()
        local actionmod = action_module:new(database, actionLib)
        return actionmod:get(policyid)
    end
    local status, info = xpcall(pfunc, handler)
    if not status then
        local resp = doerror(info)
        ngx.say(resp)
        return false
    end

	policy = cjson.decode(info)
	
    local resp = doresp(ERRORINFO.SUCCESS, nil, policy or '')
    ngx.say(resp)
end


_M.del = function(option)
    local database = option.db

	local policyid = getPolicyId(option.id)
	if not policyid then return end

    local pfunc = function()
        local actionmod = action_module:new(database, actionLib)
        return actionmod:del(policyid)
    end
    local status, info = xpcall(pfunc, handler)
    if not status then
        local resp = doerror(info)
        ngx.say(resp)
        return false
    end

    local resp = doresp(ERRORINFO.SUCCESS, nil, info)
    ngx.say(resp)

end

return _M
