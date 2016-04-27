ab分流功能须知
-------------------

对于ab功能而言，步骤是以下三步：

1. 向系统添加策略，将策略写入策略数据库中
1. 为具体的server设置运行时信息，将某个分流策略设置为运行时策略
1. 之后可以进行分流操作

###  1. 向系统添加策略 ###
向系统中添加分流策略的过程，本质上是将分流策略写入到系统的redis中，这个过程与具体哪个server没有关系，只是将分流策略以id为key存入redis中。本系统采用***ab:test:policies***为策略前缀，比如某个策略写入redis成功后，返回policyId=1, 那么在redis中，key为***ab:test:policyies:1:divtype***和***ab:test:policyies:1:divdata***将用来存储策略1的类型type和规则。
同样的，向系统添加分流策略组，首先将策略组中的单个策略写入系统中，然后返回策略组的policyGroupId。

###  2. 为具体的server设置运行时信息 ###
将某个策略设置成server的运行时策略，最终将这个运行时信息写入到redis中。运行时信息包括三个元素，分流模块名divModuleName，分流策略名divDataKey和用户信息提取模块名userInfoModuleName；运行时信息以***ab:test:runtimeInfo***为前缀；server name为redis中key的关键部分，用于甄别不同server的运行时信息。最终redis中存储的运行时信息是

```bash
    ab:test:runtimeInfo:xxx.weibo.cn:first:divModulename
    ab:test:runtimeInfo:xxx.weibo.cn:first:divDataKey
    ab:test:runtimeInfo:xxx.weibo.cn:first:userInfoModulename

    ab:test:runtimeInfo:xxx.weibo.cn:second:divModulename
    ab:test:runtimeInfo:xxx.weibo.cn:second:divDataKey
    ab:test:runtimeInfo:xxx.weibo.cn:second:userInfoModulename

    # ab:test:runtimeInfo 为前缀
    # xxx.weibo.cn  是server name
    # first和second分别表示第一级分流和第二级分流
    # divModulename等是运行时信息的元素
```
因此设置运行时信息时，server name是关键。 
运行时信息设置的接口是
    
    /ab_admin?action=runtime_set&policyid=0&hostname=xxx.weibo.cn

向hostname=xxx.weibo.cn设置运行时信息，完全是在访问runtime_set接口时的hostname参数中指定的。   
因此，如果引入location级别的运行时信息，我们只需要在调用runtime_set接口时指定hostname就可以。这个hostname同时在location中指定，比如对location /abc设置分流信息时，hostname指定为xxx.weibo.cn.abc，这样在对访问/abc接口的请求进行分流时，以xxx.weibo.cn.abc为key的分流信息生效（例如 ab:test:runtiemInfo:xxx.weibo.cn.abc:divModulename）。具体配置方法见下文

###  3. 对用户请求进行分流 ###
对用户请求进行分流的过程：

1. 提取用户请求的HOST字段，拿到以***ab:test:runtimeInfo***和***HOST***为前缀的运行时信息的三要素
2. 用户信息提取模块userInfoModule提取用户信息userInfo
3. 分流模块divmodule根据分流策略divDataKey和userInfo计算得到对应的upstream，转发；如果没有对应的upstream，则转向默认upstream。

在引入location级别的分流设置后，需要对访问同一个servername的不同location进行甄别，这里将第一步中从用户请求中获取
HOST字段，改为在location配置块中预先设置HOST字段，其效果是一样的。

```bash
	curl http://ip:port/abc?city=BJ -H 'X-Uid:30' -H 'Host:whatever'

	该请求访问/abc接口，在location接口中已经指定了server name是xxx.weibo.cn.abc，那么分流工作就按步骤进行。配置如下所示：
	location ~* /abc/(i|f)/ {
		set $hostkey $server_name.abc;

		rewrite_by_lua_file '/usr/local/dygateway/diversion/diversion.lua';
		proxy_pass http://$backend;
	}
```


