package.cpath = package.cpath .. ';./Debug/?.dll'

local function getexe()
    local i = -1
    while arg[i] ~= nil do
        i= i - 1
    end
    return arg[i + 1]
end

local subprocess = require 'subprocess'

local app = getexe()

local p, stdin, stdout = subprocess.spawn {
    app = app,
    args = {
        app,
        '-e',
        [[io.stdout:write('echo ' .. io.stdin:read 'a')]],
    },
    stdin = true,
    stdout = true,
}

stdin:write 'hello'
stdin:close()
print(stdout:read 'a')
print('end')
