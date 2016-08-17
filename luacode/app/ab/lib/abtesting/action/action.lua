local modulename = "abtestingActionModule"

local _M    = {}
local mt    = { __index = _M }
_M._VERSION = "0.0.1"

local ERRORINFO		= require('misc.errcode').info
local semaphore		= require("misc.sema")
local systemConf    = require('config.config').ab

local cjson			= require('cjson.safe')

local divtypes		= systemConf.divtypes

--[[
policy | 1: | acttype : uidsuffix 
	   |	|
	   |	| actdata : |	'0' : 
	   |	|			|
	   |	|			|	'5' : 	| 'add' : ['k1', 'v1']
	   |				|			| 
	   |				|			| 'del' : ['k2']
	   |
	   |
	   |
	   |
--]]

--[[
runtime | 1: | userinfomodele : abtesting.userinfo.uidsuffix
	    |	 | action_policy: {}
	    |	 |
	    |	 |
	    |	 |
	    |	 |
	    |	 |
	    |
	    |
	    |
	    |
--]]


_M.get_runtime = function(db, cache, key)

	local sema = semaphore.get_action_sema()
	local runtimes, err = _M.get_from_cache(cache, key)
	if not runtimes then
		local sem, err = sema:wait(0.01)
		if not sema then

		end

		runtimes, err = _M.get_from_cache(cache, key)

		if not runtimes then
			runtimes = _M.get_from_db(db, cache, key)
		else
			if sema then sema:post(1) end
			return runtimes
		end
		if sema then sema:post(1) end
	end
	return runtimes
end

_M.get_from_cache = function(cache, key)

	local runtime = cache:get(key)
	if not runtime then
		-- log:debug('action runtime does not exist in cache,
		--						and is needed to fetch from db')
	elseif runtime == -1 then
		-- log:debug('action runtime switch off')
	else
		-- log:debug('get runtime info from cache: ', runtime)
	end
	return runtime

end

_M.get_from_db = function( db, cache, rkey)

	local policy_json, err = db:get(rkey)
	if not policy_json then
		error{ERRORINFO.REDIS_ERROR, err}
	end

	if policy_json == ngx.null then -- pkey doesn't exist in db
		-- log:debug('runtime info does not exist in db, action switch off')
		cache:set(rkey, -1)
		return -1
	end
	
	local policies = cjson.decode(policy_json)
	if type(policies) ~= 'table' then
		error{ERRORINFO.LUA_RUNTIME_ERROR, 'action policy invalid'}
	end

	local runtimes = {}
	for k, policy in pairs(policies) do
		local runtime = {}
		local userinfo_parser = divtypes[policy.acttype]
		local action_module = 'abtesting.action.' .. policy.acttype
		local userinfo_module = 'abtesting.userinfo.' .. userinfo_parser
		local action_mod = require(action_module)
		local action_policy = action_mod:get(policy.actdata)

		runtime.action_module = action_module
		runtime.userinfo_module = userinfo_module
		runtime.action_policy = action_policy
		runtimes[k] = runtime
	end

	cache:set(rkey, runtimes)
	return runtimes
end

_M.process = function(runtimes)
	for k, runtime in pairs(runtimes) do
		local userinfo = _M.get_userinfo(runtime)		
		local policy = runtime.action_policy
		local action_module = require(runtime.action_module)
		action_module:op(policy, userinfo)
	end
end

_M.get_userinfo = function(runtime)
	local userinfo_module = require(runtime.userinfo_module)
	local userinfo = userinfo_module:get()
	return userinfo
end

return _M

