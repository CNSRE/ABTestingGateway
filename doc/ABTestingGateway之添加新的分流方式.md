ABTestingGateway 的基于分流策略的动态更新来实现动态调度的。
当开发者需要结合自身需求添加新的分流方式时，首先需要为其指定分流策略divPolicy，然后开发分流模块divModule和响应的信息提取模块uesrInfoModule。
下面我们以一个小例子来说明添加新分流方式的方法，我们的新需求是按照请求url的arg参数中的city字段分流。

###为新的分流方式制定分流策略
ABTestingGateway的分流策略有固定格式：
```bash
{
"divtype":"arg_city",
"divdata":[
{"city":"BJ", "upstream":"beta1"},
{"city":"SH", "upstream":"beta2"},
{"city":"TJ", "upstream":"beta1"},
{"city":"CQ", "upstream":"beta3"}]
}
```
分流策略的divtype在下一步是分流模块名的关键部分。
分流策略的divdata是策略内容，由于是按照city字段分流，这种kv形式的策略，在数据库层面可以采用redis的hash实现，在缓存层可以采用ngx_lua的sharedDict实现。

###开发分流模块divModule

ABTestingGateway的分流模块都在**/lib/abtesting/diversion/**文件夹中，其下的每个lua文件是一个分流模块，比如iprange分流方式的分流模块就是**lib/abtesting/diversion/iprange.lua**，而我们的arg_city分流方式根据divtype就是**lib/abtesting/diversion/arg_city.lua**。

分流模块主要有两个功能，一是分流策略的管理功能，包括检查策略合法、添加策略set、读取策略get；二是分流功能getUpstream，这个接口得到用户请求对应的upstream。

arg_city.lua是一个典型Lua Module实现：
```lua
local modulename = "abtestingDiversionArgCity"

local _M    = {}
local mt    = { __index = _M }
_M._VERSION = "0.0.1"

_M.new = function(self, database, policyLib)
    self.database = database
    self.policyLib = policyLib
    return setmetatable(self, mt)
end

_M.check = function(self, policy)
	...
end

_M.set = function(self, policy)
	...
end

_M.get = function(self)
	...
end

_M.getUpstream = function(self, city)
	...
end

return _M
```

####1. 分流模块初始化方法
```lua
_M.new = function(self, database, policyLib)
    if not database then
        error{ERRORINFO.PARAMETER_NONE, 'need avaliable redis db'}
    end if not policyLib then
        error{ERRORINFO.PARAMETER_NONE, 'need avaliable policy lib'}
    end

    self.database = database
    self.policyLib = policyLib
    return setmetatable(self, mt)
end
```
在分流模块初始化方法中，database是策略数据库，目前是redis；policyLib是分流策略在数据库中的key。
而
```lua
	error{ERRORINFO.PARAMETER_NONE, 'need avaliable redis db'}
```
是ABTestingGateway设计的基于xpcall的防御性机制，用于处理捕获异常。**ERRORINFO**作为系统的错误码编号，具体内容在**/lib/abtesting/error/errcode.lua**中
####2.策略检查 check方法
主要功能是对用户输入的策略进行合法性检查
```lua
_M.check = function(self, policy)

    for _, v in pairs(policy) do
        local city      = v[k_city]
        local upstream  = v[k_upstream]

        if not city or not upstream then
            local info = ERRORINFO.POLICY_INVALID_ERROR 
            local desc = ' need '..k_city..' and '..k_upstream
            return {false, info, desc}
        end

    end

    return {true}
end
```

####3.策略添加 set方法
向系统中添加用户策略，这里的策略policy是经过check后的。
```lua
_M.set = function(self, policy)
    local database  = self.database 
    local policyLib = self.policyLib

    database:init_pipeline()
    for _, v in pairs(policy) do
        database:hset(policyLib, v[k_city], v[k_upstream])
    end
    local ok, err = database:commit_pipeline()
    if not ok then 
        error{ERRORINFO.REDIS_ERROR, err} 
    end
end
```
arg_city的分流策略在redis中采用hash结构存储。

####4.策略读取 get方法
从数据库中读取用户策略的数据
```lua
_M.get = function(self)
    local database  = self.database 
    local policyLib = self.policyLib

    local data, err = database:hgetall(policyLib)
    if not data then 
        error{ERRORINFO.REDIS_ERROR, err} 
    end

    return data
end
```
目前只是将策略数据从redis中读出，然后以json形式发送给client，至于如何解析json字符串为策略数据，可以在系统的/admin/policy/get接口实现，也可以在client中实现。目前ABTestingGateway没有实现。


####5.获取用户请求对应的upstream
从数据库中读取用户策略的数据
```lua
_M.getUpstream = function(self, city)    
    local database	= self.database
    local policyLib = self.policyLib
    
    local upstream, err = database:hget(policyLib , city)
    if not upstream then error{ERRORINFO.REDIS_ERROR, err} end
    
    if upstream == ngx.null then
        return nil
    else
        return upstream
    end
end
```
分流模块获取upstream的方法，策略key为policylib，用户请求特征为city。getUpstream得到结果后返回，系统分流接口将请求转发至目标upstream。

###分流方式对应的 用户特征提取模块
在getUpstream方法中，分流模块根据用户请求中的city来计算upstream，这个city相当于用户请求特征。每种分流方式需要指定用户特征提取模块，由它提取用户请求的特征。

分流策略中的divtype将用来指定用户特征提取模块。ABTestingGateway的所有用户特征提取模块都在**lib/abtesting/userinfo/**文件夹，其下的每个lua文件是一个分流模块。

在**lib/abtesting/utils/init.lua**中
```lua
_M.divtypes = {
    ["iprange"]     = 'ipParser',  
    ["uidrange"]    = 'uidParser',
    ["uidsuffix"]   = 'uidParser',
    ["uidappoint"]  = 'uidParser',
    ["arg_city"]    = 'cityParser'
}
```
每种divtype会有对应的提取模块，因此divtype为arg_city的分流方式对应的用户信息提取模块就是**lib/abtesting/userinfo/cityParser.lua**。

以上就是向系统添加新的分流方式的具体步骤。最新的代码已提交至repo中。
