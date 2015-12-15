---
-- @classmod abtesting.adapter.policy
-- @release 0.0.1
local modulename = "abtestingAdminPolicy"

local _M = { _VERSION = "0.0.1" }
local mt = { __index = _M }

local ERRORINFO	= require('abtesting.error.errcode').info

local runtimeModule = require('abtesting.adapter.runtime')
local policyModule  = require('abtesting.adapter.policy')
local redisModule   = require('abtesting.utils.redis')
local systemConf    = require('abtesting.utils.init')
local handler       = require('abtesting.error.handler').handler
local utils         = require('abtesting.utils.utils')
local ERRORINFO     = require('abtesting.error.errcode').info

local cjson         = require('cjson.safe')
local doresp        = utils.doresp
local dolog         = utils.dolog

local redisConf     = systemConf.redisConf
local divtypes      = systemConf.divtypes
local prefixConf    = systemConf.prefixConf
local policyLib     = prefixConf.policyLibPrefix
local runtimeLib    = prefixConf.runtimeInfoPrefix
local domain_name   = prefixConf.domainname



local getPolicyId = function()
    local policyID      = ngx.var.arg_policyid

    if policyID then
        policyID = tonumber(ngx.var.arg_policyid)
        if not policyID or policyID < 0 then
            local info = ERRORINFO.PARAMETER_TYPE_ERROR 
            local desc = "policyID should be a positive Integer"
            local response = doresp(info, desc)
            dolog(info, desc)
            ngx.say(response)
            return nil 
        end
    end

    if not policyID then
        local request_body  = ngx.var.request_body
        local postData      = cjson.decode(request_body)

        if not request_body then
            -- ERRORCODE.PARAMETER_NONE
            local info = ERRORINFO.PARAMETER_NONE 
            local desc = 'request_body or post data to get policyID'
            local response = doresp(info, desc)
            dolog(info, desc)
            ngx.say(response)
            return nil 
        end

        if not postData then
            -- ERRORCODE.PARAMETER_ERROR
            local info = ERRORINFO.PARAMETER_ERROR 
            local desc = 'postData is not a json string'
            local response = doresp(info, desc)
            dolog(info, desc)
            ngx.say(response)
            return nil 
        end

        policyID = postData.policyid

        if not policyID then
            local info = ERRORINFO.PARAMETER_ERROR 
            local desc = "policyID is needed"
            local response = doresp(info, desc)
            dolog(info, desc)
            ngx.say(response)
            return nil
        end

        policyID = tonumber(postData.policyid)

        if not policyID or policyID < 0 then
            local info = ERRORINFO.PARAMETER_TYPE_ERROR 
            local desc = "policyID should be a positive Integer"
            local response = doresp(info, desc)
            dolog(info, desc)
            ngx.say(response)
            return nil
        end
    end

    return policyID

end

local getPolicy = function()

    local request_body  = ngx.var.request_body
    local postData      = cjson.decode(request_body)

    if not request_body then
        -- ERRORCODE.PARAMETER_NONE
        local errinfo   = ERRORINFO.PARAMETER_NONE
        local desc      = 'request_body or post data'
        local response  = doresp(errinfo, desc)
        dolog(errinfo, desc)
        ngx.say(response)
        return nil
    end

    if not postData then
        -- ERRORCODE.PARAMETER_ERROR
        local errinfo   = ERRORINFO.PARAMETER_ERROR 
        local desc      = 'postData is not a json string'
        local response  = doresp(errinfo, desc)
        dolog(errinfo, desc)
        ngx.say(response)
        return nil
    end

    local divtype = postData.divtype
    local divdata = postData.divdata

    if not divtype or not divdata then
        -- ERRORCODE.PARAMETER_NONE
        local errinfo   = ERRORINFO.PARAMETER_NONE 
        local desc      = "policy divtype or policy divdata"
        local response  = doresp(errinfo, desc)
        dolog(errinfo, desc)
        ngx.say(response)
        return nil
    end

    if not divtypes[divtype] then
        -- ERRORCODE.PARAMETER_TYPE_ERROR
        local errinfo   = ERRORINFO.PARAMETER_TYPE_ERROR 
        local desc      = "unsupported divtype"
        local response  = doresp(errinfo, desc)
        dolog(errinfo, desc)
        ngx.say(response)
        return nil
    end

    return postData

end

_M.check = function(option)
    local db = option.db

    local policy = getPolicy()
    if not policy then
        return false
    end

    local pfunc = function() 
        local policyMod = policyModule:new(db.redis, policyLib)
        return policyMod:check(policy)
    end

    local status, info = xpcall(pfunc, handler)
    if not status then
        local errinfo   = info[1]
        local errstack  = info[2] 
        local err, desc = errinfo[1], errinfo[2]
        local response  = doresp(err, desc)
        dolog(err, desc, nil, errstack)
        ngx.say(response)
        return false
    end

    local chkout    = info
    local valid     = chkout[1]
    local err       = chkout[2]
    local desc      = chkout[3]

    local response
    if not valid then
        dolog(err, desc)
        response = doresp(err, desc)
    else
        response = doresp(ERRORINFO.SUCCESS)
    end
    ngx.say(response)
    return true

end

_M.set = function(option)
    local db = option.db

    local policy = getPolicy()
    if not policy then
        return false
    end

    local pfunc = function() 
        policyMod = policyModule:new(db.redis, policyLib)
        return policyMod:check(policy)
    end

    local status, info = xpcall(pfunc, handler)
    if not status then
        local errinfo  = info[1]
        local errstack = info[2] 
        local err, desc = errinfo[1], errinfo[2]
        local response	= doresp(err, desc)
        dolog(err, desc, nil, errstack)
        ngx.say(response)
        return false
    end

    local chkout    = info
    local valid     = chkout[1]
    local err       = chkout[2]
    local desc      = chkout[3]

    if not valid then
        dolog(err, desc)
        local response = doresp(err, desc)
        ngx.say(response)
        return false
    end

    local pfunc = function() return policyMod:set(policy) end
    local status, info = xpcall(pfunc, handler)
    if not status then
        local errinfo   = info[1]
        local errstack  = info[2] 
        local err, desc = errinfo[1], errinfo[2]
        local response  = doresp(err, desc)
        dolog(err, desc, nil, errstack)
        ngx.say(response)
        return false
    end

    local data
    if info then
        data = ' the id of new policy is '..info
    end

    local response = doresp(ERRORINFO.SUCCESS, data)
    ngx.say(response)
    return true

end

_M.del = function(option)
    local db = option.db

    local policyId = getPolicyId()
    if not policyId then
        return false
    end

    local pfunc = function()
        local policyMod = policyModule:new(db.redis, policyLib) 
        return policyMod:del(policyId)
    end

    local status, info = xpcall(pfunc, handler)
    if not status then
        local errinfo   = info[1]
        local errstack  = info[2] 
        local err, desc = errinfo[1], errinfo[2]
        local response  = doresp(err, desc)
        dolog(err, desc, nil, errstack)
        ngx.say(response)
        return false
    end

    local response = doresp(ERRORINFO.SUCCESS)
    ngx.say(response)
    return true
end

_M.get = function(option)
    local db = option.db

    local policyId = getPolicyId()
    if not policyId then
        return false
    end

    local pfunc = function()
        local policyIO = policyModule:new(db.redis, policyLib) 
        return policyIO:get(policyId)
    end

    local status, info = xpcall(pfunc, handler)
    if not status then
        local errinfo   = info[1]
        local errstack  = info[2] 
        local err, desc = errinfo[1], errinfo[2]
        local response  = doresp(err, desc)
        dolog(err, desc, nil, errstack)
        ngx.say(response)
        return false
    else
        local response = doresp(ERRORINFO.SUCCESS, nil, info)
        dolog(ERRORINFO.SUCCESS, nil)
        ngx.say(response)
        return true
    end

end

return _M
