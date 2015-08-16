
--local user = require "weibo.ban.user"
local _M = {
    _VERSION = '0.01'
}

_M.get = function()
	local u = ngx.req.get_headers()["X-Log-Uid"]
	return u
end
return _M
