local modulename = "abtestingLRUCache"
local _M = {}
_M._VERSION = '0.0.1'

local lrucache = require "misc.resty.lrucache"
-- local lrucache = require "misc.resty.lrucache.pureffi"

local cache, err = lrucache.new(200)  -- allow up to 200 items in the cache
if not cache then
	error("failed to create the cache: " .. (err or "unknown"))
end

_M.cache = cache

return _M
