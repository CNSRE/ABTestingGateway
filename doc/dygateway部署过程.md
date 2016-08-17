动态路由系统部署使用
=========================

* dygateway主要包括ab和dyupsc两个子系统，采用redis作为数据库。   

* dygateway的配置参数全部都在nginx.conf中，以nginx变量的方式产生作用。配置文件提供了nginx和redis的最小示例.
    * /usr/local/dygateway/utils/conf/nginx.conf 
    * /usr/local/dygateway/utils/conf/redis.conf
    
* dygateway的软件包都在我们的软件仓库中,地址是 http://repos.sina.cn/custom-repos/mweibo/6/dygateway/, 涉及到以下软件包（忽略版本号，可能不是最新的）：

    * LuaJIT-2.1
    * lua-cjson-2.1.0.2
    * tengine-2.1.2
    * dygateway
    * redis-3.0.7



部署过程
-------------------

<!-- 从部署方式一节可以看到，dygateway系统中有管理机和七层机器两个角色，两种机器上的软件包和代码完全一样，区别在于nginx配置文件不同，以及redis的主从角色不同。-->

* dygateway系统采用单节点方式部署
    * tengine的安装地址与之前一样，nginx在/usr/sbin，nginx.conf在/etc/nginx
    * dygateway安装在/usr/local/dygateway中，也是系统配置中的lua代码路径
    * 每个节点的软件包与代码版本一样，nginx与redis的配置一样。
    * 分流策略和配置信息存储在每台机器的redis中，nginx重启后不会丢失之前的配置信息。由于分流策略和分流配置信息的数据量比较小，所以普通的redis持久化设置就可以。

```bash
rpm -Uvh http://repos.sina.cn/custom-repos/mweibo/6/dygateway/LuaJIT-2.1-1.mweibo.el6.x86_64.rpm
rpm -Uvh http://repos.sina.cn/custom-repos/mweibo/6/dygateway/lua-cjson-2.1.0.2-1.el6.x86_64.rpm
rpm -Uvh http://repos.sina.cn/custom-repos/mweibo/6/dygateway/dygateway-2.0-20160324.mweibo.el6.noarch.rpm
rpm -Uvh http://repos.sina.cn/custom-repos/mweibo/6/dygateway/tengine-2.1.2-20160323.mweibo.el6.x86_64.rpm

rpm -Uvh http://repos.sina.cn/custom-repos/mweibo/6/dygateway/redis-3.0.7-2.el6.remi.x86_64.rpm
```




