
local _M = {
    _VERSION = '0.01'
}

_M.get = function()
	local u = ngx.req.get_headers()["X-Uid"]
	return u
end
return _M
