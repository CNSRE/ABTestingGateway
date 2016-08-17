local modulename = "abtestingRedis"
local _M = {}

_M._VERSION = '0.0.1'

local ERRORINFO	= require('misc.errcode').info
local redis = require('misc.resty.redis')

-- local CONFIG = require('abtesting.utils.init')
-- local conf = CONFIG.redisConf
-- 暂时改成这样子
-- local conf = {
--         host = '127.0.0.1',
-- 		port = '6379',
-- 		timeout = 10000,
-- 		dbid = 0,
-- 		poolsize = 1000,
-- 		idletime = 90000,
-- }

local Redis = {}

_M.getClient = function(self, conf)
	if ngx.ctx[Redis] then
		return ngx.ctx[Redis]
	end

	local red, err = redis:new()
	if not red then
		return red, err
--        error{ERRORINFO.REDIS_ERROR, err}
	end

    local host       = conf.host
    local port       = conf.port
    local uds        = conf.uds
    local timeout    = conf.timeout
    local dbid       = conf.dbid

    if not uds and not (host and port) then
		return nil, 'no uds or tcp avaliable provided'
--		error{ERRORINFO.REDIS_PARAMETER_ERROR, 
--					'no uds or tcp avaliable provided'}
    end

    if not dbid then 
		dbid = 0		-- select db 0
	end

    if not timeout then 
        timeout = 1000  -- connect timeout for 10s
    end

    red:set_timeout(timeout)

    local ok, err 

    if uds then
        ok, err = red:connect('unix:'..uds)
    end

	if not ok and ( host and port ) then
        ok, err = red:connect(host, port)
	end

	if not ok then
		return ok, err
--        error{ERRORINFO.REDIS_CONNECT_ERROR, err} 
	end

	red:select(dbid)

	ngx.ctx[Redis] = red
	return ngx.ctx[Redis]

end

_M.close = function(self, conf)

	if ngx.ctx[Redis] then
		local red = ngx.ctx[Redis]

		local idle_time = conf and conf.idletime or 90000 --毫秒
		local pool_size = conf and conf.poolsize or 1000 --连接池大小
		red:set_keepalive(idle_time, pool_size)  

		ngx.ctx[Redis] = nil
	end
end

return _M
