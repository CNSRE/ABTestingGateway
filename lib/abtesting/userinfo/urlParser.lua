
local modulename = "abtestingUserinfoUrlParser"
local _M = {
    _VERSION = '0.01'
}


_M.get = function()
    return ngx.var.uri
end


return _M


