
local actionkey		= 'ab:runtime:action:api.weibo.cn'
local pfunc = function()
	local cache = lrucache
	local key = actionkey
	local runtimes, err = actionModule.get_from_cache(cache, key)
--	local runtimes, err = lrucache:get(key)
	if not runtimes then
		local sema = semaphore.get_action_sema()
		local sem, err = sema:wait(0.01)
		if not sema then

		end

		runtimes, err = actionModule.get_from_cache(cache, key)
--		local runtimes, err = lrucache:get(key)

		if not runtimes then
 			local db, err = redis:getClient(redis_conf)
			if not db then return end
			runtimes = actionModule.get_from_db(db, cache, key)
--			ngx.log(ngx.ERR, 'get actionruntime from db')
		end
		-- bug
		-- bug
		-- bug
		-- three times
--		ngx.log(ngx.ERR, cjson.encode(runtimes), type(runtimes))

		if sema then sema:post(1) end

	elseif runtimes == -1 then
--		ngx.log(ngx.ERR, 'action runtime switch off')
		return 
	end

	if not runtimes or type(runtimes) ~= 'table' then 
		ngx.log(ngx.ERR, 'action runtime get failed from db and cache')
		return 
	end

	actionModule.process(runtimes)

end

local status, info, desc = xpcall(pfunc, handler)
if not status then
    doerror(info)
end


