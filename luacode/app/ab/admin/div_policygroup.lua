---
-- @classmod abtesting.adapter.policy
-- @release 0.0.1
local modulename = "abtestingAdminPolicyGroup"

local _M = { _VERSION = "0.0.1" }
local mt = { __index = _M }

local runtimeModule = require('abtesting.adapter.runtime')
local policyModule  = require('abtesting.adapter.policy')

local ERRORINFO		= require('misc.errcode').info
local redisModule   = require('misc.redis')
local systemConf    = require('config.config').ab
local handler       = require('misc.handler').handler
local utils         = require('misc.utils')
local log			= require('misc.log')
local ERRORINFO     = require('misc.errcode').info

local cjson         = require('cjson.safe')
local doresp        = utils.doresp
local dolog         = utils.dolog
local doerror       = utils.doerror

local divtypes      = systemConf.divtypes
local prefixConf    = systemConf.prefixConf
local policyLib     = prefixConf.policyLibPrefix
local runtimeLib    = prefixConf.runtimeInfoPrefix
local domain_name   = prefixConf.domainname

local policyGroupModule  = require('abtesting.adapter.policygroup')
local policyGroupLib     = prefixConf.policyGroupPrefix

local errhandler = function(info, desc)
	local response = doresp(info, desc)
	ngx.log(ngx.ERR, dolog(info, desc))
	ngx.say(response)
	return false 
end

local getPolicyGroupId = function(policyGroupId)
	local policyGroupId      = tonumber(policyGroupId)
	if not policyGroupId or policyGroupId < 0 then
		return errhandler(ERRORINFO.PARAMETER_TYPE_ERROR,
						"policyGroupId invalid")
	end
	return policyGroupId
end

local getPolicyGroup = function(postdata)

	ngx.log(ngx.ERR, postdata)
	local postData      = cjson.decode(postdata)

	if not postData then
		-- ERRORCODE.PARAMETER_ERROR
		return errhandler( ERRORINFO.PARAMETER_ERROR,
						'postData is not a json string')
	end

	local policy_cnt = 0
	local policyGroup = {}
	for k, v in pairs(postData) do
		policy_cnt = policy_cnt + 1

		local idx = tonumber(k)
		if not idx or type(v) ~= 'table' then
			return errhandler( ERRORINFO.PARAMETER_ERROR,
						'policyGroup error')
		end

		local policy = v
		local divtype = policy.divtype
		local divdata = policy.divdata

		if not divtype or not divdata then
			-- ERRORCODE.PARAMETER_NONE
			return errhandler( ERRORINFO.PARAMETER_NONE,
						"policy divtype or policy divdata")
		end

		if not divtypes[divtype] then
			-- ERRORCODE.PARAMETER_TYPE_ERROR
			return errhandler( ERRORINFO.PARAMETER_TYPE_ERROR,
						"unsupported divtype")
		end

		if policyGroup[idx] then
			--不能混淆，优先级不能重复
			return errhandler( ERRORINFO.PARAMETER_TYPE_ERROR ,
						"policy in policy group should not overlap")			
		end

		policyGroup[idx] = policy
	end

	if policy_cnt ~= #policyGroup then
		return errhandler( ERRORINFO.PARAMETER_TYPE_ERROR, 
						"index of policy in policy_group should be one by one")			
	end

	return policyGroup
end

_M.checkPolicy = function(option)
	local database = option.db
	local postdata = option.policy

	local policyGroup = getPolicyGroup(postdata)
	if not policyGroup then
		return false
	end

	local steps = #policyGroup
	if steps < 1 then 
		return errhandler( ERRORINFO.PARAMETER_NONE, 
						"blank policy group")					
	end
	ngx.say(steps)
	local pfunc = function()
		local policyGroupMod = policyGroupModule:new(database,
		policyGroupLib, policyLib)
		return policyGroupMod:check(policyGroup)
	end
	local status, info = xpcall(pfunc, handler)
	if not status then
		local response = doerror(info)
		ngx.say(response)
		return false
	end

	local chkout    = info
	local valid     = chkout[1]
	local err       = chkout[2]
	local desc      = chkout[3]

	if not valid then
		return errhandler(err, desc)		
	end

	return true
end

_M.check = function(option)
	local status = _M.checkPolicy(option)
	if not status then return end
	local response = doresp(ERRORINFO.SUCCESS)
	ngx.say(response)
	return true
end

_M.set = function(option)

	local status = _M.checkPolicy(option)
	if not status then return end

	local database = option.db
	local postdata = option.policy

	local policyGroup = getPolicyGroup(postdata)
	if not policyGroup then
		return false
	end

	local pfunc = function()
		local policyGroupMod = policyGroupModule:new(database,
		policyGroupLib, policyLib)
		return policyGroupMod:set(policyGroup)
	end
	local status, info = xpcall(pfunc, handler)
	if not status then
		local response = doerror(info)
		ngx.say(response)
		return false
	end

	local data = info
	local response = doresp(ERRORINFO.SUCCESS, _, data)
	ngx.say(response)
	return true
end

_M.get = function(option)
	local database = option.db
	local pgid = option.id

	local policyGroupId = getPolicyGroupId(pgid)
	if not policyGroupId then
		return false
	end

	local pfunc = function()
		local policyGroupMod = policyGroupModule:new(database,
		policyGroupLib, policyLib)
		return policyGroupMod:get(policyGroupId)
	end
	local status, info = xpcall(pfunc, handler)
	if not status then
		local response = doerror(info)
		ngx.say(response)
		return false
	end
	local data = info
	local response = doresp(ERRORINFO.SUCCESS, _, data)
	ngx.say(response)
	return true
end

_M.get_detail = function(option)
	local database = option.db
	local pgid = option.id

	local policyGroupId = getPolicyGroupId(pgid)
	if not policyGroupId then
		return false
	end

	local pfunc = function()
		local policyGroupMod = policyGroupModule:new(database,
		policyGroupLib, policyLib)

		local policy_group = policyGroupMod:get(policyGroupId)
		ngx.log(ngx.ERR, cjson.encode(policy_group))

		local groupid = policy_group.groupid
		local group = policy_group.group
		if not next(group) then
			return policy_group
		end

		local policy_mod = policyModule:new(database, policyLib)

		local group_data = {}
		for id, _ in pairs(group) do
			local policy = policy_mod:get(id)
			group_data[tostring(id)] = policy
		end

		policy_group.group = group_data
		ngx.log(ngx.ERR, cjson.encode(policy_group))
		return policy_group
	end
	local status, info = xpcall(pfunc, handler)
	if not status then
		local response = doerror(info)
		ngx.say(response)
		return false
	end
	local data = info
	local response = doresp(ERRORINFO.SUCCESS, _, data)
	ngx.say(response)
	return true
end


_M.del = function(option)
	local database = option.db
	local pgid = option.id

	local policyGroupId = getPolicyGroupId(pgid)
	if not policyGroupId then
		return false
	end

	local pfunc = function()
		local policyGroupMod = policyGroupModule:new(database,
		policyGroupLib, policyLib)
		return policyGroupMod:del(policyGroupId)
	end
	local status, info = xpcall(pfunc, handler)
	if not status then
		local response = doerror(info)
		ngx.say(response)
		return false
	end
	local response = doresp(ERRORINFO.SUCCESS)
	ngx.say(response)
	return true
end

return _M
