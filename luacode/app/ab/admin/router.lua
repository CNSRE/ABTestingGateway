local redis			= require('misc.redis')
local systemConf    = require('config.config').ab
local utils         = require('misc.utils')
local cjson			= require('cjson.safe')

local policy        = require("ab.admin.div_policy")
local runtime       = require('ab.admin.div_runtime')
local policygroup   = require("ab.admin.div_policygroup")

local action_policy = require("ab.admin.action_policy")
local action_runtime= require("ab.admin.action_runtime")
local utils			= require("ab.admin.utils")

local doresp        = utils.doresp
local dolog         = utils.dolog

local divtypes      = systemConf.divtypes
local prefixConf    = systemConf.prefixConf
local policyLib     = prefixConf.policyLibPrefix
local runtimeLib    = prefixConf.runtimeInfoPrefix
local domain_name   = prefixConf.domainname

local redis_conf	= systemConf.redisConf

local wrapper = function(f, args)
	local db, err = redis:getClient(redis_conf)
	if not db then
	    local response = doresp(ERRORINFO.REDIS_ERROR, err)
		ngx.log(ngx.ERR, response)
	    return ngx.say(response)
	end
	
	args.db = db
	f(args)

	redis:close()
end

local notyet = function()
	local resp = {}
	resp.code = 500
	resp.desc = 'interface not avaliable'
	ngx.say(cjson.encode(resp))
end


local _policy		= {}
_policy.get			= function(id)		 wrapper(policy.get,   { id = id }) end
_policy.del			= function(id)		 wrapper(policy.del,   { id = id }) end
_policy.set			= function(postdata) wrapper(policy.set,   { policy = postdata }) end
_policy.check		= function(postdata) wrapper(policy.check, { policy = postdata }) end
_policy.getall		= function() notyet() end

local _policygroup	= {}
_policygroup.get	= function(id)		 wrapper(policygroup.get,   { id = id }) end
_policygroup.del	= function(id)		 wrapper(policygroup.del,   { id = id }) end
_policygroup.set	= function(postdata) wrapper(policygroup.set,   { policy = postdata }) end
_policygroup.check	= function(postdata) wrapper(policygroup.check, { policy = postdata }) end
_policygroup.getall	= function() notyet() end

_policygroup.get_detail	= function(id)	 wrapper(policygroup.get_detail,   { id = id }) end

local _runtime = {}
_runtime.get		= function(host)	 wrapper(runtime.get, { hostname = host }) end
_runtime.del 		= function(host)	 wrapper(runtime.del, { hostname = host }) end
-- _runtime.set 		= function(host, id) wrapper(runtime.set, { hostname = host, id = id }) end
_runtime.groupset	= function(host, id) wrapper(runtime.groupset, { hostname = host, id = id }) end

local _action_policy = {}
_action_policy.get		= function(id)		 wrapper(action_policy.get,   { id = id }) end
_action_policy.del		= function(id)		 wrapper(action_policy.del,   { id = id }) end
_action_policy.set		= function(postdata) wrapper(action_policy.set,   { policy = postdata }) end
_action_policy.check	= function(postdata) wrapper(action_policy.check, { policy = postdata }) end
_action_policy.getall	= function(postdata) notyet() end

local _action_runtime = {}
_action_runtime.get		= function(host)		wrapper(action_runtime.get,   { hostname = host}) end
_action_runtime.del		= function(host)		wrapper(action_runtime.del,   { hostname = host}) end
_action_runtime.set		= function(host, id)	wrapper(action_runtime.set,   { hostname = host, id = id }) end

local _action = {}
_action.policy	= _action_policy
_action.runtime	= _action_runtime

local _utils = {}
_utils.get_all_divtype = function() utils.get_all_divtype() end

local admin = {
	policy		= _policy,
	policygroup = _policygroup,
	runtime		= _runtime,
	utils		= _utils,
	action		= _action,
}

return admin
