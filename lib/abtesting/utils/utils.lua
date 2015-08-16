local modulename = "abtestingUtils"
local _M = {}
_M._VERSION = '0.0.1'

local cjson = require('cjson.safe')
--将doresp和dolog，与handler统一起来。handler将返回一个table，结构为：
--[[
handler———errinfo————errcode————code
    |       |               |
    |       |               |————info
    |       |
    |       |————errdesc
    |
    |
    |
    |———errstack				 
]]--		
_M.dolog = function(info, desc, data, errstack)
	local errlog = ''
	local code, err = info[1], info[2]
	local errcode = code
	local errinfo = desc and err..desc or err 

	errlog = errlog .. ' errcode : '..errcode
	errlog = errlog .. ', errinfo : '..errinfo
	if data then
		errlog = errlog .. ', extrainfo : '..data
	end
	if errstack then
		errlog = errlog .. ', errstack : '..errstack
	end
	ngx.log(ngx.ERR, errlog)
end

_M.doresp = function(info, desc, data)
	local response = {}

	local code = info[1]
	local err  = info[2]
	response.errcode = code
	response.errinfo = desc and err..desc or err 
	if data then 
		response.data = data 
	end

	return cjson.encode(response)
end

return _M
