local modulename = "abtestingActionUidrange"

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
	userinfo = tonumber(userinfo)
	if not userinfo then 
		return false, 'uid is not a valid number ' ..(userinfo or '') 
	end
	ngx.log(ngx.ERR, userinfo)

	for _, item in pairs(policy) do

		if userinfo >= item['start'] then
			if userinfo <= item['end'] then
				return item['action']
			end
		end

	end
	return nil
end

_M.op = function(self, policy, userinfo) 
	local action_set, err = _M.get_action(policy, userinfo)
--	ngx.log(ngx.ERR, cjson.encode(action_set))
	if not action_set then 
		ngx.log(ngx.ERR, 'get_action error for ', err)
		return false, err 
	end

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
_M.get = function(self, raw_policy)
	local policies = {}
	for _, item in pairs(raw_policy) do
		local policy = {}
		policy['action'] = item.action

		local range = item.range
		policy['start'] = range['start']
		policy['end'] = range['end']
		
		table.insert(policies, policy)
	end

	return policies
end

_M.check = function(self, policy)
--	ngx.log(ngx.ERR, cjson.encode(policy))
	if not policy or type(policy) ~= 'table' then
		return false, 'policy of uidappoint invalid'
	end

    table.sort(policy, function(n1, n2) return n1['range']['start'] < n2['range']['start'] end)
	
	local last_edip
	for idx, item in pairs(policy) do
		local range = item.range
		local action_set = item.action

		local l = tonumber(range['start'])
		local r = tonumber(range['end'])
		if not l or not r then
			return false, 'invalid range'
		end
		if l > r then
			return false, 'invalid range for l < r'
		end
		if idx > 1 then
			if l <= last_edip then
				return false, 'invalid range for overlapped'
			end
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
		last_edip = r
	end

	return true
end

return _M
