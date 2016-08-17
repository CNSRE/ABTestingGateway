local _M = {
	_VERSION = '0.01'
}

_M.get = function()
	local args = ngx.req.get_post_args()
	if args and type(args) == 'table' then
		return args['cur_uid']
	else
		return nil
	end
end
return _M

