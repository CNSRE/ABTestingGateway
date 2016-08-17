local modulename = "abtestingActionUidappoint"

local _M    = {}
local mt    = { __index = _M }
_M._VERSION = "0.0.1"

local ERRORINFO	= require('misc.errcode').info
local cjson		= require('cjson.safe')
local operation = require('abtesting.action.operation')

local k_uid     = 'uid'
local k_uidset  = 'uidset'
local k_upstream= 'upstream'

_M.get_action = function(policy, userinfo)
	for _, item in pairs(policy) do
		local uidset = item.uidset
		userinfo = tonumber(userinfo) or userinfo
		if uidset[userinfo] then
			return item.action
		end
	end
	return nil
end

_M.op = function(self, policy, userinfo) 
	local action_set = _M.get_action(policy, userinfo)
--	ngx.log(ngx.ERR, cjson.encode(action_set))
	if not action_set then return end

	for action, args in pairs(action_set) do
--		ngx.log(ngx.ERR, action)
		local action_mod = operation:new(action)
		if not action_mod then 
			ngx.log(ngx.ERR, 'invalid action: '.. (action or ''))
			return false, 'invalid action: '.. (action or '')
		end
		local ok, err = action_mod.op(args)
		if not ok then return ok, err end
	end
end

-- 将policy转为更加lua table友好的形式
_M.get = function(self, policy)
	for _, item in pairs(policy) do
		local uidset = item.uidset
		local newset = {}
		for _, uid in pairs(uidset) do
			newset[uid] = 1
		end
		item.uidset = newset
	end

	return policy
end

_M.check = function(self, policy)
--	ngx.log(ngx.ERR, cjson.encode(policy))
	if not policy or type(policy) ~= 'table' then
		return false, 'policy of uidappoint invalid'
	end

	for _, item in pairs(policy) do
		local uidset = item.uidset
		local action_set = item.action

		for _, uid in pairs(uidset) do
			-- uid almost be true
		end

		for action, args in pairs(action_set) do
--			ngx.log(ngx.ERR, cjson.encode(action))
--			ngx.log(ngx.ERR, cjson.encode(args))
			local action_mod = operation:new(action)
			if not action_mod then 
				return false, 'invalid action: '.. (action or '')
			end
			local ok, err = action_mod.check(args)
			if not ok then return ok, err end
		end
	end
	return true
end

return _M
