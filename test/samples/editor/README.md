# 说明
本目录下的例子是编辑器模式下的工程例子，能够直接调用iup。

## 使用方式
1. 创建repo
```shell
bin/lua tools/repo/newrepo.lua {reponame} edior
```
这里的editor表示的是编辑器模式。会自动创建main.lua和launch.bat文件

2. 复杂例子到{reponame}目录下

## 文件说明
工程目录下的project_entry.lua会被newrepo.lua生成的main.lua文件require，用户代码的入口应该存放到这个位置

## 调试方式

*基础的调试方式参考doc/windows_runtime.md文件*
在vscode中添加这个设定即可
```json
			{
            "name": "project",
            "type": "lua",
            "request": "launch",
			"stopOnEntry": false,  
			//"internalModule": "vscode-dbg",      
            "cwd": "${workspaceRoot}", 
            "runtimeArgs": "${workspaceRoot}/main.lua", 
            "runtimeExecutable" : "d:/Work/ant/projects/msvc/vs_bin/x64/Debug/iup.exe",
            "env": {
				"ANTGE" : "D:/Work/ant",
                "BIN_PATH" : "projects/msvc/vs_bin/x64/Debug"
            },
			"sourceMaps": [
                [
                    "vfs://engine/libs/",
                    "D:/Work/ant/libs/"
				],
				[
                    "vfs://engine/clibs/",
                    "D:/Work/ant/clibs/"
				],
				[
                    "vfs://",
                    "${workspaceRoot}/"
				],
			],
            
        },
```




