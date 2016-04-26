ab分流策略格式
======================

* 分流策略 policy
* 分流策略组 policygroup

分流策略policy
--------------------------

```bash
{
    "divtype":"分流类型",
    "divdata":[
        {规则一},
        {规则二},
        {规则三},
        ...
    ]
}
```

* ab 灰度系统目前支持的策略有ip段分流、用户uid段分流、uid尾数分流、uid白名单分流    
* 可以灵活添加新的分流方式

```bash
#iprange分流，其中start和end为ip的整型表示。
{
	"divtype":"iprange",
	"divdata":[
		{"range":{"start":1111, "end":2222}, "upstream":"beta1"},
		{"range":{"start":3333, "end":4444}, "upstream":"beta2"},
		{"range":{"start":7777, "end":8888}, "upstream":"beta3"}
	]
}
```

```bash
#uid段分流
{
	"divtype": "uidrange",
	"divdata": [
		{"range":{"start":1111, "end":2222},  "upstream":"beta1"},
		{"range":{"start":3333, "end":4444}, "upstream":"beta2"}
   	 ]    
}
```

```bash
#uid尾数分流
{
	"divtype": "uidsuffix",
	"divdata": [
		{"suffix":1, "upstream":"beta1"},
		{"suffix":3, "upstream":"beta2"},
		{"suffix":5, "upstream":"beta1"},
		{"suffix":0, "upstream":"beta3"}
   	 ]    
}
```

```bash
#uid白名单分流	
{
	"divtype": "uidappoint",
	"divdata": [
		{"uidset":[1234,5124,653], "upstream":"beta1"},
		{"uidset":[3214,652,145], "upstream":"beta2"}
   	 ]    
}
```
* 当向系统添加分流策略时，需要将策略数据转为json类型字符串，以POST方式访问添加策略接口
* http://www.bejson.com/jsoneditoronline/  可以将上述策略转换为字符串，用以通过post方式向系统添加策略
* 以上四条策略的字符串格式分别为：
    * {"divtype":"iprange","divdata":[{"range":{"start":1111,"end":2222},"upstream":"beta1"},{"range":{"start":3333,"end":4444},"upstream":"beta2"},{"range":{"start":7777,"end":8888},"upstream":"beta3"}]}
    * {"divtype":"uidrange","divdata":[{"range":{"start":1111,"end":2222},"upstream":"beta1"},{"range":{"start":3333,"end":4444},"upstream":"beta2"}]}
    * {"divtype":"uidsuffix","divdata":[{"suffix":1,"upstream":"beta1"},{"suffix":3,"upstream":"beta2"},{"suffix":5,"upstream":"beta1"},{"suffix":0,"upstream":"beta3"}]}
    * {"divtype":"uidappoint","divdata":[{"uidset":[1234,5124,653],"upstream":"beta1"},{"uidset":[3214,652,145],"upstream":"beta2"}]}


分流策略组policygroup
--------------------------

* 分流策略组中会有多个策略
* 优先级由数字表示，从1开始，级别为1的策略优先级最高
* 分流策略组格式为：

```bash
{
    "1":{
        "divtype":"分流类型",
        "divdata":[
            {规则一},
            {规则二},
            ...
        ]
    },
    "2":{
    
    },
    ...
}
```
* 以下是一个包含两级分流策略，第一级为uid白名单分流策略，第二级为ip段分流

```bash
{

 "1":{
	"divtype": "uidappoint",
	"divdata": [
		{"uidset":[1234,5124,653], "upstream":"beta1"},
		{"uidset":[3214,652,145], "upstream":"beta2"}
   	 ]    
 },
 "2":{
    "divtype":"iprange",
    "divdata":[
                {"range":{"start":1111, "end":2222}, "upstream":"beta1"},
                {"range":{"start":3333, "end":4444}, "upstream":"beta2"},
                {"range":{"start":7777, "end":8888}, "upstream":"beta3"}
              ]
 }
}
```
* 该分流策略组的字符串形式为：
    * {"1":{"divtype":"uidappoint","divdata":[{"uidset":[1234,5124,653],"upstream":"beta1"},{"uidset":[3214,652,145],"upstream":"beta2"}]},"2":{"divtype":"iprange","divdata":[{"range":{"start":1111,"end":2222},"upstream":"beta1"},{"range":{"start":3333,"end":4444},"upstream":"beta2"},{"range":{"start":7777,"end":8888},"upstream":"beta3"}]}}


