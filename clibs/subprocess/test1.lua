package.cpath = package.cpath .. ';./Debug/?.dll'

local subprocess = require 'subprocess'

local w2l = "D:\\work\\w3x2lni\\"

local exe = w2l .. "bin\\w3x2lni-lua.exe"
local p, stdout, stderr = subprocess.spawn {
    app = exe,
    args = {
        exe,
        "-e",
        ('package.path=[[%s]]'):format(w2l .. "script\\?.lua"),
        w2l .. "script\\backend\\init.lua",
    },
    cwd = w2l .. "script\\",
    stderr = true,
    stdout = true,
}

print(stderr:read 'a')
print(stdout:read 'a')
print(p, stdout)
