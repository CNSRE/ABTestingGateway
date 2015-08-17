
local _M = {
    _VERSION = '0.01'
}

local ffi = require("ffi")

ffi.cdef[[
struct in_addr {
    uint32_t s_addr;
};

int inet_aton(const char *cp, struct in_addr *inp);
uint32_t ntohl(uint32_t netlong);

char *inet_ntoa(struct in_addr in);
uint32_t htonl(uint32_t hostlong);
]]

local C = ffi.C

local ip2long = function(ip)
    local inp = ffi.new("struct in_addr[1]")
    if C.inet_aton(ip, inp) ~= 0 then
        return tonumber(C.ntohl(inp[0].s_addr))
    end
    return nil
end

local long2ip = function(long)
    if type(long) ~= "number" then
        return nil
    end
    local addr = ffi.new("struct in_addr")
    addr.s_addr = C.htonl(long)
    return ffi.string(C.inet_ntoa(addr))
end



_M.get = function()
    local ClientIP = ngx.req.get_headers()["X-Real-IP"]
    if ClientIP == nil then
        ClientIP = ngx.req.get_headers()["X-Forwarded-For"]
        if ClientIP then
            local colonPos = string.find(ClientIP, ' ')
            if colonPos then
                ClientIP = string.sub(ClientIP, 1, colonPos - 1) 
            end
        end
    end
    if ClientIP == nil then
        ClientIP = ngx.var.remote_addr
    end
    if ClientIP then 
        ClientIP = ip2long(ClientIP)
    end
    return ClientIP
end


return _M


