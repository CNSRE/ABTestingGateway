ab功能接口介绍
===================

ab管理接口
------------------

```bash	
#策略管理
* /ab_admin?action=policy_check
* /ab_admin?action=policy_set
* /ab_admin?action=policy_get
* /ab_admin?action=policy_del

#策略组管理（用于多级分流）
* /ab_admin?action=policygroup_check
* /ab_admin?action=policygroup_set
* /ab_admin?action=policygroup_get
* /ab_admin?action=policygroup_del

#运行时信息设置（其中runtime_set接受policyid和policygroupid参数，分别用于单级分流和多级分流）
* /ab_admin?action=runtime_get
* /ab_admin?action=runtime_set
* /ab_admin?action=runtime_del
```
* 1.检查策略是否合法                    
    * http://localhost:port/ab_admin?action=policy_check -d '{"divtype":"uidsuffix","divdata":[{"suffix":"1","upstream":"beta1"},{"suffix":"3","upstream":"beta2"},{"suffix":"5","upstream":"beta1"},{"suffix":"0","upstream":"beta3"}]}'
    * 接口说明:
        * action: 代表要执行的操作，检查策略接口为policy_check
        * 仅接受POST方法，POST数据为待检查策略的json字符串
        * 返回值：{"code":200,"desc":"success "}，系统中如果返回非200的code码，就认为是发生错误，desc为错误信息。
        * 错误返回值：{"code":50102,"desc":"parameter error for postData is not a json string"} 如果出错，返回错误码与对应错误信息，反馈给用户，其他接口同样。


* 2.向系统添加策略                    
    * http://localhost:port/ab_admin?action=policy_set -d '{"divtype":"uidsuffix","divdata":[{"suffix":"1","upstream":"beta1"},{"suffix":"3","upstream":"beta2"},{"suffix":"5","upstream":"beta1"},{"suffix":"0","upstream":"beta3"}]}'`
  
    * 接口说明:    
        * action: 代表要执行的操作
        * 仅接受POST方法，POST数据为待检查策略的json字符串
        * 返回值：{"code":200,"desc":"success  the id of new policy is 20"}，策略添加成功，返回策略号policyid，样例中policyid为20

* 3.从系统读取策略                    
    * http://localhost:port/ab_admin?action=policy_get&policyid=20
  
    * 接口说明:    
        * 参数：action: 代表要执行的操作
        * 参数：policyid: 获取第policyid号策略
        * 返回值：{"desc":"success ","code":200,"data":{"divdata":["1","beta1","3","beta2","5","beta1","0","beta3"],"divtype":"uidsuffix"}} 返回值中data部分是读取的策略数据，json格式。

* 4.从系统删除策略                    
    * http://localhost:port/ab_admin?action=policy_del&policyid=20
  
    * 接口说明:    
        * 参数：action: 代表要执行的操作
        * 参数：policyid: 删除第policyid号策略
        * 返回值：{"code":200,"desc":"success "}

* 5.检查策略组是否合法                    
    * http://localhost:port/ab_admin?action=policygroup_check -d '{"1":{"divtype":"uidappoint","divdata":[{"uidset":[1234,5124,653],"upstream":"beta1"},{"uidset":[3214,652,145],"upstream":"beta2"}]},"2":{"divtype":"iprange","divdata":[{"range":{"start":1111,"end":2222},"upstream":"beta1"},{"range":{"start":3333,"end":4444},"upstream":"beta2"},{"range":{"start":7777,"end":8888},"upstream":"beta3"}]}}
  
    * 接口说明:    
        * action: 代表要执行的操作，检查策略接口为policygroup_check
        * 仅接受POST方法，POST数据为待检查策略的json字符串
        * 返回值：{"code":200,"desc":"success "}，系统中如果返回非200的code码，就认为是发生错误，desc为错误信息。
        * 错误返回值：{"code":50102,"desc":"parameter error for postData is not a json string"} 如果出错，返回错误码与对应错误信息，反馈给用户，其他接口同样。


* 6.向系统添加策略组                    
    * http://localhost:port/ab_admin?action=policygroup_set -d '{"1":{"divtype":"uidappoint","divdata":[{"uidset":[1234,5124,653],"upstream":"beta1"},{"uidset":[3214,652,145],"upstream":"beta2"}]},"2":{"divtype":"iprange","divdata":[{"range":{"start":1111,"end":2222},"upstream":"beta1"},{"range":{"start":3333,"end":4444},"upstream":"beta2"},{"range":{"start":7777,"end":8888},"upstream":"beta3"}]}}
  
    * 接口说明:    
        * action: 代表要执行的操作
        * 仅接受POST方法，POST数据为待检查策略的json字符串
        * 返回值：{"desc":"success ","code":200,"data":{"groupid":2,"group":[11,12]}}，策略组添加成功，返回策略组号groupid是2，组中包括两个策略，策略id分别是11和12.

* 7.从系统读取策略组                    
    * http://localhost:port/ab_admin?action=policygroup_get&policygroupid=2
  
    * 接口说明:    
        * 参数：action: 代表要执行的操作
        * 参数：policyid: 获取第policygroupid号策略组
        * 返回值：{"desc":"success ","code":200,"data":{"groupid":2,"group":["11","12"]}} 返回值以json格式返回该组策略中包括哪些策略。

* 8.从系统删除策略组                    
    * http://localhost:port/ab_admin?action=policygroup_del&policygroupid=2
  
    * 接口说明:    
        * 参数：action: 代表要执行的操作
        * 参数：policyid: 删除第policygroupid号策略组
        * 返回值：{"code":200,"desc":"success "}

* 9.设置***策略***为系统的运行时策略，进行单级分流         
    * http://localhost:port/ab_admin?action=runtime_set&policyid=22&hostname=api.weibo.cn
  
    * 接口说明:    
        * 参数：action: 代表要执行的操作
        * 参数：policyid: 设置第policyid号策略为运行时策略
        * 参数：hostname：非常重要，向server api.weibo.cn绑定运行时信息，或向location /abc @server api.weibo.cn绑定运行时信息
        * 返回值：{"code":200,"desc":"success "}
        * 注意：设置运行时信息的动作会导致原来数据库中的运行时信息删除，不论本次设置是否成功

* 10.设置***策略组***为系统的运行时策略，进行多级分流
    * http://localhost:port/ab_admin?action=runtime_set&policygroupid=4&hostname=api.weibo.cn
  
    * 接口说明:    
        * 参数：action: 代表要执行的操作
        * 参数：policygroupid: 设置第policygroupid号策略组   为   运行时策略
        * 参数：hostname: 为host api.weibo.cn设置运行时策略
        * 返回值：{"code":200,"desc":"success "}
        * 返回值：若发生错误，则有相关提示，比如某策略不存在。

        * 请注意：将 策略  或者 策略组 设置为运行时策略的接口是一样的，区别的方式在于参数是policyid还是policygroupid，所以要注意不要写错。
        * 请注意：设置运行时信息的动作会导致原来数据库中的运行时信息删除，不论本次设置是否成功


* 11.获取系统运行时信息 
    * http://localhost:port/ab_admin?action=runtime_get&hostname=api.weibo.cn
  
    * 接口说明:    
        * 参数：action: 代表要执行的操作，获取系统运行时信息runtime_get
        * 参数：hostname: 获取hostname主机的运行时信息
        * 系统未设置运行时信息时，返回值{"desc":"success ","code":200,"data":{"divsteps":0,"runtimegroup":{}}}
        * 系统设置运行时信息后，举例为：

```bash
        {
            "desc": "success ",
            "code": 200,
            "data": {
                "divsteps": 2,
                "runtimegroup": {
                    "second": {
                        "divModulename": "abtesting.diversion.iprange",
                        "divDataKey": "ab:test:policies:16:divdata",
                        "userInfoModulename": "abtesting.userinfo.ipParser"
                    },
                    "first": {
                        "divModulename": "abtesting.diversion.uidappoint",
                        "divDataKey": "ab:test:policies:15:divdata",
                        "userInfoModulename": "abtesting.userinfo.uidParser"
                    }
                }
            }
        }
        # divsteps表示几级分流
        # runtimegroup是分流信息，以first、second等作为下标，最多十级分流       
        # divModulename为运行时的分流模块名
        # userInfoModulename为运行时的用户信息提取模块名
        # divDataKey为运行时的分流策略名
```

* 12.删除系统运行时信息                   
    * http://localhost:port/ab_admin?action=runtime_del&hostname=api.weibo.cn
  
    * 接口说明:    
        * 参数：action: 代表要执行的操作，删除系统运行时信息runtime_del
        * 返回值：{"code":200,"desc":"success "}

ab分流接口
------------------

* ab分流接口目前只能配置为 location /   
* 以***ab管理接口***小节中的第11条获取运行时信息为例，第一级是uidappoint白名单分流，第二级是iprange ip段分流方式

* curl http://localhost:port/ -H 'Host:api.weibo.cn' -H 'X-Uid:30'
    * HOST字段是每个合法用户请求都有的，从HTTP 请求头中获取
    * 在匹配到virtual host和location后，分流功能通过location中设置的***hostkey***字段找到运行时信息，然后进行下一步的分流。
    * 因此location中的***$hostkey***字段是分流的基础，这里与ab管理功能中的设置运行时信息中的hostname参数一样

response格式
------------------

系统response采用json方式返回，resp包括返回码**code**、调用信息**desc**和调用结果**data**：

* 操作成功   
{***"code"***:200, ***"desc"***:"success", ***"data"***:["stable","beta1","beta2","beta3","beta4","beta5"]}

* 操作错误   
{***"code"***:500, ***"desc"***:"Invalid operation: get_upstream"}


