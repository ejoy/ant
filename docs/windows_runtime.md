# windows客户端的测试方法

1. 编译客户端
```
 cd .\clibs\ant\ && make
 cd .\runtime\windows\ && make
```

2. 创建服务端repo
```
.\bin\lua.exe .\tools\repo\newrepo.lua "服务端repo名"
```

3. 创建客户端repo（不要和服务端的相同）
```
.\bin\lua.exe .\tools\repo\clientsetup.lua "客户端repo名"
```

4. 启动服务端
```
.\bin\lua.exe .\test\fileserver.lua "服务端repo名"
```

5. 启动客户端
```
.\runtime\windows\ant.exe "客户端repo名"
```
