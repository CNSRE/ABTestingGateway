local runtimeModule = require('abtesting.adapter.runtime')
local policyModule  = require('abtesting.adapter.policy')
local redisModule   = require('abtesting.utils.redis')
local systemConf    = require('abtesting.utils.init')
local handler       = require('abtesting.error.handler').handler
local utils         = require('abtesting.utils.utils')
local ERRORINFO     = require('abtesting.error.errcode').info
local cjson         = require('cjson.safe')

local redisConf			  = systemConf.redisConf
local prefixConf		  = systemConf.prefixConf
local runtimeInfoLib      = prefixConf.runtimeInfoPrefix
local policyLib			  = prefixConf.policyLibPrefix
local domain_name		  = prefixConf.domainname
local divtypes			  = systemConf.divtypes

local separator = ':'
local fields = {}
fields.divtype = 'divtype'
fields.divdata = 'divdata'
fields.idCount = 'idCount'

local doresp		 = utils.doresp
local dolog			 = utils.dolog

local domainName = domain_name 
if not domainName or domainName == ngx.null 
	or string.len(domainName) < 1 then
        local info = ERRORINFO.PARAMETER_NONE 
        local desc = "domainName is blank and please set it in nginx.conf"
        local response = doresp(info, desc)
		dolog(info, desc)
        ngx.say(response)
        return
end

local policyID	= ngx.var.arg_policyid

if policyID then
	policyID = tonumber(ngx.var.arg_policyid)
    if not policyID or policyID < 0 then
        local info = ERRORINFO.PARAMETER_TYPE_ERROR 
        local desc = "policyID should be a positive Integer"
        local response = doresp(info, desc)
		dolog(info, desc)
        ngx.say(response)
        return
    end
end

if not policyID then
    local request_body = ngx.var.request_body
    local postData = cjson.decode(request_body)

    if not request_body then
        -- ERRORCODE.PARAMETER_NONE
        local info = ERRORINFO.PARAMETER_NONE 
        local desc = 'request_body or post data to get policyID'
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

	policyID = postData.policyid

    if not policyID then
        local info = ERRORINFO.PARAMETER_ERROR 
        local desc = "policyID is needed"
        local response = doresp(info, desc)
		dolog(info, desc)
        ngx.say(response)
        return
    end

    policyID = tonumber(postData.policyid)

    if not policyID or policyID < 0 then
        local info = ERRORINFO.PARAMETER_TYPE_ERROR 
        local desc = "policyID should be a positive Integer"
        local response = doresp(info, desc)
		dolog(info, desc)
        ngx.say(response)
        return
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
	local policyMod = policyModule:new(red.redis, policyLib)
	return policyMod:get(policyID)
end

local status, info = xpcall(pfunc, handler)
if not status then
	local errinfo  = info[1]
	local errstack = info[2] 
    local err, desc = errinfo[1], errinfo[2]
    local response	= doresp(err, desc)
	dolog(err, desc, nil, errstack)
    ngx.say(response)
    return

end

local divtype = info.divtype
local divdata = info.divdata
if divtype == ngx.null or
	divdata == ngx.null then
	local err	= ERRORINFO.POLICY_BLANK_ERROR
	local desc	= 'policy NO.'..policyID
    local response  = doresp(err, desc)
	dolog(err, desc)
	ngx.say(response)
	return
end

if not divtypes[divtype] then
	-- unsupported divtype
end

local pfunc = function()
	local divModulename		 = table.concat({'abtesting', 'diversion', divtype}, '.')
	local divDataKey		 = table.concat({policyLib, policyID, fields.divdata}, ':')
	local userInfoModulename = table.concat({'abtesting', 'userinfo', divtypes[divtype]}, '.')

	local runtimeMod		 = runtimeModule:new(red.redis, runtimeInfoLib) 
	return runtimeMod:set(domainName, divModulename, divDataKey, userInfoModulename)
end

local status, info = xpcall(pfunc, handler)
if not status then
	local errinfo  = info[1]
	local errstack = info[2] 
    local err, desc = errinfo[1], errinfo[2]
    local response	= doresp(err, desc)
	dolog(err, desc, nil, errstack)
    ngx.say(response)
    return
end

local response = doresp(ERRORINFO.SUCCESS)
ngx.say(response)
