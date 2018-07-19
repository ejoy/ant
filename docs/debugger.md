# 使用方法

1. 安装vscode。

2. 安装vscode-ant插件
https://gz-tea.ejoy.com/zhengweijian.zwj/vscode-ant

> 两种方法

* 用vscode打开vscode-ant目录，按F5，会启动一个新的vscode，在新的vscode里调试ant
* 将vscode-ant目录复制到vscode的插件目录，路径应该是%USERPROFILE%\.vscode\extensions\

3. 添加调试配置launch.json

```
        {
            "type": "lua",
            "request": "launch",
            "name": "Launch",
            "stopOnEntry": true,
            "runtimeExecutable": "${workspaceRoot}\\bin\\iup.exe",
            "runtimeArgs": "${workspaceRoot}\\libs\\dev\\Client\\clientwindow.lua",
            "console": "externalTerminal",
            "cwd": "${workspaceRoot}",
            "skipFiles": [
                "libs/new-debugger/*"
            ],
            "sourceMaps": [
                [
                    "./*",
                    "${workspaceRoot}/*"
                ]
            ]
        },
        {
            "type": "lua",
            "request": "attach",
            "name": "Attach",
            "stopOnEntry": true,
            "ip": "localhost",
            "port": 4278,
            "skipFiles": [
                "libs/new-debugger/*"
            ],
            "sourceMaps": [
                [
                    "./*",
                    "${workspaceRoot}/*"
                ]
            ]
        }
```

3. Attach调试。手动启动被调试目标，如

```
.\bin\iup.exe .\libs\dev\Client\clientwindow.lua
```

调试配置选择`Attach`，按F5

4. Launch调试

调试配置选择`Launch`，按F5

