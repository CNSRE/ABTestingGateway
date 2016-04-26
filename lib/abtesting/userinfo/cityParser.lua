
local _M = {
    _VERSION = '0.01'
}

_M.get = function()
	local u = ngx.var.arg_city
    ngx.log(ngx.ERR, u)
	return u
end
return _M
