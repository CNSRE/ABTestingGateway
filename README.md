基于动态策略的灰度发布系统
========================
ABTesingGateway 是一个可以动态设置分流策略的灰度发布系统，工作在7层，基于[tengine](http://tengine.taobao.org/)，采用[ngx-lua](https://github.com/openresty/lua-nginx-module)开发，使用 redis 作为分流策略数据库，可以实现动态调度功能。

nginx是目前使用较多的7层服务器，可以实现高性能的转发和响应；ABTestingGateway 是在 nginx 转发的框架内，在转向 upstream 前，根据 用户请求特征 和 系统的分流策略 ，查找出目标upstream，进而实现分流。

在以往的基于 nginx 实现的灰度系统中，分流逻辑往往通过 rewrite 阶段的 if 和 rewrite 指令等实现，优点是`性能较高`，缺点是`功能受限`、`容易出错`，以及`转发规则固定，只能静态分流`。针对这些缺点，我们设计实现了ABTesingGateway，采用 ngx-lua 实现系统功能，通过启用[lua-shared-dict](http://wiki.nginx.org/HttpLuaModule#ngx.shared.DICT)和[lua-resty-lock](https://github.com/openresty/lua-resty-redis)作为系统缓存和缓存锁，系统获得了较为接近原生nginx转发的性能。

<div align="center"><img src="https://raw.githubusercontent.com/SinaMSRE/ABTestingGateway/master/doc/img/abtesting_architect.png" width="70%" height="70%"><p>ABTesingGateway 的架构简图</p></div>

Features:
----------

- 支持多种分流方式，目前包括iprange、uidrange、uid尾数和指定uid分流
- 动态设置分流策略，即时生效，无需重启
- 可扩展性，提供了开发框架，开发者可以灵活添加新的分流方式，实现二次开发
- 高性能，压测数据接近原生nginx转发
- 灰度系统配置写在nginx配置文件中，方便管理员配置
- 适用于多种场景：灰度发布、AB测试和负载均衡等

系统实现
------------
###分流功能：
转发分流是灰度系统的主要功能，目前 ABTesingGateway 支持 `ip段分流(iprange)`、`uid用户段分流(uidrange)`、`uid尾数分流(uidsuffix)` 和 `指定特殊uid分流(uidappoint)` 四种方式。

ABTesingGateway 依据系统中配置的 `运行时信息runtimeInfo` 进行分流工作；通过将 runtimeInfo 设置为不同的分流策略，实现运行时分流策略的动态更新，达到动态调度的目的。

1. 系统运行时信息设置

    <div align="center"><img src="https://raw.githubusercontent.com/SinaMSRE/ABTestingGateway/master/doc/img/runtime_policy.png" ></div>
如图所示

    - 系统管理员通过系统管理接口将`分流策略policy`设置为`运行时策略`，并指定该策略对应的 `分流模块名divModulename` 和 `用户信息提取模块名userInfoModulename` 后，系统可以进行分流工作。
    - 系统对用户请求进行分流时，首先获得系统 `运行时信息runtimeInfo` 中的信息，然后提取 `用户特征userInfo`，最后 `分流模块divModule` 根据 `分流策略dviDataKey` 和 `用户特征userInfo` 查找出应该转发到的upstream。如果没有对应的upstream，则将该请求转向默认upstream。 

2. 以iprange分流为例           
        
        以某个iprange分流策略为例：
            {
                "divtype":"iprange",
                "divdata":[
                            {"range":{"start":1111, "end":2222}, "upstream":"beta1"},
                            {"range":{"start":3333, "end":4444}, "upstream":"beta2"},
                            {"range":{"start":7777, "end":8888}, "upstream":"beta3"}
                          ]
            }
其中divdata中的每个 range:upstream 对中，range 为 ip 段，upstream 为 ip 段对应的后端；range 中的 start 和 end 分别为 ip 段的起始和终止， ip以整型表示。
当灰度系统启用iprange分流方式时，会根据用户请求的ip进行分流转发。
假如用户请求中的ip信息转为整型后是4000，将被转发至beta2 upstream。

3. 分流过程流程图
<div align="center"><img src="https://raw.githubusercontent.com/SinaMSRE/ABTestingGateway/master/doc/img/div_flowchart.png"><p>分流过程流程图</p></div>
   
###管理功能：
<div align="center"><img src="https://raw.githubusercontent.com/SinaMSRE/ABTestingGateway/master/doc/img/manage.png"><p>管理功能架构图</p></div>
    
    1. 管理员登入后，得到系统信息视图，运行时信息视图，可以进行策略管理和运行时信息管理
    2. 业务接口层向管理员提供  增/删/查/改  接口
    3. 适配层将承担业务接口与分流模块的沟通工作
    4. 适配层提出统一接口，开发人员可以通过实现接口来添加新的分流方式     

####管理接口：
<pre>
[策略管理接口]	
    #分流策略检查，参数为一个分流策略数据的json串
    1. /admin/policy/check
    #分流策略添加，参数与check接口一致
    2. /admin/policy/set
    #分流策略读取，参数为要读取策略的policyid
    3. /admin/policy/get
    #分流策略删除，参数为要删除策略的policyid
    4. /admin/policy/del

[运行时信息管理接口]
    #设置分流策略为运行时策略，参数为policyid
    1. /admin/runtime/set
    #获取系统当前运行时信息，无参数
    2. /admin/runtime/get
    #删除系统运行时信息，关闭分流接口，无参数
    3. /admin/runtime/del
</pre>

快速部署
----------

###软件依赖
- tengine-2.1.0
- LuaJIT-2.1-20141128
- ngx_lua-0.9.13
- lua-cjson-2.1.0.2
- redis-2.8.19


###系统部署
repo中的`utils/conf`文件夹中有灰度系统部署所需的最小示例

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

###灰度系统使用demo
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
               以uidsuffix尾数分流方式为例，示例分流策略为：
                    {
                        "divtype":"uidsuffix",
                        "divdata":[
                                    {"suffix":"1", "upstream":"beta1"},
                                    {"suffix":"3", "upstream":"beta2"},
                                    {"suffix":"5", "upstream":"beta1"},
                                    {"suffix":"0", "upstream":"beta3"}
                                  ]
                    }
        添加分流策略接口 /admin/policy/set 接受json化的policy数据
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
        0> curl 127.0.0.1:8030/
        this is stable server
        
        2. 分流，带uid为30，根据策略，转发至beta3
        0> curl 127.0.0.1:8030/  -H 'X-Uid:30'
        this is beta3 server

        3. 分流，带uid为33，根据策略，转发至beta2
        0> curl 127.0.0.1:8030/  -H 'X-Uid:33'
        this is beta2 server

压测结果：
-----------

<div align="center"><img src="https://raw.githubusercontent.com/SinaMSRE/ABTestingGateway/master/doc/img/load_line.png"><p>压测环境下灰度系统与原生nginx转发的对比图</p></div>

<div align="center"><img src="https://raw.githubusercontent.com/SinaMSRE/ABTestingGateway/master/doc/img/load_data.png"><p>压测环境下灰度系统与原生nginx转发的数据对比</p></div>

如图所示，用户请求完全命中cache是理想中的情况，灰度系统在理想情况下可以达到十分接近原生nginx转发的性能。

产生图中压测结果的场景是：用户请求经过proxy server转向upstream server，访问1KB大小的静态文件。proxy server的硬件配置：

- CPU：E5620 2.4GHz 16核
- Mem：24GB
- Nic：千兆网卡，多队列，理论流量峰值为125MB/s

线上部署简图：
-----------
<div align="center"><img src="https://raw.githubusercontent.com/SinaMSRE/ABTestingGateway/master/doc/img/deployment.png"></div>


