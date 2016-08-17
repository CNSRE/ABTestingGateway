local modulename = "abtestingActionOperation"

local _M    = {}
local mt    = { __index = _M }
_M._VERSION = "0.0.1"

local op_header_set = {}

op_header_set.op = function(args)
	local key = args[1]
	local val = args[2]

	ngx.req.set_header(key, val)

	return true
end

op_header_set.check = function(args)
	local key = args[1]
	local val = args[2]
--	ngx.log(ngx.ERR, 'key:', key, 'val:', val)
	-- 还要检查是否符合 header 头部字段长度
	if not key then 
		return false, 'key error'
	end
	if not val then
		return false, 'val error'
	end
	return true
end


local op_header_del = {}

op_header_del.check = function(args)
	local key = args[1]
	-- 还要检查是否符合 header 头部字段长度
	if not key then 
		return false, 'key error'
	end
	return true
end

op_header_del.op = function(args)
	local key = args[1]
	ngx.req.set_header(key, nil)
	return true
end


local op_arg_del = {}

op_arg_del.check = function(args)
	local key = args[1]
	-- 还要检查是否符合 header 头部字段长度
	if not key then 
		return false, 'key error'
	end
	return true
end

op_arg_del.op = function(args)
	local key = args[1]

	local args = ngx.req.get_uri_args()

	args[key] = nil 
	ngx.req.set_uri_args(args)
	return true
end


local op_arg_set = {}

op_arg_set.check = function(args)
	local key = args[1]
	local val = args[2]
	-- 还要检查是否符合 header 头部字段长度
	if not key then 
		return false, 'key error'
	end
	if not val then
		return false, 'val error'
	end
	return true
end

op_arg_set.op = function(args)
	local key = args[1]
	local val = args[2]

	local args = ngx.req.get_uri_args()
	args[key] = val

	ngx.req.set_uri_args(args)
end


local operation  = {
	header_set = op_header_set,
	header_del = op_header_del,
	arg_set	= op_arg_set,
	arg_del = op_arg_del,
}

_M.new = function(self, action)
	return operation[action]
end

return _M
