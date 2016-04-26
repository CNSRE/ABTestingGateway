local modulename = "abtestingSema"
local _M = {}

local semaphore = require("lua-resty-core.lib.ngx.semaphore")

_M.sema = semaphore.new(1)
_M.upsSema = semaphore.new(1)

return _M
