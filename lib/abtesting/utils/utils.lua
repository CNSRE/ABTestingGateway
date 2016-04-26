local modulename = "abtestingUtils"
local _M = {}
_M._VERSION = '0.0.1'

local cjson = require('cjson.safe')
local log	= require("abtesting.utils.log")
--将doresp和dolog，与handler统一起来。
--handler将返回一个table，结构为：
--[[
handler———errinfo————errcode————code
    |           |               |
    |           |               |————info
    |           |
    |           |————errdesc
    |
    |
    |
    |———errstack				 
]]--		

_M.dolog = function(info, desc, data, errstack)
--    local errlog = 'ab_admin '
    local errlog = ''
    local code, err = info[1], info[2]
    local errcode = code
    local errinfo = desc and err..desc or err 
    
    errlog = errlog .. 'code : '..errcode
    errlog = errlog .. ', desc : '..errinfo
    if data then
        errlog = errlog .. ', extrainfo : '..data
    end
    if errstack then
        errlog = errlog .. ', errstack : '..errstack
    end
	return errlog
end

_M.doresp = function(info, desc, data)
    local response = {}
    
    local code = info[1]
    local err  = info[2]
    response.code = code
    response.desc = desc and err..desc or err 
    if data then 
        response.data = data 
    end
    
    return cjson.encode(response)
end

_M.doerror = function(info, extrainfo)
    local errinfo   = info[1]
    local errstack  = info[2] 
    local err, desc = errinfo[1], errinfo[2]

    local dolog, doresp = _M.dolog, _M.doresp
    local errlog = dolog(err, desc, extrainfo, errstack)
	log:errlog(errlog)

    local response  = doresp(err, desc)
    return response
end

return _M
