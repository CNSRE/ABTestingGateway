
local router = require "misc.router"
local wafmod = require "waf.waf"
local ab	= require "ab.admin.router"
local cjson	= require "cjson.safe"

local r = router.new()
local waf = wafmod.new()

r:match({
	GET = {
		-- waf
		["/admin/waf/get_banip_in_range/:st"]		= function(params) waf.get_banip_in_range(params.st) end,
		["/admin/waf/get_banip_in_range/:st/:ed"]	= function(params) waf.get_banip_in_range(params.st, params.ed) end,
		["/admin/waf/get_range_in_banip/:ip"]		= function(params) waf.get_range_in_banip(params.ip) end,
		["/admin/waf/get_baned_total_num/:st/:ed"]	= function(params) waf.get_baned_total_num(params.st, params.ed) end,
		["/admin/waf/get_baned_total_num/:base"]	= function(params) waf.get_baned_total_num(params.base) end,
		["/admin/waf/get_baned_total_num"]			= function(params) waf.get_baned_total_num() end,
		["/admin/waf/whitelist/get"]				= function(params) waf.get_whitelist() end,
		["/admin/waf/get_banip"]					= function(params) waf.get_banip() end,

		-- dyupsc
--		["/admin/dyups/"]		= function(params) waf.get_banip_in_range(params.st) end,

		-- ab
		-- div policy
		["/admin/ab/policy/get/:id"]				= function(params) ab.policy.get(params.id) end,
		["/admin/ab/policy/del/:id"]				= function(params) ab.policy.del(params.id) end,
		["/admin/ab/policy/getall"]					= function(params) ab.policy.getall() end,

		-- div group
		["/admin/ab/policygroup/get/:id"]			= function(params) ab.policygroup.get(params.id)  end,
		["/admin/ab/policygroup/get/detail/:id"]	= function(params) ab.policygroup.get_detail(params.id)  end,
		["/admin/ab/policygroup/del/:id"]			= function(params) ab.policygroup.del(params.id)  end,
		["/admin/ab/policygroup/getall"]			= function(params) ab.policygroup.getall(params.id)  end,

		-- div runtime
		-- set policygroup as runtime info
		["/admin/ab/runtime/set/2/:hostname/:id"]	= function(params) ab.runtime.groupset(params.hostname, params.id) end,
		["/admin/ab/runtime/get/:hostname"]			= function(params) ab.runtime.get(params.hostname) end,
		["/admin/ab/runtime/del/:hostname"]			= function(params) ab.runtime.del(params.hostname) end,

		-- action policy
		["/admin/ab/action/policy/get/:id"]					= function(params) ab.action.policy.get(params.id) end,
		["/admin/ab/action/policy/del/:id"]					= function(params) ab.action.policy.del(params.id) end,
		["/admin/ab/action/policy/getall"]					= function(params) ab.action.policy.getall() end,

		-- action runtime
		["/admin/ab/action/runtime/set/:hostname/:id"]		= function(params) ab.action.runtime.set(params.hostname, params.id) end,
		["/admin/ab/action/runtime/get/:hostname"]			= function(params) ab.action.runtime.get(params.hostname) end,
		["/admin/ab/action/runtime/del/:hostname"]			= function(params) ab.action.runtime.del(params.hostname) end,

		-- utils 
		["/admin/ab/host/getall"]		= function(params) ab.utils.get_all_host() end,
		["/admin/ab/divtype/getall"]	= function(params) ab.utils.get_all_divtype() end,
	},
	POST = {
		-- waf
		["/admin/waf/policy/set"]		= function(params) waf.set(params.rules) end,
		["/admin/waf/policy/del"]		= function(params) waf.del(params.rules) end,
		["/admin/waf/whitelist/set"]	= function(params) waf.white_set(params.rules) end,
		["/admin/waf/whitelist/del"]	= function(params) waf.white_del(params.rules) end,

		-- div policy & policy_group
		["/admin/ab/policy/set"]		= function(params) ab.policy.set(params.policy) end,
		["/admin/ab/policy/check"]		= function(params) ab.policy.check(params.policy) end,
		["/admin/ab/policygroup/set"]	= function(params) ab.policygroup.set(params.policy)  end,
		["/admin/ab/policygroup/check"]	= function(params) ab.policygroup.check(params.policy)  end,

		-- action policy
		["/admin/ab/action/policy/set"]		= function(params) ab.action.policy.set(params.policy) end,
		["/admin/ab/action/policy/check"]	= function(params) ab.action.policy.check(params.policy)end,
	},
})

-- ngx.log(ngx.ERR, ngx.var.request_uri)

local ok, errmsg = r:execute(
	ngx.var.request_method,
	ngx.var.request_uri,
	ngx.req.get_uri_args(),  -- all these parameters
	ngx.req.get_post_args(), -- will be merged in order
	{other_arg = 1}         -- into a single "params" table
)

if not ok then
	ngx.status = 404
	local resp = {}
	resp.code = 500
	resp.data = "location or args not valid"

	local msg = cjson.encode(resp)

	ngx.log(ngx.ERR, msg)
	ngx.say(msg)
end
