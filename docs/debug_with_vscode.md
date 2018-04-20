### 环境
1. 使用msvc版本（理论上mingw版本都是可以的，目前还没有完全测试过）
2. 下载vscode，并安装插件vscode-lua-debug插件，命令为：ext install lua-debug，github地址：[vscode-lua-debug](https://github.com/actboy168/vscode-lua-debug)
3. 配置vscode debug选项，使用launch直接启动(见下面解析）；
4. 按F5进行调试；

### launch调试项配置
这些配置都需要在request类型为: "launch"下进行（目前attach模式还没有尝试过，如尝试过后，请更新文档。此外这个插件也支持远程调试）
1. 配置runtimeExecutable选项。如："runtimeExecutable" : "${workspaceRoot}/projects/msvc/vs_bin/x64/Debug/iup.exe"。这是因为lua是嵌入到自定义的程序中，所以这个一定要定义，并且vscode-lua-debug这个插件需要从启动的exe程序来决定加载的debugger是32位还是64位；
2. 配置runtimeArgs。如："runtimeArgs": "libs/main.lua"。这里决定了启动时候需要用到的lua文件；
3. 配置env。如："env": { "STATIC_LINKING_IUP" : "1", "BIN_PATH" : "projects/msvc/vs_bin/x64/Debug"}，这些环境变量在使用msvc工程启动的时候是需要的，否则会有报错；
4. 配置cwd。根据需要调试的环境，设定对应的cwd。如上述运行libs/main.lua的时候，就需要将cwd配置到ant目录下；
5. path和cpath。如果启动的时候执行了工程中的libs/init.lua文件的话，这两项可以不配置（因为init.lua文件会进行默认的配置，会改写这两项）；

### 已知的问题
1. 断点偶尔就会失效，通常重启能够解决问题；
2. 在vscode中点击“stop debug”按钮后，如果程序连接了hierarchy.dll的话，会崩溃。看堆栈信息是因为hierarchy有自己一套的内存管理，在stop debug后，尝试去释放之前分配的一块内容，但这块内存在这个时候已经被系统回收了，再尝试释放就崩溃了，原因未知；


### 附上launch模型具体的设置
使用iup调试
>        
    {
        "name": "launch_vs_debug",
        "type": "lua",
        "request": "launch",
        //"stopOnEntry": true,            
        "cwd": "${workspaceRoot}",  
        "path": "./?.lua",
        "cpath": "./?.dll;${workspaceRoot}/project/msvc/vs_bin/x64/Debug/?.dll",
        "runtimeArgs": "libs/main.lua",            
        "runtimeExecutable" : "${workspaceRoot}/projects/msvc/vs_bin/x64/Debug/iup.exe",
        "env": {
            "STATIC_LINKING_IUP" : "1",
            "BIN_PATH" : "projects/msvc/vs_bin/x64/Debug"
        }        
    },

单个文件调试
>   
    {
        "name": "launch_test",
        "type": "lua",
        "request": "launch",
        //"stopOnEntry": true,            
        "cwd": "${workspaceRoot}",  
        "path": "./?.lua",
        "cpath": "./?.dll;${workspaceRoot}/project/msvc/vs_bin/x64/Debug/?.dll",                        
        "runtimeExecutable" : "${workspaceRoot}/projects/msvc/vs_bin/x64/Debug/lua.exe",
        "runtimeArgs": "${file}",            
    },
