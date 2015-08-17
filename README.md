基于动态策略的灰度发布系统
========================

这是一个基于动态策略的灰度发布系统，基于nginx-lua开发，可以动态替换分流策略，实现动态调度功能。

Features:
----------

- 基于nginx和ngx-lua开发
- 支持多种分流方式，目前包括iprange、uidrange、uid尾数和指定uid分流等
- 动态设置分流策略，即时生效，无需重启
- 可扩展性，灵活添加新的分流方式
- 高性能，压测数据接近原生nginx转发
- 灰度系统配置写在nginx配置文件中，方便管理员配置
- 适用于多种场景：灰度发布、AB测试和负载均衡等

快速部署:
----------
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


接口说明:
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

接口使用:
----------

软件版本：
-----------
- tengine-2.1.0
- LuaJIT-2.1-20141128
- ngx_lua-0.9.13
- lua-cjson-2.1.0.2
- redis-2.8.19


