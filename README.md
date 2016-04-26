
基于动态策略的灰度发布系统
=========================

* ABTestingGateway 是一个可以动态设置分流策略的灰度发布系统，工作在7层，基于nginx和ngx-lua开发，使用 redis 作为分流策略数据库，可以实现动态调度功能。

* nginx是目前使用较多的7层服务器，可以实现高性能的转发和响应；ABTestingGateway 是在 nginx 转发的框架内，在转向 upstream 前，根据 用户请求特征 和 系统的分流策略 ，查找出目标upstream，进而实现分流。

* ABTestingGateway 是新浪微博内部的动态路由系统 dygateway 的一部分，主要功能是：

ab功能简介
-------------------

对于ab功能而言，步骤是以下三步：

1. 向系统添加策略，将策略写入策略数据库中
1. 为具体的server设置运行时信息，将某个分流策略设置为运行时策略
1. 之后可以进行分流操作

详细解释参见： [ab分流功能须知](doc/ab功能须知.md)

系统部署
=========================

安装过程
-------------------

详见：[dygateway部署过程](doc/dygateway部署过程.md)

配置过程
------------------------

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

TODO LIST
----------------------------

* ab提供提供交互界面管理接口
    * 获取系统中所有策略、策略组

* ab的策略增加name字段，用于识别和操作name

* ab去cache策略

* dyupsc增加部分接口：keepalive字段等

* 每次的修改操作能够写在日志里记录起来
