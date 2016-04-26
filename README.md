
动态路由系统
=========================

* 动态路由系统 dygateway 主要由灰度发布系统ABTestingGateway（简称ab功能）和动态upstream member系统（简称dyups功能）组成，用于在7层上实现动态调度。     

* 实现的方式是:
    * ab功能决定将用户请求转发到哪个upstream
    * dyups功能统决定upstream里有哪些member
        * dyups可以运行时添加upstream
        * dyups可以在运行时向upstream内部添加server。
    * 通过两个子系统的合作，dygateway实现了动态调度功能。 


* 在介绍系统部署方法前，有必要对动态路由系统的各个功能做一定介绍:

ab功能简介
-------------------

对于ab功能而言，步骤是以下三步：

1. 向系统添加策略，将策略写入策略数据库中
1. 为具体的server设置运行时信息，将某个分流策略设置为运行时策略
1. 之后可以进行分流操作

详细解释参见： [ab分流功能须知](doc/ab功能须知.md)

dyups功能简介
----------------------

对于dyups功能而言，主要有如下功能：

1. 修改upstream的server列表，动态增减其中的server，设置权重等参数，无需重启系统
1. 动态增加或删除upstream，
1. 对upstream或server列表的修改，都会触发dump事件，将修改后的结果重新覆盖upstream.conf
1. 目前支持从redis中以pub/sub方式获取指令，实现集群。

系统部署
=========================

安装过程
-------------------

dygateway的软件包都在我们的软件仓库中,地址是 http://repos.sina.cn/custom-repos/mweibo/6/dygateway/ 

详见：[dygateway部署过程](doc/dygateway部署过程.md)

配置过程
------------------------

[nginx.conf配置过程](doc/nginx_conf_配置过程.md)  

[redis.conf配置过程](doc/redis_conf_配置过程.md)  

[dyupsc模块的初始化配置](doc/dyupsc模块的初始化配置.md)


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


dyupsc功能接口
------------------

* [dyupsc功能接口说明文档](doc/dyupsc功能接口使用介绍.md) 

```bash

    * 动态增删指定upstream中的server.
    /dyupsc_admin?action=remove_server
    /dyupsc_admin?action=remove_peer

    * 动态增删upstream.
    /dyupsc_admin?action=remove_upstream

    * 动态修改upstream中server的weight值.
    /dyupsc_admin?action=set_peer_weight
    
    * 动态修改upstream中server的 状态down or up.
        * 修改后端peer的max_fails值
        * 修改后端peer的fail_timeout值
    /dyupsc_admin?action=set_peer_down

    * 查看upstream中的信息: 
        * 查看upstream列表.
        * 查看upstream中server的列表.
        * 只查看后备服务器列表.
    /dyupsc_admin?action=get_upstreams
    /dyupsc_admin?action=get_primary_peers
    /dyupsc_admin?action=get_backup_peers
```

TODO LIST
----------------------------

* dyupsc与ab的互动
    * 设置运行时策略时，检查策略中的upstream是否存在
    * 删除upstream时，检测运行时策略中该upstream是否存在
    * dyupsc与ab共享utils，共享init

* ab提供提供交互界面管理接口
    * 获取系统中所有策略、策略组

* ab的策略增加name字段，用于识别和操作name

* ab去cache策略

* dyupsc增加部分接口：keepalive字段等

* 每次的修改操作能够写在日志里记录起来
