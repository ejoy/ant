package.cpath = package.cpath .. ';./Debug/?.dll'

local function luaexe()
    local i = -1
    while arg[i] ~= nil do
        i= i - 1
    end
    return arg[i + 1]
end

local subprocess = require 'subprocess'

local p, stdin, stdout = subprocess.spawn {
    luaexe(),
    '-e',
    [[io.stdout:write('echo ' .. io.stdin:read 'a')]],
    stdin = true,
    stdout = true,
    hideWindow = true,
}

stdin:write 'hello'
stdin:close()
print(stdout:read 'a')
print('end')
