local runtimeModule = require('abtesting.adapter.runtime')
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

local doresp        = utils.doresp
local dolog         = utils.dolog

local domainName = domain_name or ngx.var.arg_domainname 
if not domainName then
    local request_body  = ngx.var.request_body
    local postData      = cjson.decode(request_body)
    
    if not request_body then
        -- ERRORCODE.PARAMETER_NONE
        local info = ERRORINFO.PARAMETER_NONE 
        local desc = 'request_body or post data'
        local response = doresp(info, desc)
        dolog(info, desc)
        ngx.say(response)
        return
    end
    
    if not postData then
        -- ERRORCODE.PARAMETER_ERROR
        local info = ERRORINFO.PARAMETER_ERROR 
        local desc = 'postData is not a json string'
        local response = doresp(info, desc)
        dolog(info, desc)
        ngx.say(response)
        return
    end
    
    if not domainName then
        domainName = postData.domainname
        if not domainName then
            local info = ERRORINFO.PARAMETER_NONE
            local desc = "domainName"
            local response = doresp(info, desc)
            dolog(info, desc)
            ngx.say(response)
            return
        end
    end
end


local red = redisModule:new(redisConf)
local ok, err = red:connectdb()
if not ok then
    local errinfo	= ERRORINFO.REDIS_CONNECT_ERROR
    local response	= doresp(errinfo, err)
    dolog(errinfo, err)
    ngx.say(response)
    return
end

local pfunc = function()
    local runtimeMod = runtimeModule:new(red.redis, runtimeLib) 
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
    return
end

local response = doresp(ERRORINFO.SUCCESS)
ngx.say(response)
