local modulename = "abtestingUtils"
local _M = {}
_M._VERSION = '0.0.1'

local cjson = require('cjson.safe')
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

local dolog = function(info, desc, data, errstack)
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

local doresp = function(info, desc, data)
    local resp = {}
    
    local code = info[1]
    local err  = info[2]
    resp.code = code
    resp.desc = desc and err..desc or err 
    if data then 
        resp.data = data 
    end
    
    return cjson.encode(resp)
end

local doerror = function(info, extrainfo)
    local errinfo   = info[1]
    local errstack  = info[2] 
    local err, desc = errinfo[1], errinfo[2]

    local dolog, doresp = _M.dolog, _M.doresp
    local errlog = dolog(err, desc, extrainfo, errstack)
	ngx.log(ngx.ERR, errlog)

    local resp  = doresp(err, desc)
    return resp
end

local errhandler = function(info, desc)
    local resp = doresp(info, desc)
	ngx.log(ngx.ERR, resp)
    ngx.say(resp)
    return false 
end
local getHost = function()

    local hostkey = ngx.var.hostkey
    if hostkey then
        return hostkey	
    else
		ngx.log(ngx.ERR, '[ab]', 'Caution nginx config no hostkey')
		return ngx.req.get_headers()['Host']
    end
end


_M.dolog = dolog
_M.doresp = doresp
_M.doerror = doerror
_M.defer = errhandler 
_M.getHost = getHost

return _M
