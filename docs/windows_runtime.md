# windows客户端的测试方法

1. 编译客户端
```
 cd .\clibs\ant\ && make
 cd .\runtime\windows\ && make
```

2. 创建服务端repo
```
.\bin\lua.exe .\tools\repo\newrepo.lua "repo名"
```

3. 创建客户端repo
```
.\bin\lua.exe .\tools\repo\clientsetup.lua
```

4. 资源管理器打开服务端repo， %UserProfile%\Documents\repo名\
新建文件main.lua,写入
```lua
print 'hello world'
```

5. 启动服务端
```
.\bin\lua.exe .\test\fileserver.lua "repo名"
```

6. 启动客户端
```
.\runtime\windows\ant.exe
```
