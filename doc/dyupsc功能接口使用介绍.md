
dyupsc功能接口介绍
=========================
  * 1.动态增删指定upstream中的server.
  * 2.动态增删upstream.
  * 3.动态修改upstream中peer的weight值.
  * 4.动态修改upstream中peer的max_fails值.
  * 5.动态修改upstream中peer的fail_timeout值.
  * 6.动态修改upstream中peer的状态down or up.
  * 7.查看upstream中的信息:   
      * 查看upstream列表.
      * 查看upstream中server的列表.
      * 只查看后备服务器列表.

使用方法
====
   提供下列REST HTTP接口,形如"127.0.0.1:80/dyupsc_admain?action=${opreation_name}&args=${operation_args}":  
   
   * 1.给upstream中servers增加一个server                 
     `http://localhost:port/dyupsc_admin?action=add_server&upstream=bar&ip=127.0.0.1&port=81&weight=2&maxfails=2&failtimeout=10`        
     其中参数说明:    
     * action: 代表要执行的操作
     * upstream: 操作当前nginx那个upstream
     * ip: 新增加server的ip
     * port: 新增加server的port
     * weight: 为新的server设置权值,注意(该参数是可选参数default 1)
     * maxfails: 为新的server设置max_fails,注意(该参数是可选参数default 1)
     * failtimeout: 为新的server设置fail_timeout,注意(该参数是可选参数default 10)
     
   * 2.给upstream中后端peers增加一个peer             
     `http://localhost:port/dyupsc_admin?action=add_peer&upstream=bar&ip=127.0.0.1&port=81`        
     其中参数说明:    
     * action: 代表要执行的操作
     * upstream: 操作当前nginx那个upstream
     * ip: 新增加server的ip
     * port: 新增加server的port

   * 3.删除upstream中servers的一个server            
     `http://localhost:port/dyupsc_admin?action=remove_server&upstream=bar&ip=127.0.0.1&port=81`        
     其中参数说明:    
     * action: 代表要执行的操作
     * upstream: 操作当前nginx那个upstream
     * ip: 新增加server的ip
     * port: 新增加server的port


   * 4.删除upstream中后端peers的一个peer           
     `http://localhost:port/dyupsc_admin?action=remove_peer&upstream=bar&ip=127.0.0.1&port=81`        
     其中参数说明:    
     * action: 代表要执行的操作
     * upstream: 操作当前nginx那个upstream
     * ip: 新增加server的ip
     * port: 新增加server的port   
     `注意:`每个upstream中最少有一个peer，所以remove_peer是upstream的最后一个primary peer，或者最后一个backup peer时，为了安全起见，都不会删除。    


   * 5.查看upstream中的servers信息           
     `http://localhost:port/dyupsc_admin?action=get_serves`        
     其中参数说明:    
     * action: 代表要执行的操作


   * 6.查看upstream中后端peers信息           
     `http://localhost:port/dyupsc_admin?action=get_primary_peers`        
     其中参数说明:    
     * action: 代表要执行的操作


   * 7.查看指定机器nginx的upetreams信息           
     `http://localhost:port/dyupsc_admin?action=get_upstreams`        
     其中参数说明:    
     * action: 代表要执行的操作


   * 8.查看upstream中后备peers信息(状态为backup的peer)          
     `http://localhost:port/dyupsc_admin?action=get_backup_peers`        
     其中参数说明:    
     * action: 代表要执行的操作
     
   * 9.设置后端peer的weight的值          
     `http://localhost:port/dyupsc_admin?action=set_peer_weight&upstream=bar&backup=false&id=0&value=3`        
     其中参数说明:    
     * action: 代表要执行的操作
     * upstream: 操作当前nginx那个upstream     
     * backup: 表示当前操作的peer是否是backup,取值true[是backup] or false[不是backup]
     * id: 代表所要操作的peer在当前upstream列表中的位置,即下标(从０开始)
     * value: 代表要为指定peer设定的新的权值weight
     
   * 10.设置后端peer的max_fails的值           
     `http://localhost:port/dyupsc_admin?action=set_peer_max_fails&upstream=bar&backup=false&id=0&value=true`        
     其中参数说明:    
     * action: 代表要执行的操作
     * upstream: 操作当前nginx那个upstream     
     * backup: 表示当前操作的peer是否是backup,取值true[是backup] or false[不是backup]
     * id: 代表所要操作的peer在当前upstream列表中的位置,即下标(从０开始)
     * value: 代表要为指定peer设定新的max_fails值
     
   * 11.设置后端peer的fail_timeout的值           
     `http://localhost:port/dyupsc_admin?action=set_peer_fail_timeout&upstream=bar&backup=false&id=0&value=true`        
     其中参数说明:    
     * action: 代表要执行的操作
     * upstream: 操作当前nginx那个upstream     
     * backup: 表示当前操作的peer是否是backup,取值true[是backup] or false[不是backup]
     * id: 代表所要操作的peer在当前upstream列表中的位置,即下标(从０开始)
     * value: 代表要为指定peer设定新的fail_timeout值，单位是s

   * 12.设置后端peer状态为down or up          
     `http://localhost:port/dyupsc_admin?action=set_peer_down&upstream=bar&backup=false&id=0&value=true`        
     其中参数说明:    
     * action: 代表要执行的操作
     * upstream: 操作当前nginx那个upstream     
     * backup: 表示当前操作的peer是否是backup,取值true[是backup] or false[不是backup]
     * id: 代表所要操作的peer在当前upstream列表中的位置,即下标(从０开始)
     * value: 代表要为指定的peer设定新的状态,取值true[设置为down] or false[设置为up]
     
   * 13.增加一个upstream为指定nginx           
     `http://localhost:port/dyupsc_admin?action=add_upstream&upstream=new_bar&servers=server 127.0.0.1:81;server 127.0.0.1:82;`        
     其中参数说明:    
     * action: 代表要执行的操作
     * upstream: 为当前nginx那个upstream的名称
     * servers: 指定新的upstream中的server信息   
     `注意:`最少要有一个server,若新增加的upstream的名字是nginx中已经有的upstream,则会覆盖调旧的upstream信息.    
     `注意:`其中servers字段不同的server之间要使用分号";"隔开.            

   * 14.删除一个upstream给指定nginx            
     `http://localhost:port/dyupsc_admin?action=remove_upstream&upstream=new_bar`        
     其中参数说明:    
     * action: 代表要执行的操作
     * upstream: 想要删除的那个upstream的名称   

[目录](#目录)

响应字段含义
====
上述使用方法都是使用的rest http的方式,其http响应结果是json字符串形如:     

### 修改操作:       
`curl "127.0.0.1:8045/dyupsc_admin?action=add_server&upstream=bar&ip=127.0.0.1&port=82" `
```json
{
    "code": 200,
    "desc": "success", 
    "data": "add_server success"
}
```   

### 查询操作:          
`curl   "http://localhost:port/dyupsc_admin?action=get_serves"`   

```json  
{
    "code": 200,
    "data": {
        "bar": [
            {
                "addr": "127.0.0.1:80",
                "fail_timeout": 10,
                "max_fails": 1,
                "weight": 1
            },
            {
                "addr": "127.0.0.1:81",
                "fail_timeout": 10,
                "max_fails": 1,
                "weight": 1
            }
        ]
    }
}
```  

其中json的结构总共分为2个字段:    

*  1.code字段含义:        
     code表示其该次操作的请求响应码[200表示执行成功,500表示操作失败].     
* 如果code是200则:        
 * data字段含义:              
     data表示其数据部分[若该操作是修改操作,则数据字段表示操作的结果的信息.若是查询操作:则data字段是查询返回的数据].    
 * desc字段含义:     
     返回成功操作的描述信息.      
* 如果code非200:   
 * desc字段含义:      
     返回失败操作的描述信息.      

[目录](#目录)



使用注意
====
### 一.其中`add_server`和`add_peer`两个操作的解析:   

* add_server:   
  * 该操作是向指定upstream中的servers列表中增加一个server.       
* add_peer: 
  * 该操作是向指定upstream中的后端peers列表中增加一个peer(真正的后端机器)在进行增加peer的时候会进行查询这个peer是否在upstream中的servers列表中,若不在是不允许添加的
所以在执行`add_peer`之前一定要执行`add_server`操作.        

[目录](#目录)

