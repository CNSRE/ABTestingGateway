# vim:set ft=ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(10140);
#workers(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 6 + 1);

our $CWD = cwd();

no_long_string();
#no_diff();

$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$::CWD/lib/?.lua;;";
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

run_tests();

__DATA__

=== TEST 1: clear certs
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"
            ssl.clear_certs()
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(nil, "test.com", true)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))

                local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
                local bytes, err = sock:send(req)
                if not bytes then
                    ngx.say("failed to send http request: ", err)
                    return
                end

                ngx.say("sent http request: ", bytes, " bytes.")

                while true do
                    local line, err = sock:receive()
                    if not line then
                        -- ngx.say("failed to recieve response status line: ", err)
                        break
                    end

                    ngx.say("received: ", line)
                end

                local ok, err = sock:close()
                ngx.say("close: ", ok, " ", err)
            end  -- do
            -- collectgarbage()
        }
    }

--- request
GET /t
--- response_body
connected: 1
failed to do SSL handshake: handshake failed

--- error_log
lua ssl server name: "test.com"
sslv3 alert handshake failure

--- no_error_log
[alert]
[emerg]



=== TEST 2: set DER cert and private key
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            ssl.clear_certs()

            local f = assert(io.open("t/cert/test.crt.der"))
            local cert_data = f:read("*a")
            f:close()

            local ok, err = ssl.set_der_cert(cert_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER cert: ", err)
                return
            end

            local f = assert(io.open("t/cert/test.key.der"))
            local pkey_data = f:read("*a")
            f:close()

            local ok, err = ssl.set_der_priv_key(pkey_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER cert: ", err)
                return
            end
        }
        ssl_certificate ../../cert/test2.crt;
        ssl_certificate_key ../../cert/test2.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(nil, "test.com", true)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))

                local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
                local bytes, err = sock:send(req)
                if not bytes then
                    ngx.say("failed to send http request: ", err)
                    return
                end

                ngx.say("sent http request: ", bytes, " bytes.")

                while true do
                    local line, err = sock:receive()
                    if not line then
                        -- ngx.say("failed to recieve response status line: ", err)
                        break
                    end

                    ngx.say("received: ", line)
                end

                local ok, err = sock:close()
                ngx.say("close: ", ok, " ", err)
            end  -- do
            -- collectgarbage()
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: userdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
close: 1 nil

--- error_log
lua ssl server name: "test.com"

--- no_error_log
[error]
[alert]
[emerg]



=== TEST 3: read SNI name via ssl.server_name()
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"
            print("read SNI name from Lua: ", ssl.server_name())
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(nil, "test.com", true)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))

                local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
                local bytes, err = sock:send(req)
                if not bytes then
                    ngx.say("failed to send http request: ", err)
                    return
                end

                ngx.say("sent http request: ", bytes, " bytes.")

                while true do
                    local line, err = sock:receive()
                    if not line then
                        -- ngx.say("failed to recieve response status line: ", err)
                        break
                    end

                    ngx.say("received: ", line)
                end

                local ok, err = sock:close()
                ngx.say("close: ", ok, " ", err)
            end  -- do
            -- collectgarbage()
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: userdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
close: 1 nil

--- error_log
lua ssl server name: "test.com"
read SNI name from Lua: test.com

--- no_error_log
[error]
[alert]



=== TEST 4: read SNI name via ssl.server_name() when no SNI name specified
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"
            local name = ssl.server_name(),
            print("read SNI name from Lua: ", name, ", type: ", type(name))
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(nil, nil, true)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))

                local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
                local bytes, err = sock:send(req)
                if not bytes then
                    ngx.say("failed to send http request: ", err)
                    return
                end

                ngx.say("sent http request: ", bytes, " bytes.")

                while true do
                    local line, err = sock:receive()
                    if not line then
                        -- ngx.say("failed to recieve response status line: ", err)
                        break
                    end

                    ngx.say("received: ", line)
                end

                local ok, err = sock:close()
                ngx.say("close: ", ok, " ", err)
            end  -- do
            -- collectgarbage()
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: userdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
close: 1 nil

--- error_log
read SNI name from Lua: nil, type: nil

--- no_error_log
[error]
[alert]
[emerg]



=== TEST 5: read raw server addr via ssl.raw_server_addr() (unix domain socket)
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"
            local addr, addrtyp, err = ssl.raw_server_addr()
            if not addr then
                ngx.log(ngx.ERR, "failed to fetch raw server addr: ", err)
                return
            end
            if addrtyp == "inet" then  -- IPv4
                ip = string.format("%d.%d.%d.%d", byte(addr, 1), byte(addr, 2),
                                   byte(addr, 3), byte(addr, 4))
                print("Using IPv4 address: ", ip)

            elseif addrtyp == "inet6" then  -- IPv6
                ip = string.format("%d.%d.%d.%d", byte(addr, 13), byte(addr, 14),
                                   byte(addr, 15), byte(addr, 16))
                print("Using IPv6 address: ", ip)

            else  -- unix
                print("Using unix socket file ", addr)
            end
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(nil, "test.com", true)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))

                local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
                local bytes, err = sock:send(req)
                if not bytes then
                    ngx.say("failed to send http request: ", err)
                    return
                end

                ngx.say("sent http request: ", bytes, " bytes.")

                while true do
                    local line, err = sock:receive()
                    if not line then
                        -- ngx.say("failed to recieve response status line: ", err)
                        break
                    end

                    ngx.say("received: ", line)
                end

                local ok, err = sock:close()
                ngx.say("close: ", ok, " ", err)
            end  -- do
            -- collectgarbage()
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: userdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
close: 1 nil

--- error_log eval
[
'lua ssl server name: "test.com"',
qr/Using unix socket file .*?nginx\.sock/
]

--- no_error_log
[error]
[alert]



=== TEST 6: read raw server addr via ssl.raw_server_addr() (IPv4)
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen 127.0.0.1:12345 ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"
            local byte = string.byte

            local addr, addrtyp, err = ssl.raw_server_addr()
            if not addr then
                ngx.log(ngx.ERR, "failed to fetch raw server addr: ", err)
                return
            end
            if addrtyp == "inet" then  -- IPv4
                ip = string.format("%d.%d.%d.%d", byte(addr, 1), byte(addr, 2),
                                   byte(addr, 3), byte(addr, 4))
                print("Using IPv4 address: ", ip)

            elseif addrtyp == "inet6" then  -- IPv6
                ip = string.format("%d.%d.%d.%d", byte(addr, 13), byte(addr, 14),
                                   byte(addr, 15), byte(addr, 16))
                print("Using IPv6 address: ", ip)

            else  -- unix
                print("Using unix socket file ", addr)
            end
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("127.0.0.1", 12345)
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(nil, "test.com", true)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))

                local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
                local bytes, err = sock:send(req)
                if not bytes then
                    ngx.say("failed to send http request: ", err)
                    return
                end

                ngx.say("sent http request: ", bytes, " bytes.")

                while true do
                    local line, err = sock:receive()
                    if not line then
                        -- ngx.say("failed to recieve response status line: ", err)
                        break
                    end

                    ngx.say("received: ", line)
                end

                local ok, err = sock:close()
                ngx.say("close: ", ok, " ", err)
            end  -- do
            -- collectgarbage()
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: userdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
close: 1 nil

--- error_log
lua ssl server name: "test.com"
Using IPv4 address: 127.0.0.1

--- no_error_log
[error]
[alert]



=== TEST 7: read raw server addr via ssl.raw_server_addr() (IPv6)
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen [::1]:12345 ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"
            local byte = string.byte

            local addr, addrtyp, err = ssl.raw_server_addr()
            if not addr then
                ngx.log(ngx.ERR, "failed to fetch raw server addr: ", err)
                return
            end
            if addrtyp == "inet" then  -- IPv4
                ip = string.format("%d.%d.%d.%d", byte(addr, 1), byte(addr, 2),
                                   byte(addr, 3), byte(addr, 4))
                print("Using IPv4 address: ", ip)

            elseif addrtyp == "inet6" then  -- IPv6
                ip = string.format("%d.%d.%d.%d", byte(addr, 13), byte(addr, 14),
                                   byte(addr, 15), byte(addr, 16))
                print("Using IPv6 address: ", ip)

            else  -- unix
                print("Using unix socket file ", addr)
            end
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("[::1]", 12345)
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(nil, "test.com", true)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))

                local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
                local bytes, err = sock:send(req)
                if not bytes then
                    ngx.say("failed to send http request: ", err)
                    return
                end

                ngx.say("sent http request: ", bytes, " bytes.")

                while true do
                    local line, err = sock:receive()
                    if not line then
                        -- ngx.say("failed to recieve response status line: ", err)
                        break
                    end

                    ngx.say("received: ", line)
                end

                local ok, err = sock:close()
                ngx.say("close: ", ok, " ", err)
            end  -- do
            -- collectgarbage()
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: userdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
close: 1 nil

--- error_log
lua ssl server name: "test.com"
Using IPv6 address: 0.0.0.1

--- no_error_log
[error]
[alert]



=== TEST 8: set DER cert chain
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            ssl.clear_certs()

            local f = assert(io.open("t/cert/chain/chain.der"))
            local cert_data = f:read("*a")
            f:close()

            local ok, err = ssl.set_der_cert(cert_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER cert: ", err)
                return
            end

            local f = assert(io.open("t/cert/chain/test-com.key.der"))
            local pkey_data = f:read("*a")
            f:close()

            local ok, err = ssl.set_der_priv_key(pkey_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER cert: ", err)
                return
            end
        }
        ssl_certificate ../../cert/test2.crt;
        ssl_certificate_key ../../cert/test2.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/chain/root-ca.crt;
    lua_ssl_verify_depth 3;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(nil, "test.com", true)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))

                local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
                local bytes, err = sock:send(req)
                if not bytes then
                    ngx.say("failed to send http request: ", err)
                    return
                end

                ngx.say("sent http request: ", bytes, " bytes.")

                while true do
                    local line, err = sock:receive()
                    if not line then
                        -- ngx.say("failed to recieve response status line: ", err)
                        break
                    end

                    ngx.say("received: ", line)
                end

                local ok, err = sock:close()
                ngx.say("close: ", ok, " ", err)
            end  -- do
            -- collectgarbage()
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: userdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
close: 1 nil

--- error_log
lua ssl server name: "test.com"

--- no_error_log
[error]
[alert]
[emerg]



=== TEST 9: read PEM cert chain but set DER cert chain
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            ssl.clear_certs()

            local f = assert(io.open("t/cert/chain/chain.pem"))
            local cert_data = f:read("*a")
            f:close()

            cert_data, err = ssl.cert_pem_to_der(cert_data)
            if not cert_data then
                ngx.log(ngx.ERR, "failed to convert pem cert to der cert: ", err)
                return
            end

            local ok, err = ssl.set_der_cert(cert_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER cert: ", err)
                return
            end

            local f = assert(io.open("t/cert/chain/test-com.key.der"))
            local pkey_data = f:read("*a")
            f:close()

            local ok, err = ssl.set_der_priv_key(pkey_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER private key: ", err)
                return
            end
        }
        ssl_certificate ../../cert/test2.crt;
        ssl_certificate_key ../../cert/test2.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/chain/root-ca.crt;
    lua_ssl_verify_depth 3;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(nil, "test.com", true)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))

                local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
                local bytes, err = sock:send(req)
                if not bytes then
                    ngx.say("failed to send http request: ", err)
                    return
                end

                ngx.say("sent http request: ", bytes, " bytes.")

                while true do
                    local line, err = sock:receive()
                    if not line then
                        -- ngx.say("failed to recieve response status line: ", err)
                        break
                    end

                    ngx.say("received: ", line)
                end

                local ok, err = sock:close()
                ngx.say("close: ", ok, " ", err)
            end  -- do
            -- collectgarbage()
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: userdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
close: 1 nil

--- error_log
lua ssl server name: "test.com"

--- no_error_log
[error]
[alert]
[emerg]



=== TEST 10: tls version - SSLv3
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen 127.0.0.2:8080 ssl;
        server_name test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            local ver, err = ssl.get_tls1_version_str(resp)
            if not ver then
                ngx.log(ngx.ERR, "failed to get TLS1 version: ", err)
                return
            end
            ngx.log(ngx.WARN, "got TLS1 version: ", ver)
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_protocols SSLv3;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;
    lua_ssl_verify_depth 3;
    lua_ssl_protocols SSLv3;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("127.0.0.2", 8080)
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(false, nil, true, false)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))
            end  -- do
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: boolean

--- error_log
got TLS1 version: SSLv3,

--- no_error_log
[error]
[alert]
[emerg]



=== TEST 11: tls version - TLSv1
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen 127.0.0.2:8080 ssl;
        server_name test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            local ver, err = ssl.get_tls1_version_str(resp)
            if not ver then
                ngx.log(ngx.ERR, "failed to get TLS1 version: ", err)
                return
            end
            ngx.log(ngx.WARN, "got TLS1 version: ", ver)
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_protocols TLSv1;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;
    lua_ssl_verify_depth 3;
    lua_ssl_protocols TLSv1;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("127.0.0.2", 8080)
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(false, nil, true, false)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))
            end  -- do
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: boolean

--- error_log
got TLS1 version: TLSv1,

--- no_error_log
[error]
[alert]
[emerg]



=== TEST 12: tls version - TLSv1.1
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen 127.0.0.2:8080 ssl;
        server_name test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            local ver, err = ssl.get_tls1_version_str(resp)
            if not ver then
                ngx.log(ngx.ERR, "failed to get TLS1 version: ", err)
                return
            end
            ngx.log(ngx.WARN, "got TLS1 version: ", ver)
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_protocols TLSv1.1;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;
    lua_ssl_verify_depth 3;
    lua_ssl_protocols TLSv1.1;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("127.0.0.2", 8080)
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(false, nil, true, false)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))
            end  -- do
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: boolean

--- error_log
got TLS1 version: TLSv1.1,

--- no_error_log
[error]
[alert]
[emerg]



=== TEST 13: tls version - TLSv1.2
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen 127.0.0.2:8080 ssl;
        server_name test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            local ver, err = ssl.get_tls1_version_str(resp)
            if not ver then
                ngx.log(ngx.ERR, "failed to get TLS1 version: ", err)
                return
            end
            ngx.log(ngx.WARN, "got TLS1 version: ", ver)
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_protocols TLSv1.2;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;
    lua_ssl_verify_depth 3;
    lua_ssl_protocols TLSv1.2;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("127.0.0.2", 8080)
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(false, nil, true, false)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))
            end  -- do
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: boolean

--- error_log
got TLS1 version: TLSv1.2,

--- no_error_log
[error]
[alert]
[emerg]



=== TEST 14: ngx.semaphore in ssl_certificate_by_lua*
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen 127.0.0.2:8080 ssl;
        server_name test.com;
        ssl_certificate_by_lua_block {
            local semaphore = require "ngx.semaphore"

            local sema = assert(semaphore.new())

            local function f()
                assert(sema:wait(1))
            end

            local t = assert(ngx.thread.spawn(f))
            ngx.sleep(0.25)

            assert(sema:post())

            assert(ngx.thread.wait(t))
            print("ssl cert by lua done")
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_protocols TLSv1.2;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;
    lua_ssl_verify_depth 3;
    lua_ssl_protocols TLSv1.2;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("127.0.0.2", 8080)
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(false, nil, true, false)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))
            end  -- do
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: boolean

--- grep_error_log eval: qr/http lua semaphore (?:wait yielding|\w[^:,]*)/
--- grep_error_log_out
http lua semaphore new
http lua semaphore wait
http lua semaphore wait yielding
http lua semaphore post
--- error_log
ssl cert by lua done

--- no_error_log
[error]
[alert]
[emerg]



=== TEST 15: read PEM key chain but set DER key chain
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            ssl.clear_certs()

            local f = assert(io.open("t/cert/chain/chain.pem"))
            local cert_data = f:read("*a")
            f:close()

            cert_data, err = ssl.cert_pem_to_der(cert_data)
            if not cert_data then
                ngx.log(ngx.ERR, "failed to convert pem cert to der cert: ", err)
                return
            end

            local ok, err = ssl.set_der_cert(cert_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER cert: ", err)
                return
            end

            local f = assert(io.open("t/cert/chain/test-com.key.pem"))
            local pkey_data = f:read("*a")
            f:close()

            pkey_data, err = ssl.priv_key_pem_to_der(pkey_data)
            if not pkey_data then
                ngx.log(ngx.ERR, "failed to convert pem key to der key: ", err)
                return
            end
            local ok, err = ssl.set_der_priv_key(pkey_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set private key: ", err)
                return
            end
        }
        ssl_certificate ../../cert/test2.crt;
        ssl_certificate_key ../../cert/test2.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block { ngx.status = 201 ngx.say("foo") ngx.exit(201) }
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/chain/root-ca.crt;
    lua_ssl_verify_depth 3;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(nil, "test.com", true)
                if not sess then
                    ngx.say("failed to do SSL handshake: ", err)
                    return
                end

                ngx.say("ssl handshake: ", type(sess))

                local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
                local bytes, err = sock:send(req)
                if not bytes then
                    ngx.say("failed to send http request: ", err)
                    return
                end

                ngx.say("sent http request: ", bytes, " bytes.")

                while true do
                    local line, err = sock:receive()
                    if not line then
                        -- ngx.say("failed to recieve response status line: ", err)
                        break
                    end

                    ngx.say("received: ", line)
                end

                local ok, err = sock:close()
                ngx.say("close: ", ok, " ", err)
            end  -- do
            -- collectgarbage()
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: userdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
close: 1 nil

--- error_log
lua ssl server name: "test.com"

--- no_error_log
[error]
[alert]
[emerg]
