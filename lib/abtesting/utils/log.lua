local log = ngx.log

local ERR = ngx.ERR
local INFO = ngx.INFO
local WARN = ngx.WARN
local DEBUG = ngx.DEBUG

local _M = {}
local mt = {__index = _M}
_M._VERSION = "0.01"

_M.new = function (self, hostname)
	self.tag = hostname
	return setmetatable(self, mt)
end

function _M.info(self, ...)
    log(INFO, "ab_div host [", self.tag or 'ab_admin',"] ", ...)
end


function _M.warn(self, ...)
    log(WARN, "ab_div host [", self.tag or 'ab_admin',"] ", ...)
end


function _M.errlog(self, ...)
    log(ERR, "ab_div host [", self.tag or 'ab_admin',"] ", ...)
end


function _M.debug(self, ...)
    log(DEBUG, "ab_div host [", self.tag or 'ab_admin',"] ", ...)
end


return _M
