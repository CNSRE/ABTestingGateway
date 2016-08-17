---
-- @classmod abtesting.adapter.policy
-- @release 0.0.1
local modulename = "abtestingAdminPolicy"

local _M = { _VERSION = "0.0.1" }
local mt = { __index = _M }


local runtimeModule = require('abtesting.adapter.runtime')
local policyModule  = require('abtesting.adapter.policy')

local systemConf    = require('config.config').ab
local ERRORINFO		= require('misc.errcode').info
local handler       = require('misc.handler').handler
local utils         = require('misc.utils')
local log			= require('misc.log')

local cjson         = require('cjson.safe')
local doresp        = utils.doresp
local dolog         = utils.dolog
local doerror       = utils.doerror

local divtypes      = systemConf.divtypes
local prefixConf    = systemConf.prefixConf
local policyLib     = prefixConf.policyLibPrefix
local runtimeLib    = prefixConf.runtimeInfoPrefix
local domain_name   = prefixConf.domainname


local errhandler = function(info, desc)
    local response = doresp(info, desc)
    ngx.log(ngx.ERR, dolog(info, desc))
    ngx.say(response)
    return false 
end

local getPolicyId = function(policyID)
--    local policyID = tonumber(ngx.var.arg_policyid)
    local policyID = tonumber(policyID)

    if not policyID or policyID < 0 then
        return errhandler(ERRORINFO.PARAMETER_TYPE_ERROR,
                        "policyID invalid")
    end
    return policyID
end

local getPolicy = function(request_body)

--    local request_body  = ngx.var.request_body

    if not request_body then
        return errhandler(ERRORINFO.PARAMETER_NONE,
                        'request_body or post data')

    end

    local postData = cjson.decode(request_body)
    if not postData then
        return errhandler(ERRORINFO.PARAMETER_ERROR ,
                        'postData is not a json string')        
    end

    local divtype = postData.divtype
    local divdata = postData.divdata

    if not divtype or not divdata then
        return errhandler(ERRORINFO.PARAMETER_NONE,
                        "policy divtype or policy divdata")             
    end

    if not divtypes[divtype] then
        return errhandler(ERRORINFO.PARAMETER_TYPE_ERROR ,
                        "unsupported divtype")             
    end

    return postData

end

_M.check = function(option)
    local database = option.db
	local postdata = option.policy

    local policy = getPolicy(postdata)
    if not policy then
        return false
    end

    local pfunc = function() 
        local policyMod = policyModule:new(database, policyLib)
        return policyMod:check(policy)
    end

    local status, info = xpcall(pfunc, handler)
    if not status then
        local response = doerror(info)
        ngx.say(response)
        return false
    end

    local chkout    = info
    local valid     = chkout[1]
    local err       = chkout[2]
    local desc      = chkout[3]

    local response
    if not valid then
        log:errlog(dolog(err, desc))
        response = doresp(err, desc)
    else
        response = doresp(ERRORINFO.SUCCESS)
    end
    ngx.say(response)
    return true

end

_M.set = function(option)
    local database = option.db
	local postdata = option.policy

    local policy = getPolicy(postdata)
    if not policy then
        return false
    end

    local pfunc = function() 
        policyMod = policyModule:new(database, policyLib)
        return policyMod:check(policy)
    end

    local status, info = xpcall(pfunc, handler)
    if not status then
        local response = doerror(info)
        ngx.say(response)
        return false
    end

    local chkout    = info
    local valid     = chkout[1]
    local err       = chkout[2]
    local desc      = chkout[3]

    if not valid then
        return errhandler(err, desc)             
    end

    local pfunc = function() return policyMod:set(policy) end
    local status, info = xpcall(pfunc, handler)
    if not status then
        local response = doerror(info)
        ngx.say(response)
        return false
    end

    local data = ' the id of new policy is '..info
    local response = doresp(ERRORINFO.SUCCESS, data)
    ngx.say(response)
    return true

end

_M.del = function(option)
    local database = option.db
	local pid = option.id

    local policyId = getPolicyId(pid)
    if not policyId then
        return false
    end

    local pfunc = function()
        local policyMod = policyModule:new(database, policyLib) 
        return policyMod:del(policyId)
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

_M.get = function(option)
    local database = option.db
	local pid = option.id

    local policyId = getPolicyId(pid)
    if not policyId then
        return false
    end

    local pfunc = function()
        local policyIO = policyModule:new(database, policyLib) 
        return policyIO:get(policyId)
    end

    local status, info = xpcall(pfunc, handler)
    if not status then
        local response = doerror(info)
        ngx.say(response)
        return false
    else
        local response = doresp(ERRORINFO.SUCCESS, nil, info)
        log:errlog(dolog(ERRORINFO.SUCCESS, nil))
        ngx.say(response)
        return true
    end

end

return _M
