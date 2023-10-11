### 环境
1. 下载VSCode
2. 安装插件lua-debug插件，`Ctrl+P`然后输入`ext install actboy168.lua-debug`
3. 配置调试配置

### 本地调试（编辑模式）
``` json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "lua",
            "request": "launch",
            "name": "Debug",
            "luaexe": "${workspaceFolder}/bin/msvc/debug/vaststars.exe",
            "console": "integratedTerminal",
            "stopOnEntry": true,
            "luaVersion": "lua-latest",
            "outputCapture": [],
            "program": "",
            "arg": [
            ]
        },
    ]
 }
```

### 本地调试（运行时模式）

``` json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "lua",
            "request": "launch",
            "name": "Debug",
            "luaexe": "${workspaceFolder}/bin/msvc/debug/vaststars_rt.exe",
            "console": "integratedTerminal",
            "sourceMaps": [
                [
                    "/engine/*",
                    "${workspaceFolder}/3rd/ant/engine/*"
                ],
                [
                    "/pkg/ant.*",
                    "${workspaceFolder}/3rd/ant/pkg/ant.*"
                ],
                [
                    "/pkg/vaststars.*",
                    "${workspaceFolder}/startup/pkg/vaststars.*"
                ],
                [
                    "/*",
                    "${workspaceFolder}/startup/*"
                ]
            ],
            "outputCapture": [],
            "program": ""
        },
    ]
 }
```

### 远程调试（运行时模式）

``` json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "lua",
            "request": "attach",
            "name": "Debug",
            "address": "127.0.0.1:4378",
            "outputCapture": [],
        },
    ]
 }
```
