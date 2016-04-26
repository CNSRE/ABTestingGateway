Name
====

ngx.balancer - Lua API for defining dynamic upstream balancers in Lua

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Synopsis](#synopsis)
* [Description](#description)
* [Methods](#methods)
    * [set_current_peer](#set_current_peer)
    * [set_more_tries](#set_more_tries)
    * [get_last_failure](#get_last_failure)
* [Community](#community)
    * [English Mailing List](#english-mailing-list)
    * [Chinese Mailing List](#chinese-mailing-list)
* [Bugs and Patches](#bugs-and-patches)
* [Author](#author)
* [Copyright and License](#copyright-and-license)
* [See Also](#see-also)

Status
======

This Lua module is currently considered experimental.

Synopsis
========

```nginx
http {
    upstream backend {
        server 0.0.0.1;   # just an invalid address as a place holder

        balancer_by_lua_block {
            local balancer = require "ngx.balancer"

            -- well, usually we calculate the peer's host and port
            -- according to some balancing policies instead of using
            -- hard-coded values like below
            local host = "127.0.0.2"
            local port = 8080

            local ok, err = balancer.set_current_peer(host, port)
            if not ok then
                ngx.log(ngx.ERR, "failed to set the current peer: ", err)
                return ngx.exit(500)
            end
        }

        keepalive 10;  # connection pool
    }

    server {
        # this is the real entry point
        listen 80;

        location / {
            # make use of the upstream named "backend" defined above:
            proxy_pass http://backend/fake;
        }
    }

    server {
        # this server is just for mocking up a backend peer here...
        listen 127.0.0.2:8080;

        location = /fake {
            echo "this is the fake backend peer...";
        }
    }
}
```

Description
===========

This Lua module provides API functions to allow defining highly dynamic NGINX load balancers for
any existing nginx upstream modules like [http://nginx.org/en/docs/http/ngx_http_proxy_module.html ngx_proxy] and
[http://nginx.org/en/docs/http/ngx_http_fastcgi_module.html ngx_fastcgi].

It allows you to dynamically select a backend peer to connect to (or retry) on a per-request
basis from a list of backend peers which may also be dynamic.

[Back to TOC](#table-of-contents)

Methods
=======

All the methods of this module are static (or module-level). That is, you do not need an object (or instance)
to call these methods.

[Back to TOC](#table-of-contents)

set_current_peer
----------------
**syntax:** `ok, err = balancer.set_current_peer(host, port)`

**context:** *balancer_by_lua&#42;*

Sets the peer address (host and port) for the current backend query (which may be a retry).

Domain names in `host` do not make sense. You need to use OpenResty libraries like
[lua-resty-dns](https://github.com/openresty/lua-resty-dns) to obtain IP address(es) from
all the domain names before entering the `balancer_by_lua*` handler (for example,
you can perform DNS lookups in an earlier phase like [access_by_lua*](https://github.com/openresty/lua-nginx-module#access_by_lua)
and pass the results to the `balancer_by_lua*` handler via [ngx.ctx](https://github.com/openresty/lua-nginx-module#ngxctx).

[Back to TOC](#table-of-contents)

set_more_tries
--------------
**syntax:** `ok, err = balancer.set_more_tries(count)`

**context:** *balancer_by_lua&#42;*

Sets the tries performed when the current attempt (which may be a retry) fails (as determined
by directives like [proxy_next_upstream](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream), depending on what
particular nginx uptream module you are currently using. Note that the current attempt is *excluded* in the `count` number set here.

Please note that, the total number of tries in a single downstream request cannot exceed the
hard limit configured by directives like [proxy_next_upstream_tries](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream_tries),
depending on what concrete nginx upstream module you are using. When exceeding this limit,
the `count` value will get reduced to meet the limit and the second return value will be
the string `"reduced tries due to limit"`, which is a warning, while the first return value
is still a `true` value.

[Back to TOC](#table-of-contents)

get_last_failure
----------------
**syntax:** `state_name, status_code = balancer.get_last_failure()`

**context:** *balancer_by_lua&#42;*

Retrieves the failure details about the previous failed attempt (if any) when the `next_upstream` retrying
mechanism is in action. When there was indeed a failed previous attempt, it returned a string descrbing
that attempt's state name, as well as an integer describing the status code of that attempt.

Possible state names are as follows:
* `"next"`
    Failures due to bad status codes sent from the backend server. The origin's response is sane though, which means the backend connection
can still be reused for future requests.
* `"failed"`
    Fatal errors while communicating to the backend server (like connection timeouts, connection resets, and etc). In this case,
the backend connection must be aborted and cannot get reused.

Possible status codes are those HTTP error status codes like `502` and `504`.

When the current attempt is the first attempt for the current downstream request (which means
there is no previous attempts at all), this
method always returns a single `nil` value.

[Back to TOC](#table-of-contents)

Community
=========

[Back to TOC](#table-of-contents)

English Mailing List
--------------------

The [openresty-en](https://groups.google.com/group/openresty-en) mailing list is for English speakers.

[Back to TOC](#table-of-contents)

Chinese Mailing List
--------------------

The [openresty](https://groups.google.com/group/openresty) mailing list is for Chinese speakers.

[Back to TOC](#table-of-contents)

Bugs and Patches
================

Please report bugs or submit patches by

1. creating a ticket on the [GitHub Issue Tracker](https://github.com/openresty/lua-resty-core/issues),
1. or posting to the [OpenResty community](#community).

[Back to TOC](#table-of-contents)

Author
======

Yichun Zhang &lt;agentzh@gmail.com&gt; (agentzh), CloudFlare Inc.

[Back to TOC](#table-of-contents)

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2015, by Yichun "agentzh" Zhang, CloudFlare Inc.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[Back to TOC](#table-of-contents)

See Also
========
* the ngx_lua module: https://github.com/openresty/lua-nginx-module
* the [balancer_by_lua*](https://github.com/openresty/lua-nginx-module#balancer_by_lua_block) directive.
* library [lua-resty-core](https://github.com/openresty/lua-resty-core)
* OpenResty: http://openresty.org

[Back to TOC](#table-of-contents)
