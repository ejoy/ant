### 环境
1. 下载VSCode
2. 安装插件lua-debug插件，`Ctrl+P`然后输入`ext install actboy168.lua-debug`
3. 在VSCode里，打开ant目录
4. 配置调试配置，将下面的配置复制到`.vscode/launch.json`里

### 调试编辑器

1. 打开VSCode调试面板，选择`Editor (mingw)`或`Editor (msvc)`，按F5

### 调试windows运行时

1. 启动fileserver, `./clibs/lua.exe tools/fileserver/main.lua`
2. 启动运行时, `./runtime/windows/ant.exe <需要调试的项目路径>`
3. 打开VSCode调试面板，选择`Attach`，按F5

### 调试osx运行时

1. 启动fileserver, `./clibs/ant/ant.exe tools/fileserver/main.lua`
2. 启动运行时, `./runtime/osx/ant.exe <需要调试的项目路径>`
3. 打开VSCode调试面板，选择`Attach`，按F5

### 调试ios运行时

1. 启动fileserver, `./clibs/ant/ant.exe tools/fileserver/main.lua <需要调试的项目路径>`
2. 启动ios代理， `./clibs/ant/ant.exe tools/fileserver/mobiledevice/proxy.lua`
3. 在iOS中，启动运行时APP
4. 打开VSCode调试面板，选择`Attach`，按F5

### 附上launch.json具体的设置

``` json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Editor (msvc)",
            "type": "lua",
            "request": "launch",
            "luaexe": "${workspaceRoot}/clibs/lua.exe",
            "program": "${workspaceRoot}/test/imgui/main.lua",
            "cwd": "${workspaceRoot}",
            "env": {
                "PATH": "${workspaceFolder}/clibs/"
            },
            "skipFiles": [
                "engine/antpm/*"
            ]
        },
        {
            "name": "Editor (mingw)",
            "type": "lua",
            "request": "launch",
            "luaexe": "${workspaceRoot}/clibs/lua.exe",
            "program": "${workspaceRoot}/test/imgui/main.lua",
            "cwd": "${workspaceRoot}",
            "env": {
                "PATH": "${workspaceFolder}/clibs/"
            },
            "skipFiles": [
                "engine/antpm/*"
            ]
        },
        {
            "type": "lua",
            "request": "attach",
            "name": "Attach",
            "stopOnEntry": true,
            "address": "127.0.0.1:4278",
        },
    ]
 }
```

### 已知的问题
1. 在vscode中点击“stop debug”按钮后，如果程序连接了hierarchy.dll的话，会崩溃。看堆栈信息是因为hierarchy有自己一套的内存管理，在stop debug后，尝试去释放之前分配的一块内容，但这块内存在这个时候已经被系统回收了，再尝试释放就崩溃了，原因未知；
