## IO系统设计思路

- 基本思路
	- 想将io系统做得更加纯粹.只和连接断开,收发包等相关,不需要参杂指令处理
	- 封装API,满足处理连接**地址+端口**的情况,以及通过**libimobiledevice**连接的情况.
	
 

- 简化API, 目前对外暴露的只包括以下几个API:
	- New: 新建io
	- Bind(id, type): 绑定到某个
	- Connect(id, type)



