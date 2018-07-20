# 使用方法

1. 安装vscode。

2. clone https://gz-tea.ejoy.com/zhengweijian.zwj/vscode-ant，和ant目录平行
    |-D:/WORK
        |- ant
        |- vscode-ant

3. 用vscode打开vscode-ant目录，按F5，会启动一个新的vscode，在新的vscode里打开ant目录

4. 添加调试配置launch.json

```
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "lua",
            "request": "launch",
            "name": "Editor",
            "runtimeExecutable": "${workspaceRoot}\\bin\\iup.exe",
            "runtimeArgs": "${workspaceRoot}\\libs\\main.lua",
            "console": "integratedTerminal",
            "cwd": "${workspaceRoot}",
            "stopOnEntry": false,
        },
        {
            "type": "lua",
            "request": "launch",
            "name": "Launch",
            "stopOnEntry": true,
            "runtimeExecutable": "${workspaceRoot}\\bin\\iup.exe",
            "runtimeArgs": "${workspaceRoot}\\libs\\dev\\Client\\clientwindow.lua",
            "console": "integratedTerminal",
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
    ]
}
```

5. Attach调试。手动启动被调试目标，如

```
.\bin\iup.exe .\libs\dev\Client\clientwindow.lua
```

调试配置选择`Attach`，按F5

6. Launch调试

调试配置选择`Launch`，按F5


7. Editor调试

调试配置选择`Editor`，按F5
