# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_on();
#workers(2);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4 + 4);

$ENV{TEST_NGINX_CWD} = cwd();

#no_diff();
no_long_string();
run_tests();

__DATA__

=== TEST 1: set current peer (separate addr and port)
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
            local b = require "ngx.balancer"
            assert(b.set_current_peer("127.0.0.3", 12345))
        }
    }
--- config
    location = /t {
        proxy_pass http://backend;
    }
--- request
    GET /t
--- response_body_like: 502 Bad Gateway
--- error_code: 502
--- error_log eval
[
'[lua] balancer_by_lua:2: hello from balancer by lua! while connecting to upstream,',
qr{connect\(\) failed .*?, upstream: "http://127\.0\.0\.3:12345/t"},
]
--- no_error_log
[warn]



=== TEST 2: set current peer & next upstream (3 tries)
--- skip_nginx: 4: < 1.7.5
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504 http_403 http_404;
    proxy_next_upstream_tries 10;

    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
            local b = require "ngx.balancer"
            if not ngx.ctx.tries then
                ngx.ctx.tries = 0
            end

            if ngx.ctx.tries < 2 then
                local ok, err = b.set_more_tries(1)
                if not ok then
                    return error("failed to set more tries: ", err)
                elseif err then
                    ngx.log(ngx.WARN, "set more tries: ", err)
                end
            end
            ngx.ctx.tries = ngx.ctx.tries + 1
            assert(b.set_current_peer("127.0.0.3", 12345))
        }
    }
--- config
    location = /t {
        proxy_pass http://backend;
    }
--- request
    GET /t
--- response_body_like: 502 Bad Gateway
--- error_code: 502
--- grep_error_log eval: qr{connect\(\) failed .*, upstream: "http://.*?"}
--- grep_error_log_out eval
qr#^(?:connect\(\) failed .*?, upstream: "http://127.0.0.3:12345/t"\n){3}$#
--- no_error_log
[warn]



=== TEST 3: set current peer & next upstream (no retries)
--- skip_nginx: 4: < 1.7.5
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504 http_403 http_404;

    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
            local b = require "ngx.balancer"
            if not ngx.ctx.tries then
                ngx.ctx.tries = 0
            end

            ngx.ctx.tries = ngx.ctx.tries + 1
            assert(b.set_current_peer("127.0.0.3", 12345))
        }
    }
--- config
    location = /t {
        proxy_pass http://backend;
    }
--- request
    GET /t
--- response_body_like: 502 Bad Gateway
--- error_code: 502
--- grep_error_log eval: qr{connect\(\) failed .*, upstream: "http://.*?"}
--- grep_error_log_out eval
qr#^(?:connect\(\) failed .*?, upstream: "http://127.0.0.3:12345/t"\n){1}$#
--- no_error_log
[warn]



=== TEST 4: set current peer & next upstream (3 tries exceeding the limit)
--- skip_nginx: 4: < 1.7.5
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504 http_403 http_404;
    proxy_next_upstream_tries 2;

    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            local b = require "ngx.balancer"

            if not ngx.ctx.tries then
                ngx.ctx.tries = 0
            end

            if ngx.ctx.tries < 2 then
                local ok, err = b.set_more_tries(1)
                if not ok then
                    return error("failed to set more tries: ", err)
                elseif err then
                    ngx.log(ngx.WARN, "set more tries: ", err)
                end
            end
            ngx.ctx.tries = ngx.ctx.tries + 1
            assert(b.set_current_peer("127.0.0.3", 12345))
        }
    }
--- config
    location = /t {
        proxy_pass http://backend;
    }
--- request
    GET /t
--- response_body_like: 502 Bad Gateway
--- error_code: 502
--- grep_error_log eval: qr{connect\(\) failed .*, upstream: "http://.*?"}
--- grep_error_log_out eval
qr#^(?:connect\(\) failed .*?, upstream: "http://127.0.0.3:12345/t"\n){2}$#
--- error_log
set more tries: reduced tries due to limit



=== TEST 5: get last peer failure status (404)
--- skip_nginx: 4: < 1.7.5
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504 http_403 http_404;
    proxy_next_upstream_tries 10;

    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            local b = require "ngx.balancer"

            local state, status = b.get_last_failure()
            print("last peer failure: ", state, " ", status)

            if not ngx.ctx.tries then
                ngx.ctx.tries = 0
            end

            if ngx.ctx.tries < 2 then
                local ok, err = b.set_more_tries(1)
                if not ok then
                    return error("failed to set more tries: ", err)
                elseif err then
                    ngx.log(ngx.WARN, "set more tries: ", err)
                end
            end
            ngx.ctx.tries = ngx.ctx.tries + 1
            assert(b.set_current_peer("127.0.0.1", tonumber(ngx.var.server_port)))
        }
    }
--- config
    location = /t {
        proxy_pass http://backend/back;
    }

    location = /back {
        return 404;
    }
--- request
    GET /t
--- response_body_like: 404 Not Found
--- error_code: 404
--- grep_error_log eval: qr{last peer failure: \S+ \S+}
--- grep_error_log_out
last peer failure: nil nil
last peer failure: next 404
last peer failure: next 404

--- no_error_log
[warn]



=== TEST 6: get last peer failure status (500)
--- skip_nginx: 4: < 1.7.5
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504 http_403 http_404;
    proxy_next_upstream_tries 10;

    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            local b = require "ngx.balancer"

            local state, status = b.get_last_failure()
            print("last peer failure: ", state, " ", status)

            if not ngx.ctx.tries then
                ngx.ctx.tries = 0
            end

            if ngx.ctx.tries < 2 then
                local ok, err = b.set_more_tries(1)
                if not ok then
                    return error("failed to set more tries: ", err)
                elseif err then
                    ngx.log(ngx.WARN, "set more tries: ", err)
                end
            end
            ngx.ctx.tries = ngx.ctx.tries + 1
            assert(b.set_current_peer("127.0.0.1", tonumber(ngx.var.server_port)))
        }
    }
--- config
    location = /t {
        proxy_pass http://backend/back;
    }

    location = /back {
        return 500;
    }
--- request
    GET /t
--- response_body_like: 500 Internal Server Error
--- error_code: 500
--- grep_error_log eval: qr{last peer failure: \S+ \S+}
--- grep_error_log_out
last peer failure: nil nil
last peer failure: failed 500
last peer failure: failed 500

--- no_error_log
[warn]



=== TEST 7: get last peer failure status (503)
--- skip_nginx: 4: < 1.7.5
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504 http_403 http_404;
    proxy_next_upstream_tries 10;

    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            local b = require "ngx.balancer"

            local state, status = b.get_last_failure()
            print("last peer failure: ", state, " ", status)

            if not ngx.ctx.tries then
                ngx.ctx.tries = 0
            end

            if ngx.ctx.tries < 2 then
                local ok, err = b.set_more_tries(1)
                if not ok then
                    return error("failed to set more tries: ", err)
                elseif err then
                    ngx.log(ngx.WARN, "set more tries: ", err)
                end
            end
            ngx.ctx.tries = ngx.ctx.tries + 1
            assert(b.set_current_peer("127.0.0.1", tonumber(ngx.var.server_port)))
        }
    }
--- config
    location = /t {
        proxy_pass http://backend/back;
    }

    location = /back {
        return 503;
    }
--- request
    GET /t
--- response_body_like: 503 Service Temporarily Unavailable
--- error_code: 503
--- grep_error_log eval: qr{last peer failure: \S+ \S+}
--- grep_error_log_out
last peer failure: nil nil
last peer failure: failed 502
last peer failure: failed 502

--- no_error_log
[warn]



=== TEST 8: get last peer failure status (connect failed)
--- skip_nginx: 4: < 1.7.5
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504 http_403 http_404;
    proxy_next_upstream_tries 10;

    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            local b = require "ngx.balancer"

            local state, status = b.get_last_failure()
            print("last peer failure: ", state, " ", status)

            if not ngx.ctx.tries then
                ngx.ctx.tries = 0
            end

            if ngx.ctx.tries < 2 then
                local ok, err = b.set_more_tries(1)
                if not ok then
                    return error("failed to set more tries: ", err)
                elseif err then
                    ngx.log(ngx.WARN, "set more tries: ", err)
                end
            end
            ngx.ctx.tries = ngx.ctx.tries + 1
            assert(b.set_current_peer("127.0.0.3", 12345))
        }
    }
--- config
    location = /t {
        proxy_pass http://backend/back;
    }

    location = /back {
        return 404;
    }
--- request
    GET /t
--- response_body_like: 502 Bad Gateway
--- error_code: 502
--- grep_error_log eval: qr{last peer failure: \S+ \S+}
--- grep_error_log_out
last peer failure: nil nil
last peer failure: failed 502
last peer failure: failed 502

--- no_error_log
[warn]



=== TEST 9: set current peer (port embedded in addr)
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
            local b = require "ngx.balancer"
            assert(b.set_current_peer("127.0.0.3:12345"))
        }
    }
--- config
    location = /t {
        proxy_pass http://backend;
    }
--- request
    GET /t
--- response_body_like: 502 Bad Gateway
--- error_code: 502
--- error_log eval
[
'[lua] balancer_by_lua:2: hello from balancer by lua! while connecting to upstream,',
qr{connect\(\) failed .*?, upstream: "http://127\.0\.0\.3:12345/t"},
]
--- no_error_log
[warn]



=== TEST 10: keepalive before balancer
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 0.0.0.1;
        keepalive 10;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
            local b = require "ngx.balancer"
            assert(b.set_current_peer("127.0.0.3:12345"))
        }
    }
--- config
    location = /t {
        proxy_pass http://backend;
    }
--- request
    GET /t
--- response_body_like: 502 Bad Gateway
--- grep_error_log eval: qr/load balancing method redefined in/
--- grep_error_log_out eval
[
"load balancing method redefined in
",
"",
]
--- error_code: 502
--- error_log eval
[
'[lua] balancer_by_lua:2: hello from balancer by lua! while connecting to upstream,',
qr{connect\(\) failed .*?, upstream: "http://127\.0\.0\.3:12345/t"},
]
--- no_error_log
[crit]



=== TEST 11: keepalive after balancer
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            local b = require "ngx.balancer"
            assert(b.set_current_peer("127.0.0.1", tonumber(ngx.var.server_port)))
        }
        keepalive 1;
    }
--- config
    location = /t {
        content_by_lua_block {
            local res0 = ngx.location.capture("/tt")
            local res1 = ngx.location.capture("/tt")
            local res2 = ngx.location.capture("/tt")

            if res2.status == ngx.HTTP_OK then
                ngx.print(res2.body)
            end
        }
    }

    location = /tt {
        proxy_pass http://backend/back;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    location = /back {
        echo "hello keepalive!";
    }
--- request
    GET /t
--- response_body
hello keepalive!
--- error_code: 200
--- grep_error_log eval: qr{\S+ keepalive peer:.*?connection}
--- grep_error_log_out eval
["free keepalive peer: saving connection
get keepalive peer: using connection
free keepalive peer: saving connection
get keepalive peer: using connection
free keepalive peer: saving connection
",
"get keepalive peer: using connection
free keepalive peer: saving connection
get keepalive peer: using connection
free keepalive peer: saving connection
get keepalive peer: using connection
free keepalive peer: saving connection
",
]
--- no_error_log
[warn]



=== TEST 12: set_current_peer called in a wrong context
--- wait: 0.2
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 127.0.0.1:$TEST_NGINX_SERVER_PORT;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
        }
    }

--- config

    location = /fake {
        echo ok;
    }

    location = /t {
        proxy_pass http://backend/fake;

        log_by_lua_block {
            local balancer = require "ngx.balancer"
            local ok, err = balancer.set_current_peer("127.0.0.1", 1234)
            if not ok then
                ngx.log(ngx.ERR, "failed to call: ", err)
                return
            end
            ngx.log(ngx.ALERT, "unexpected success")
        }
    }

--- request
GET /t
--- response_body
ok
--- error_log eval
qr/\[error\] .*? log_by_lua.*? failed to call: API disabled in the current context/
--- no_error_log
[alert]



=== TEST 13: get_last_failure called in a wrong context
--- wait: 0.2
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 127.0.0.1:$TEST_NGINX_SERVER_PORT;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
        }
    }

--- config

    location = /fake {
        echo ok;
    }

    location = /t {
        proxy_pass http://backend/fake;

        log_by_lua_block {
            local balancer = require "ngx.balancer"
            local state, status, err = balancer.get_last_failure()
            if not state and err then
                ngx.log(ngx.ERR, "failed to call: ", err)
                return
            end
            ngx.log(ngx.ALERT, "unexpected success")
        }
    }

--- request
GET /t
--- response_body
ok
--- error_log eval
qr/\[error\] .*? log_by_lua.*? failed to call: API disabled in the current context/
--- no_error_log
[alert]



=== TEST 14: set_more_tries called in a wrong context
--- wait: 0.2
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 127.0.0.1:$TEST_NGINX_SERVER_PORT;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
        }
    }

--- config

    location = /fake {
        echo ok;
    }

    location = /t {
        proxy_pass http://backend/fake;

        log_by_lua_block {
            local balancer = require "ngx.balancer"
            local ok, err = balancer.set_more_tries(1)
            if not ok then
                ngx.log(ngx.ERR, "failed to call: ", err)
                return
            end
            ngx.log(ngx.ALERT, "unexpected success")
        }
    }

--- request
GET /t
--- response_body
ok
--- error_log eval
qr/\[error\] .*? log_by_lua.*? failed to call: API disabled in the current context/
--- no_error_log
[alert]
