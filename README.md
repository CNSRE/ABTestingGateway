基于动态策略的灰度发布系统
========================

这是一个可以动态设置分流策略的灰度发布系统，基于ngx-lua开发，可以实现动态调度功能。

灰度发布系统的主要功能是实现用户请求的分流转发，工作在7层，根据用户请求特征，如UID、IP等，将请求转发至后端服务器，实现分流。

nginx是目前使用较多的7层服务器，可以实现高性能的转发和响应；灰度发布系统是在nginx转发的框架内，在转向upstream前，根据用户请求特征和分流策略，计算出目标upstream，进而实现分流。

在以往的基于nginx实现的灰度系统中，分流逻辑往往通过rewrite阶段的if和rewrite指令等实现，优点是`性能较高`，缺点是`功能受限`、`容易出错`，以及`转发规则固定，只能静态分流`。

针对这些缺点，我们基于[tengine](http://tengine.taobao.org/)和[ngx-lua](https://github.com/openresty/lua-nginx-module)设计实现了一个灰度发布系统，采用ngx-lua实现系统功能，采用redis作为分流策略数据库，通过启用[lua-shared-dict](http://wiki.nginx.org/HttpLuaModule#ngx.shared.DICT)和[lua-resty-lock](https://github.com/openresty/lua-resty-redis)作为系统缓存和缓存锁，系统获得了较为接近原生nginx转发的性能。

<div align="center"><img src="https://raw.githubusercontent.com/SinaMSRE/ABTestingGateway/master/doc/img/abtesting_architect.png" width="70%" height="70%"></div>

- 系统实现了分流策略的动态即时更新，进而实现了动态调度功能。

- 系统提供了策略管理接口，系统管理员通过管理接口设置分流策略，控制分流。

- 系统提供了开发框架，开发者可以灵活添加新的分流方式，实现二次开发

Features:
----------

- 基于nginx和ngx-lua开发
- 支持多种分流方式，目前包括iprange、uidrange、uid尾数和指定uid分流等
- 动态设置分流策略，即时生效，无需重启
- 可扩展性，灵活添加新的分流方式
- 高性能，压测数据接近原生nginx转发
- 灰度系统配置写在nginx配置文件中，方便管理员配置
- 适用于多种场景：灰度发布、AB测试和负载均衡等

功能介绍
------------
###分流功能：
转发分流是灰度系统的主要功能，目前系统支持按照ip段分流、uid段分流、uid尾数分流和指定特殊uid分流四种方式。
    
1. iprange

        IP段分流方式的分流策略为：
            {
                "divtype":"iprange",
                "divdata":[
                            {"range":{"start":1111, "end":2222}, "upstream":"beta1"},
                            {"range":{"start":3333, "end":4444}, "upstream":"beta2"},
                            {"range":{"start":7777, "end":8888}, "upstream":"beta3"}
                          ]
            }
        其中divdata中的每个range:upstream对中，range为ip段，upstream为ip段对应转发的后端；range中的start和end分别为ip的整型表示。
        当灰度系统启用iprange分流方式时，会根据用户请求的ip进行分流转发。
        假如用户请求的ip，转为32位整型是4000，将被转发至beta2 upstream。

2. uidrange

        UID段分流方式的分流策略为：
            {
                "divtype":"uidrange",
                "divdata":[
                            {"range":{"start":111, "end":222}, "upstream":"beta1"},
                            {"range":{"start":333, "end":444}, "upstream":"beta2"},
                            {"range":{"start":777, "end":888}, "upstream":"beta3"}
                          ]
            }
        uidrange分流与iprange分流的原理一样。
        当灰度系统启用uidrange分流方式时，会根据用户请求的uid进行分流转发。
        目前系统采用读取用户请求中，http头部的   X-Uid   字段获取uid

3. uidsuffix

        UID尾数分流方式的分流策略为：
            {
                "divtype":"uidsuffix",
                "divdata":[
                            {"suffix":"1", "upstream":"beta1"},
                            {"suffix":"3", "upstream":"beta2"},
                            {"suffix":"5", "upstream":"beta1"},
                            {"suffix":"0", "upstream":"beta3"}
                          ]
            }

        当灰度系统启用uidsuffix分流方式时，会根据用户请求的uid的个位尾数进行分流转发。

4. uidappoint

        指定特殊UID分流方式的分流策略为：
            {
                "divtype":"uidsuffix",
                "divdata":[
                            {"uidset":["1143321","43214321"], "upstream":"beta1"},
                            {"uidset":["34321","324214","234321"], "upstream":"beta2"},
                            {"uidset":["546","563","656", "1661638660"], "upstream":"beta3"}
                          ]
            }

        当灰度系统启用uidappoint分流方式时，会根据用户请求的uid进行分流转发。
        当用户请求uid恰好为234321时，系统将其转发至beta2 upstream。

5. 分流过程流程图
<div align="center"><img src="https://raw.githubusercontent.com/SinaMSRE/ABTestingGateway/master/doc/img/div_flowchart.png"></div>

系统管理员通过系统管理接口将`某个分流策略`设置为`运行时策略`，并指定该策略对应的`分流模块`和`用户信息提取模块`后，系统开始进行分流工作。

分流过程中，首先获得系统的`运行时信息`，然后提取`用户特征`，最后`分流模块`根据`用户特征`和`分流策略`计算得出应该转发到的upstream server。
   

###管理功能：
    
1. 分流策略管理         
    
2. 运行时信息管理


接口说明
----------
###管理接口：
<pre>
[策略管理接口]	
    #分流策略检查
    1. /admin/policy/check
    #分流策略添加
    2. /admin/policy/set
    #分流策略读取
    3. /admin/policy/get
    #分流策略删除
    4. /admin/policy/del

[运行时管理接口]
    #设置分流策略为运行时策略
    1. /admin/runtime/set
    #获取系统当前运行时信息
    2. /admin/runtime/get
    #删除系统运行时信息，关闭分流接口
    3. /admin/runtime/del
</pre>

快速部署
----------

repo中的`utils/conf`文件夹中有灰度系统部署所需的一个最小示例

<pre>
1. git clone https://github.com/SinaMSRE/ABTestingGateway
2. cd /path/to/ABTestingGateway/utils

#启动redis数据库
3. redis-server conf/redis.conf 

#启动upstream server，其中stable为默认upstream
4. /usr/local/nginx/sbin/nginx -p `pwd` -c conf/stable.conf
5. /usr/local/nginx/sbin/nginx -p `pwd` -c conf/beta1.conf
6. /usr/local/nginx/sbin/nginx -p `pwd` -c conf/beta2.conf
7. /usr/local/nginx/sbin/nginx -p `pwd` -c conf/beta3.conf
8. /usr/local/nginx/sbin/nginx -p `pwd` -c conf/beta4.conf

#启动灰度系统，proxy server，灰度系统的配置也写在conf/nginx.conf中
9. /usr/local/nginx/sbin/nginx -p `pwd` -c conf/nginx.conf
</pre>

灰度系统工作示例
--------------
1. 管理功能
    
        1. 部署并启动系统
        
        2. 查询系统运行时信息，得到null
        0> curl 127.0.0.1:8030/admin/runtime/get
        {"errcode":200,"errinfo":"success ","data":{"divModulename":null,"divDataKey":null,"userInfoModulename":null}}
        
        3. 查询id为9的策略，得到null
        0> curl 127.0.0.1:8030/admin/policy/get?policyid=9
        {"errcode":200,"errinfo":"success ","data":{"divdata":null,"divtype":null}}
        
        4. 向系统添加策略，返回成功，并返回新添加策略的policyid
        0> curl 127.0.0.1:8030/admin/policy/set -d '{"divtype":"uidsuffix","divdata":[{"suffix":"1","upstream":"beta1"},{"suffix":"3","upstream":"beta2"},{"suffix":"5","upstream":"beta1"},{"suffix":"0","upstream":"beta3"}]}'
        {"errcode":200,"errinfo":"success  the id of new policy is 0"}
        
        5. 查看添加结果
        0> curl 127.0.0.1:8030/admin/policy/get?policyid=0
        {"errcode":200,"errinfo":"success ","data":{"divdata":["1","beta1","3","beta2","5","beta1","0","beta3"],"divtype":"uidsuffix"}}
        
        6. 设置系统运行时策略为 0号策略
        0> curl 127.0.0.1:8030/admin/runtime/set?policyid=0
        {"errcode":200,"errinfo":"success "}
        
        7. 查看系统运行时信息，得到结果
        0> curl 127.0.0.1:8030/admin/runtime/get
        {"errcode":200,"errinfo":"success ","data":{"divModulename":"abtesting.diversion.uidsuffix","divDataKey":"ab:test:policies:0:divdata","userInfoModulename":"abtesting.userinfo.uidParser"}}
        
        8. 当访问接口不正确返回时，将返回相应的 错误码 和 错误描述信息
        0> curl 127.0.0.1:8030/admin/policy/get?policyid=abc
        {"errcode":50104,"errinfo":"parameter type error for policyID should be a positive Integer"}


2. 分流功能

        在验证管理功能通过，并设置系统运行时策略后，开始验证分流功能

        1. 分流，不带用户uid，转发至默认upstream
        0> curl 127.0.0.1:8030
        this is stable server
        
        2. 分流，带uid为30，根据策略，转发至beta3
        0> curl 127.0.0.1:8030  -H 'X-Uid:30'
        this is beta3 server

线上部署：
-----------
<div align="center"><img src="https://github.com/SinaMSRE/ABTestingGateway/blob/master/doc/img/deployment.png"></div>

软件版本：
-----------
- tengine-2.1.0
- LuaJIT-2.1-20141128
- ngx_lua-0.9.13
- lua-cjson-2.1.0.2
- redis-2.8.19

