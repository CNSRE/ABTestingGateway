-- Copyright (C) Yichun Zhang (agentzh)
-- Copyright (C) cuiweixie
-- I hereby assign copyright in this code to the lua-resty-core project,
-- to be licensed under the same terms as the rest of the code.


local ffi = require 'ffi'
local base = require "resty.core.base"


local FFI_OK = base.FFI_OK
local FFI_ERROR = base.FFI_ERROR
local FFI_DECLINED = base.FFI_DECLINED
local ffi_new = ffi.new
local ffi_str = ffi.string
local ffi_gc = ffi.gc
local C = ffi.C
local type = type
local error = error
local tonumber = tonumber
local getfenv = getfenv
local get_string_buf = base.get_string_buf
local get_size_ptr = base.get_size_ptr
local setmetatable = setmetatable
local co_yield = coroutine._yield
local ERR_BUF_SIZE = 128


local errmsg = base.get_errmsg_ptr()


ffi.cdef[[
    struct ngx_http_lua_semaphore_s;
    typedef struct ngx_http_lua_semaphore_s ngx_http_lua_semaphore_t;

    int ngx_http_lua_ffi_semaphore_new(ngx_http_lua_semaphore_t **psem,
        int n, char **errmsg);

    int ngx_http_lua_ffi_semaphore_post(ngx_http_lua_semaphore_t *sem, int n);

    int ngx_http_lua_ffi_semaphore_count(ngx_http_lua_semaphore_t *sem);

    int ngx_http_lua_ffi_semaphore_wait(ngx_http_request_t *r,
        ngx_http_lua_semaphore_t *sem, int wait_ms,
        unsigned char *errstr, size_t *errlen);

    void ngx_http_lua_ffi_semaphore_gc(ngx_http_lua_semaphore_t *sem);
]]


local psem = ffi_new("ngx_http_lua_semaphore_t *[1]")


local _M = { version = base.version }
local mt = { __index = _M }


function _M.new(n)
    n = tonumber(n) or 0
    if n < 0 then
        return error("no negative number")
    end

    local ret = C.ngx_http_lua_ffi_semaphore_new(psem, n, errmsg)
    if ret == FFI_ERROR then
        return nil, ffi_str(errmsg[0])
    end

    local sem = psem[0]

    ffi_gc(sem, C.ngx_http_lua_ffi_semaphore_gc)

    return setmetatable({ sem = sem }, mt)
end


function _M.wait(self, seconds)
    if type(self) ~= "table" or type(self.sem) ~= "cdata" then
        return error("not a semaphore instance")
    end

    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    local milliseconds = tonumber(seconds) * 1000
    if milliseconds < 0 then
        return error("no negative number")
    end

    local cdata_sem = self.sem

    local err = get_string_buf(ERR_BUF_SIZE)
    local errlen = get_size_ptr()
    errlen[0] = ERR_BUF_SIZE

    local ret = C.ngx_http_lua_ffi_semaphore_wait(r, cdata_sem,
                                                  milliseconds, err, errlen)

    if ret == FFI_ERROR then
        return nil, ffi_str(err, errlen[0])
    end

    if ret == FFI_OK then
        return true
    end

    if ret == FFI_DECLINED then
        return nil, "timeout"
    end

    return co_yield()
end


function _M.post(self, n)
    if type(self) ~= "table" or type(self.sem) ~= "cdata" then
        return error("not a semaphore instance")
    end

    local cdata_sem = self.sem

    local num = n and tonumber(n) or 1
    if num < 1 then
        return error("no negative number")
    end

    -- always return NGX_OK
    C.ngx_http_lua_ffi_semaphore_post(cdata_sem, num)

    return true
end


function _M.count(self)
    if type(self) ~= "table" or type(self.sem) ~= "cdata" then
        return error("not a semaphore instance")
    end

    return C.ngx_http_lua_ffi_semaphore_count(self.sem)
end


return _M
