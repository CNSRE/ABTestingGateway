---
-- @classmod abtesting.adapter.policy
-- @release 0.0.1
local modulename = "abtestingAdapterAction"

local _M = { _VERSION = "0.0.1" }
local mt = { __index = _M }

local ERRORINFO = require('misc.errcode').info
local fields    = require('config.config').ab.fields

local cjson		= require('cjson.safe')

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
-- addtion a policy to specified redis lib
-- @param policy policy of addtion
-- @return allways returned SUCCESS
_M.set = function(self, policy)
    local id = self:getIdCount()
    local database = self.database
	local action_key = self.baseLibrary .. ':' .. id
	local ok, err = database:set(action_key, policy)
    if err then error{ERRORINFO.REDIS_ERROR, err} end
--    local divModulename = table.concat({'abtesting', 'diversion', policy.divtype}, '.')
--    
--    self:_setDivtype(id, policy.divtype)
--    self:_setDivdata(id, policy.divdata, divModulename)
    
    return id
end

_M.check = function(self, policydata)
	local policies = cjson.decode(policydata)
	if not policies then 
		return false, 'policydata is not a json' 
	end

	for idx, policy in pairs(policies) do

		-- TODO：检查是否是合法的acttype
		--
	    local action_module_name = table.concat({'abtesting', 'action', policy.acttype}, '.')
--		ngx.log(ngx.ERR, action_module_name)
	    local action_module = require(action_module_name)
--		ngx.log(ngx.ERR, cjson.encode(policy.actdata))
		local ok, err = action_module:check(policy.actdata)

		if not ok then 
			return ok, 'No. '.. idx .. ' policy invalid for: '.. ( err or '')
		end

	end
	return true
end

_M.get = function(self, id)
    local database	= self.database
	local actionKey	= self.baseLibrary .. ':' .. id
	local policy	= ""

    local action_str, err  = database:get(actionKey)
    if not action_str then
        error{ERRORINFO.REDIS_ERROR, err} 
    elseif action_str == ngx.null then
        return policy
    end
	local policy = action_str

--	local policy = cjson.decode(action_str)

    return policy
end

_M.del = function(self, id)
    local database	= self.database
	local actionKey	= self.baseLibrary .. ':' .. id
	local policy	= ""

    local action_str, err  = database:del(actionKey)
    if err then error{ERRORINFO.REDIS_ERROR, err} end
end


return _M
