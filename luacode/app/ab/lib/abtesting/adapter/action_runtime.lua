---
-- @classmod abtesting.adapter.runtime
-- @release 0.0.1
local modulename = "abtestingAdapterActionRuntime"

local _M = {}
local metatable = {__index = _M}

_M._VERSION = "0.0.1"

local ERRORINFO = require('misc.errcode').info
local fields    = require('config.config').ab.fields


local separator = ':'

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

_M.set = function(self, domain, policy)

	local database = self.database
	local runtimeKey  = self.baseLibrary .. ':' .. domain 
	local ok, err = database:set(runtimeKey, policy)

	if not ok then error{ERRORINFO.REDIS_ERROR, err} end

	return ERRORINFO.SUCCESS
end

_M.del = function(self, domain)
    local database = self.database

	local runtimeKey = self.baseLibrary .. ':' .. domain
	local ok, err = database:del(runtimeKey)
    
    if not ok then error{ERRORINFO.REDIS_ERROR, err} end
end

_M.get = function(self, domain)
    local database = self.database
   
	local runtimeKey = self.baseLibrary .. ':' .. domain
    local response, err = database:get(runtimeKey)
    if not response then
        error{ERRORINFO.REDIS_ERROR, err}
    end
    
	ngx.log(ngx.ERR, response)
    return response
end

return _M
