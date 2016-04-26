---
-- @classmod abtesting.adapter.runtime
-- @release 0.0.1
local modulename = "abtestingAdapterRuntime"

local _M = {}
local metatable = {__index = _M}

_M._VERSION = "0.0.1"

local ERRORINFO = require('abtesting.error.errcode').info
local fields    = require('abtesting.utils.init').fields

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
_M.set = function(self, domain, ...)
	local info = {...}
	local divModulename = info[1]
	local divDataKey = info[2]
	local userInfoModulename = info[3]

	local database = self.database
	local divModulenamekey = table.concat({self.baseLibrary, domain, fields.divModulename}, separator)
	local divDataKeyOfKey  = table.concat({self.baseLibrary, domain, fields.divDataKey}, separator)
    local userInfoModulenameKey = table.concat({self.baseLibrary, domain, fields.userInfoModulename}, separator)
	local ok, err = database:mset(divModulenamekey, divModulename,
                                    divDataKeyOfKey, divDataKey,
                                        userInfoModulenameKey, userInfoModulename)

	if not ok then error{ERRORINFO.REDIS_ERROR, err} end

	return ERRORINFO.SUCCESS
end

---
-- delete runtime info(diversion modulename and diversion metadata key)
-- @param domain a domain of delete
-- @return if returned, the return value always SUCCESS
_M.del = function(self, domain)
    local database = self.database
    local divModulenamekey = table.concat({self.baseLibrary, domain, fields.divModulename}, separator)
    local divDataKeyOfKey  = table.concat({self.baseLibrary, domain, fields.divDataKey}, separator)
    local userInfoModulenameKey = table.concat({self.baseLibrary, domain, fields.userInfoModulename}, separator)
    
    local ok, err = database:del(divModulenamekey, divDataKeyOfKey, userInfoModulenameKey)
    
    if not ok then error{ERRORINFO.REDIS_ERROR, err} end
    
    return ERRORINFO.SUCCESS
end

---
-- get runtime info(diversion modulename and diversion metadata key)
-- @param domain is a domain name to search runtime info
-- @return a table of diversion modulename and diversion metadata key
_M.get = function(self, domain)
    local database = self.database
    local divModulenameKey      = table.concat({self.baseLibrary, domain, fields.divModulename}, separator)
    local divDataKeyOfKey       = table.concat({self.baseLibrary, domain, fields.divDataKey}, separator)
    local userInfoModulenameKey = table.concat({self.baseLibrary, domain, fields.userInfoModulename}, separator)
    
    local response, err = database:mget(divModulenameKey, divDataKeyOfKey, userInfoModulenameKey)
    if not response then
        error{ERRORINFO.REDIS_ERROR, err}
    end
    
    return response
end

return _M
