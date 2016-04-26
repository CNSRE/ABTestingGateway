---
-- @classmod abtesting.adapter.policy
-- @release 0.0.1
local modulename = "abtestingAdapterPolicy"

local _M = { _VERSION = "0.0.1" }
local mt = { __index = _M }

local ERRORINFO = require('abtesting.error.errcode').info
local fields    = require('abtesting.utils.init').fields

local separator = ':'
---
-- policyIO new function
-- @param database opened redis.
-- @param baseLibrary a library(prefix of redis key) of policies.
-- @return runtimeInfoIO object
_M.new = function(self, database, baseLibrary)
    if not database then
        error{ERRORINFO.PARAMETER_NONE, 'need avaliable redis db'}
    end
    if not baseLibrary then
        error{ERRORINFO.PARAMETER_NONE, 'need avaliable policy baselib'}
    end
    
    self.database     = database
    self.baseLibrary  = baseLibrary
    self.idCountKey = table.concat({baseLibrary, fields.idCount}, separator)
    
    local ok, err = database:exists(self.idCountKey)
    if not ok then error{ERRORINFO.REDIS_ERROR,  err} end
    
    if 0 == ok then
        local ok, err = database:set(self.idCountKey, '-1')
        if not ok then error{ERRORINFO.REDIS_ERROR, err} end
    end
    return setmetatable(self, mt)
end

---
-- get id for current policy
-- @return the id
_M.getIdCount = function(self)
    local database = self.database
    local key = self.idCountKey
    local idCount, err = database:incr(key)
    if not idCount then error{ERRORINFO.REDIS_ERROR, err} end
    
    return idCount
end

---
-- private function, set diversion type
-- @param id identify a policy
-- @param divtype diversion type (ipange/uid/...)
-- @return allways returned SUCCESS
_M._setDivtype = function(self, id, divtype)
    local database = self.database
    local key = table.concat({self.baseLibrary, id, fields.divtype}, separator)
    local ok, err = database:set(key, divtype)
    if not ok then error{ERRORINFO.REDIS_ERROR, err} end
end

---
-- private function, set diversion data
-- @param id identify a policy
-- @param divdata diversion data
-- @param modulename module name of diversion data (decision by diversion type)
-- @return allways returned SUCCESS
_M._setDivdata = function(self, id, divdata, modulename)
    local divModule = require(modulename)
    local database = self.database
    local key = table.concat({self.baseLibrary, id, fields.divdata}, separator)
    
    divModule:new(database, key):set(divdata)
end

---
-- addtion a policy to specified redis lib
-- @param policy policy of addtion
-- @return allways returned SUCCESS
_M.set = function(self, policy)
    local id = self:getIdCount()
    local database = self.database
    local divModulename = table.concat({'abtesting', 'diversion', policy.divtype}, '.')
    
    self:_setDivtype(id, policy.divtype)
    self:_setDivdata(id, policy.divdata, divModulename)
    
    return id
end

_M.check = function(self, policy)
    local divModulename = table.concat({'abtesting', 'diversion', policy.divtype}, '.')
    local divModule = require(divModulename)
    local database = self.database
    
    return divModule:new(database, ''):check(policy.divdata)
end

---
-- delete a policy from specified redis lib
-- @param id the policy identify
-- @return allways returned SUCCESS
_M.del = function(self, id)
    local database      = self.database
    local baseLibrary   = self.baseLibrary

    local policyLib = baseLibrary .. ':' .. id 

    local keys, err = database:keys(policyLib..'*')
    if not keys then
        error{ERRORINFO.REDIS_ERROR, err}
    end

    database:init_pipeline()
    for _i, key in pairs(keys) do
        database:del(key)
    end
    local ok, err = database:commit_pipeline()
    if not ok then error{ERRORINFO.REDIS_ERROR, err} end
	
end

_M.get = function(self, id)
    local divTypeKey    = table.concat({self.baseLibrary, id, fields.divtype}, separator)
    local divDataKey    = table.concat({self.baseLibrary, id, fields.divdata}, separator)
    local database      = self.database
    local policy        = {}
    policy.divtype      = ngx.null
    policy.divdata      = ngx.null

    local divtype, err  = database:get(divTypeKey)
    if not divtype then
        error{ERRORINFO.REDIS_ERROR, err} 
    elseif divtype == ngx.null then
        return policy
    end

    local divModulename = table.concat({'abtesting', 'diversion', divtype}, '.')
    local divModule     = require(divModulename):new(database, divDataKey)

    local divdata       = divModule:get()
    policy.divtype      = divtype
    policy.divdata      = divdata
    return policy
end

return _M
