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
local ERRORINFO     = require('abtesting.error.errcode').info
local cjson         = require('cjson.safe')

local redisConf     = systemConf.redisConf
local prefixConf    = systemConf.prefixConf
local runtimeLib    = prefixConf.runtimeInfoPrefix
local policyLib     = prefixConf.policyLibPrefix
local domain_name   = prefixConf.domainname
local divtypes      = systemConf.divtypes

local fields = {}
fields.divModulename        = 'divModulename'
fields.divDataKey           = 'divDataKey'
fields.userInfoModulename   = 'userInfoModulename'

local separator = ':'
fields.divtype  = 'divtype'
fields.divdata  = 'divdata'
fields.idCount  = 'idCount'

local doresp    = utils.doresp
local dolog     = utils.dolog

local getDomainName = function()
    local domainName = domain_name 
    if not domainName or domainName == ngx.null 
        or string.len(domainName) < 1 then
        local info = ERRORINFO.PARAMETER_NONE 
        local desc = "domainName is blank and please set it in nginx.conf"
        local response = doresp(info, desc)
        dolog(info, desc)
        ngx.say(response)
        return false
    end

    return domainName
end

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

_M.get = function(option)
    local db = option.db

    local domainName = getDomainName()
    if not domainName then
        return false
    end

    local pfunc = function()
        local runtimeMod = runtimeModule:new(db.redis, runtimeLib) 
        return runtimeMod:get(domainName)
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
        divModulename       = fields.divModulename 
        divDataKey          = fields.divDataKey 
        userInfoModulename  = fields.userInfoModulename 

        local runtimeInfo   = {}
        runtimeInfo[divModulename]      = info[1]
        runtimeInfo[divDataKey]         = info[2]
        runtimeInfo[userInfoModulename] = info[3]

        local response = doresp(ERRORINFO.SUCCESS, nil, runtimeInfo)
        ngx.say(response)
        return true
    end

end

_M.del = function(option)
    local db = option.db

    local domainName = getDomainName()
    if not domainName then
        return false
    end

    local pfunc = function()
        local runtimeMod = runtimeModule:new(db.redis, runtimeLib) 
        runtimeMod:del(domainName)
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

_M.set = function(option)
    local db = option.db

    local policyId = getPolicyId()
    if not policyId then
        return false
    end

    local domainName = getDomainName()
    if not domainName then
        return false
    end

    local pfunc = function()
        local policyMod = policyModule:new(db.redis, policyLib)
        return policyMod:get(policyId)
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

    local divtype = info.divtype
    local divdata = info.divdata
    if divtype == ngx.null or
        divdata == ngx.null then
        local err	= ERRORINFO.POLICY_BLANK_ERROR
        local desc	= 'policy NO.'..policyId
        local response  = doresp(err, desc)
        dolog(err, desc)
        ngx.say(response)
        return false
    end

    if not divtypes[divtype] then
        -- unsupported divtype
    end

    local pfunc = function()
        local divModulename     = table.concat({'abtesting', 'diversion', divtype}, '.')
        local divDataKey        = table.concat({policyLib, policyId, fields.divdata}, ':')
        local userInfoModulename= table.concat({'abtesting', 'userinfo', divtypes[divtype]}, '.')

        local runtimeMod        = runtimeModule:new(db.redis, runtimeLib) 
        return runtimeMod:set(domainName, divModulename, divDataKey, userInfoModulename)
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

return _M


