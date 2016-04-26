---
-- @classmod abtesting.adapter.runtime
-- @release 0.0.1
local modulename = "abtestingAdapterRuntimeGroup"

local _M = {}
local metatable = {__index = _M}

_M._VERSION = "0.0.1"

local ERRORINFO         = require('abtesting.error.errcode').info
local runtimeModule     = require('abtesting.adapter.runtime')
local systemConf        = require('abtesting.utils.init')
local policyModule      = require('abtesting.adapter.policy')
local policyGroupModule = require('abtesting.adapter.policygroup')
local prefixConf        = systemConf.prefixConf
local divtypes          = systemConf.divtypes
local policyLib         = prefixConf.policyLibPrefix
local policyGroupLib    = prefixConf.policyGroupPrefix
local indices           = systemConf.indices 
local fields            = systemConf.fields

local separator = ':'

---
-- runtimeInfoIO new function
-- @param database  opened redis
-- @param baseLibrary a library(prefix of redis key) of runtime info
-- @return runtimeInfoIO object
_M.new = function(self, database, baseLibrary)
	if not database then
		error{ERRORINFO.PARAMETER_NONE, 'need a object of redis'}
	end if not baseLibrary then
	    error{ERRORINFO.PARAMETER_NONE, 'need a library of runtime info'}
    end

    self.database     = database
    self.baseLibrary  = baseLibrary

    return setmetatable(self, metatable)
end

---
-- set runtime info(diversion modulename and diversion metadata key)
-- @param domain is a domain name to search runtime info
-- @param ... now is diversion modulename and diversion data key
-- @return if returned, the return value always SUCCESS
_M.set = function(self, domain, policyGroupId, divsteps)
    local database = self.database
    local baseLibrary = self.baseLibrary
    local prefix = baseLibrary .. ':' .. domain

    local policyGroupMod = policyGroupModule:new(database, policyGroupLib, policyLib)
    local policyGroup = policyGroupMod:get(policyGroupId)
    local groupid = policyGroup.groupid
    local group = policyGroup.group

--  添加 group为空错误
    if #group < 1 then
        error{ERRORINFO.PARAMETER_TYPE_ERROR, 'blank policyGroupId'}
    end

    if divsteps and divsteps > #group then  
        error{ERRORINFO.PARAMETER_TYPE_ERROR, 'divsteps is deeper than policyGroupID'}
    end

    if not divsteps then divsteps = #group end

    for i = 1, divsteps do
        local idx = indices[i]
        local policyId = group[i]

        local policyMod = policyModule:new(database, policyLib)
        local policy = policyMod:get(policyId)

        local divtype = policy.divtype
        local divdata = policy.divdata
        if divtype == ngx.null or
            divdata == ngx.null then
            error{ERRORINFO.POLICY_BLANK_ERROR, 'policy NO.'..policyId}
        end

        --        if not divtypes[divtype] then
        --            -- unsupported divtype
        --        end

        local divModulename     = table.concat({'abtesting', 'diversion', divtype}, '.')
        local divDataKey        = table.concat({policyLib, policyId, fields.divdata}, ':')
        local userInfoModulename= table.concat({'abtesting', 'userinfo', divtypes[divtype]}, '.')

        local runtimeMod = runtimeModule:new(database, prefix) 
        runtimeMod:set(idx, divModulename, divDataKey, userInfoModulename)
    end
    
    local divStep = prefix .. ':' .. fields.divsteps
    database:set(divStep, divsteps)

    return ERRORINFO.SUCCESS
end

---
-- get runtime info(diversion modulename and diversion metadata key)
-- @param domain is a domain name to search runtime info
-- @return a table of diversion modulename and diversion metadata key
_M.get = function(self, domain)
    local database = self.database
    local baseLibrary = self.baseLibrary
    local prefix = baseLibrary .. ':' .. domain

    local ret = {}

    local divStep = prefix .. ':' .. fields.divsteps
    local ok, err = database:get(divStep)
    if not ok then error{ERRORINFO.REDIS_ERROR, err} end

    local divsteps = tonumber(ok)
    if not divsteps then
        ret.divsteps = 0
        ret.runtimegroup = {}
        return ret
    end

    local runtimeGroup = {}
    for i = 1, divsteps do
        local idx = indices[i]
        local runtimeMod    =  runtimeModule:new(database, prefix)
        local runtimeInfo   =  runtimeMod:get(idx)
        local rtInfo   = {}
        rtInfo[fields.divModulename]      = runtimeInfo[1]
        rtInfo[fields.divDataKey]         = runtimeInfo[2]
        rtInfo[fields.userInfoModulename] = runtimeInfo[3]

        runtimeGroup[idx] = rtInfo
    end

    ret.divsteps = divsteps
    ret.runtimegroup = runtimeGroup
    return ret

end

---
-- delete runtime info(diversion modulename and diversion metadata key)
-- @param domain a domain of delete
-- @return if returned, the return value always SUCCESS
_M.del = function(self, domain)
    local database = self.database
    local baseLibrary = self.baseLibrary
    local prefix = baseLibrary .. ':' .. domain

    local divStep = prefix .. ':' .. fields.divsteps
    local ok, err = database:get(divStep)
    if not ok then error{ERRORINFO.REDIS_ERROR, err} end

    local divsteps = tonumber(ok)
    if not divsteps or divsteps == ngx.null or divsteps == null then
        local ok, err = database:del(divStep)
        if not ok then error{ERRORINFO.REDIS_ERROR, err} end
        return nil
    end

    for i = 1, divsteps do
        local idx = indices[i]
        local runtimeMod =  runtimeModule:new(database, prefix)
        local ok, err = runtimeMod:del(idx)
        if not ok then error{ERRORINFO.REDIS_ERROR, err} end
    end

    local ok, err = database:del(divStep)
    if not ok then error{ERRORINFO.REDIS_ERROR, err} end
end

return _M
