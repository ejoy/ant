package.cpath = './clibs/ant/clibs/?.dll;'
local clibs = require 'clibs'
clibs.init('./clibs/?.dll;./bin/?.dll')

local whitelist = {
    bgfx = true,
    bullet = true,
    math3d = true,
    thread = true,
    terrain = true,
    hierarchy = true,
    crypt = true,
    debugger = true,
    lsocket = true,
    memoryfile = true,
    protocol = true,
    remotedebug = true,
}

local function modluename(name)
    local pos = name:find('.', 1, true)
    if not pos then
        return name
    end
    return name:sub(1, pos-1)
end

local l = {}

local function lpairs()
    local n = 1
    return function()
        local v = l[n]
        if not v then
            return
        end
        n = n + 1
        return v[1], v[2]
    end
end

local function linit()
    for name in pairs(clibs.all()) do
        local module = modluename(name)
        if whitelist[module] then
            l[#l+1] = { name, ('luaopen_%s'):format(name:gsub('%.', '_'))}
        else
            print('Disable:', module)
        end
    end
    table.sort(l, function (a, b)
        return a[1] < b[1]
    end)
end

linit()

local t = {}
t[#t+1] = '#include "preload_module.h"'
t[#t+1] = ''
t[#t+1] = 'extern "C" {'
for name, func in lpairs() do
    t[#t+1] = ('int %s(lua_State* L);'):format(func)
end
t[#t+1] = '}'
t[#t+1] = ''
t[#t+1] = 'std::map<std::string, lua_CFunction> preload_module() {'
t[#t+1] = '\treturn {'
for name, func in lpairs() do
    t[#t+1] = ('\t\t{ "%s", %s },'):format(name, func)
end
t[#t+1] = '\t};'
t[#t+1] = '}'
t[#t+1] = ''

local f = assert(io.open('./clibs/ant/preload_module.cpp', 'w'))
f:write(table.concat(t, '\n'))
f:close()
