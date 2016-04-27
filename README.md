
基于动态策略的灰度发布系统
=========================

* ABTestingGateway 是一个可以动态设置分流策略的灰度发布系统，工作在7层，基于nginx和ngx-lua开发，使用 redis 作为分流策略数据库，可以实现动态调度功能。

* nginx是目前使用较多的7层服务器，可以实现高性能的转发和响应；ABTestingGateway 是在 nginx 转发的框架内，在转向 upstream 前，根据 用户请求特征 和 系统的分流策略 ，查找出目标upstream，进而实现分流。

* ABTestingGateway 是新浪微博内部的动态路由系统 dygateway 的一部分，因此本文档中的 dygateway 主要是指其子功能 ABTestingGateway。动态路由系统dygateway目前应用于手机微博7层、微博头条等产品线。

在以往的基于 nginx 实现的灰度系统中，分流逻辑往往通过 rewrite 阶段的 if 和 rewrite 指令等实现，优点是`性能较高`，缺点是`功能受限`、`容易出错`，以及`转发规则固定，只能静态分流`。针对这些缺点，我们设计实现了ABTestingGateway，采用 ngx-lua 实现系统功能，通过启用[lua-shared-dict](http://wiki.nginx.org/HttpLuaModule#ngx.shared.DICT)和[lua-resty-lock](https://github.com/openresty/lua-resty-lock)作为系统缓存和缓存锁，系统获得了较为接近原生nginx转发的性能。

<div align="center"><img src="https://raw.githubusercontent.com/SinaMSRE/ABTestingGateway/master/doc/img/abtesting_architect.png" width="70%" height="70%"><p>ABTestingGateway 的架构简图</p></div>

如果在使用过程中有任何问题，欢迎大家来吐槽，一起完善、一起提高、一起使用！

email: bg2bkk@gmail.com  open.hfc@gmail.com

压测数据：[压测报告](https://github.com/WEIBOMSRE/ABTestingGateway/blob/master/doc/%E7%81%B0%E5%BA%A6%E5%8F%91%E5%B8%83%E7%B3%BB%E7%BB%9F%E5%8E%8B%E6%B5%8B%E6%8A%A5%E5%91%8A.pdf)

项目演讲：[演讲文档](https://github.com/WEIBOMSRE/ABTestingGateway/blob/master/doc/%E5%9F%BA%E4%BA%8E%E5%8A%A8%E6%80%81%E7%AD%96%E7%95%A5%E7%9A%84%E7%81%B0%E5%BA%A6%E5%8F%91%E5%B8%83%E7%B3%BB%E7%BB%9F.pdf)

Features:
----------

- 支持多种分流方式，目前包括iprange、uidrange、uid尾数和指定uid分流
- 动态设置分流策略，即时生效，无需重启
- 可扩展性，提供了开发框架，开发者可以灵活添加新的分流方式，实现二次开发
- 高性能，压测数据接近原生nginx转发
- 灰度系统配置写在nginx配置文件中，方便管理员配置
- 适用于多种场景：灰度发布、AB测试和负载均衡等

- new feature: ***支持多级分流***


灰度发布系统功能简介
-------------------

对于ab功能而言，步骤是以下三步：

1. 向系统添加策略，将策略写入策略数据库中
1. 为具体的server设置运行时信息，将某个分流策略设置为运行时策略
1. 之后可以进行分流操作

详细解释参见： [ab分流功能须知](doc/ab功能须知.md)

系统部署
=========================

软件依赖
------------------

* tengine or openresty
* ngx_lua	(可以从openresty软件包中获取最新版本)
* LuaJIT	(可以从openresty软件包中获取最新版本)
* lua-cjson (可以从openresty软件包中获取最新版本)
* redis-2.8.19

配置过程
------------------------

* 由于内部部署时以dygateway项目名部署，因此下文中的所有配置，都应将ABTestingGateway文件夹重命名为dygateway

[nginx.conf配置过程](doc/nginx_conf_配置过程.md)  

[redis.conf配置过程](doc/redis_conf_配置过程.md)  


系统使用
=========================

ab分流策略
-----------------

* ab功能目前支持的分流策略有
    * iprange: ip段分流
    * uidrange: 用户uid段分流
    * uidsuffix: uid尾数分流
    * uidappoint: uid白名单分流    

* 可以灵活添加新的分流方式

[ab分流策略格式和样例](doc/ab分流策略.md)

ab功能接口
------------------

* [ab功能接口说明文档](doc/ab功能接口使用介绍.md) 

```bash	
    * 策略管理：增删改查
    /ab_admin?action=policy_check
    /ab_admin?action=policy_set
    /ab_admin?action=policy_get
    /ab_admin?action=policy_del

    * 策略组管理（用于多级分流）
    /ab_admin?action=policygroup_check
    /ab_admin?action=policygroup_set
    /ab_admin?action=policygroup_get
    /ab_admin?action=policygroup_del

    * 运行时信息管理
        * 其中runtime_set接受policyid和policygroupid参数，分别用于单级分流和多级分流

    /ab_admin?action=runtime_get
    /ab_admin?action=runtime_set
    /ab_admin?action=runtime_del
```

压测结果：
-----------

<div align="center"><img src="https://raw.githubusercontent.com/SinaMSRE/ABTestingGateway/master/doc/img/load_line.png"><p>压测环境下灰度系统与原生nginx转发的对比图</p></div>

<div align="center"><img src="https://raw.githubusercontent.com/SinaMSRE/ABTestingGateway/master/doc/img/load_data.png"><p>压测环境下灰度系统与原生nginx转发的数据对比</p></div>

如图所示，用户请求完全命中cache是理想中的情况，灰度系统在理想情况下可以达到十分接近原生nginx转发的性能。

产生图中压测结果的场景是：用户请求经过proxy server转向upstream server，访问1KB大小的静态文件。

proxy server的硬件配置：

- CPU：E5620 2.4GHz 16核
- Mem：24GB
- Nic：千兆网卡，多队列，理论流量峰值为125MB/s

线上部署简图：
-----------
<div align="center"><img src="https://raw.githubusercontent.com/SinaMSRE/ABTestingGateway/master/doc/img/deployment.png"></div>


TODO LIST
----------------------------

* ab提供提供交互界面管理接口
    * 获取系统中所有策略、策略组

* ab的策略增加name字段，用于识别和操作name

* ab去cache策略

* dyupsc增加部分接口：keepalive字段等

* 每次的修改操作能够写在日志里记录起来
