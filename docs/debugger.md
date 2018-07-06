# 使用方法

1. 安装vscode。

2. 安装lua-debug插件（只是暂时借用它的调试前端）

3. 添加调试配置launch.json

```
        {
            "type": "lua",
            "request": "attach",
            "name": "TestDebugger",
            "stopOnEntry": true,
            "ip": "localhost", // 调试目标的ip
            "port": 4278
        }
```

3. 启动client。windows下的方法为

```
cd .\libs\dev\Client\ && .\..\..\..\bin\iup.exe clientwindow.lua
```

4. F5
