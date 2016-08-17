local redis		= require('misc.redis')
local utils		= require('misc.utils')
local ERRORINFO	= require('misc.errcode').info
local handler	= require('misc.handler').handler
local config	= require('config.config').ab

local dolog         = utils.dolog	
local doerror       = utils.doerror
local getHost		= utils.getHost
local redis_conf	= config.redisConf

local upstream      = nil

local pfunc = function()
	local hostname = getHost()
	local runtime_module = require("ab.diversion.div.runtime")
	local upstream_module = require("ab.diversion.div.upstream")
	local runtime = runtime_module:new(hostname)
	local upstream = upstream_module:new(hostname)

	local divstep, runtimegroup = runtime:get()
	if not divstep or divstep == -1 then
		return nil, 'div switch off' 
	end

	local ups = upstream:get(divstep, runtimegroup)
	return ups
end

local ok, ret = xpcall(pfunc, handler)
if not ok then
    doerror(ret)
else
	upstream = ret
end

if upstream then
    ngx.var.backend = upstream
end

local desc = 'proxypass to upstream http://' .. upstream or ngx.var.backend
local info = dolog(ERRORINFO.SUCCESS, desc)
ngx.log(ngx.ERR, info)
redis:close(redis_conf)
