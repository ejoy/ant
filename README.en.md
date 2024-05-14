Ant Game Engine
=====

[English Version](./README.en.md) | [中文版本](./README.md)

Ant is an open source game engine developed by Lingxi Interactive Entertainment. At this stage, only the code repository is made public and has not yet been officially released. Documentation, examples, etc. are to be gradually improved on the [Wiki](https://github.com/ejoy/ant/wiki) If you have any questions, you can post in [Discussions](https://github.com/ejoy/ant/discussions). Issues are only used for bug tracking, please do not ask questions in them.

### Update and Initialize Third-party Libraries:

> git submodule update --init

### Build a Compilation Environment

#### MSVC
- Install Visual Studio

#### MINGW
- Download and install [msys2](https://www.msys2.org/)
- Find the msys2 installation directory and use mingw64.exe to open the msys2 terminal
- Add the path to ming64 to the environment variable
``` bash
echo "export MINGW=/mingw64" >> ~/.bash_profile
echo "export PATH=\$MINGW/bin:\$PATH" >> ~/.bash_profile
```

- Install gcc/ninja
``` bash
pacman -Syu mingw-w64-x86_64-gcc mingw-w64-x86_64-ninja
```

#### macOS
- Install xcode, ninja


### Compile

#### Compile and build tool luamake

``` bash
git clone https://github.com/actboy168/luamake
cd luamake
git submodule update --init
.\compile\install.bat (msvc)
./compile/install.sh (mingw/linux/macos)
```

#### Compile runtime

``` bash
luamake
```

#### Compile tools
tools include: shaderc, texturec, gltf2ozz, release mode will be an order of magnitude faster (tools in debug mode do not need to be compiled)
 
``` bash
luamake -mode release tools
```

#### Compile options
``` bash
luamake [target] -mode [debug/release] #-mode默认是debug
```

### Run
Run a minimal example
``` bash
bin/msvc/debug/ant.exe test/simple/main.lua
```

### Start Editor

```bash
bin/msvc/debug/ant.exe tools/editor/main.lua [projectdir] #for example: test/simple
```

### Debug

- Install VSCode;
- Install the Lua Debug plug-in;
- Add debug configuration to`.vscode/launch.json`
``` json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "lua",
            "request": "launch",
            "name": "Debug",
            "luaexe": "${workspaceFolder}/bin/msvc/debug/ant.exe",
            "luaVersion": "lua-latest",
            "path": null,
            "cpath": null,
            "console": "integratedTerminal",
            "stopOnEntry": true,
            "outputCapture": [],
            "program": "test/simple/main.lua",
            "arg": []
        }
    ]
}
```

### About Ant Directory Structure
- **bin**：compilation results, exe/dll/lib, etc
- **build**：intermediate results of compilation
- **clibs**：c/c++ code
- **engine**：engine basic support code, including package manager, startup code, etc
- **pkg**：Each function package of the engine (there are dependencies between packages)
- **runtime**：different platform support for engine runtime
- **test**：test project
- **tools**：engine related tools
