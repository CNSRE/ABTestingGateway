
local modulename = "ab.admin.action.utils"

local _M = { _VERSION = "0.0.1" }

local system_conf	= require('config.config').ab
local cjson			= require('cjson.safe')

_M.get_all_divtype = function()
	local resp = {}
	resp.code = 200
	resp.data = system_conf.divtypes

	ngx.say(cjson.encode(resp))
end

return _M


