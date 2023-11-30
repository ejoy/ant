local fastio = require "fastio"
local vfs = require "vfs"

return function (env, path)
    local package = {
        config = table.concat({"/",";","?","!","-"}, "\n"),
        loaded = {},
        path = path:match("^(.+/)[^/]*$")..'?.lua'
    }
    local function searcher_lua(name)
        local packagepath = package.path
        assert(type(packagepath) == "string", "'package.path' must be a string")
        name = string.gsub(name, '%.', '/')
        for c in string.gmatch(packagepath, '[^;]+') do
            local filename = string.gsub(c, '%?', name)
            local mem, symbol = vfs.read(filename)
            if mem then
                local func, err = fastio.loadlua(mem, symbol, env)
                if not func then
                    error(("error loading module '%s' from file '%s':\n\t%s"):format(name, path, err))
                end
                return func, path
            end
        end
        return nil, "no file '"..packagepath:gsub(';', "'\n\tno file '"):gsub('%?', name).."'"
    end
    local function findloader(name)
        local msg = ''
        assert(type(package.searchers) == "table", "'package.searchers' must be a table")
        for _, searcher in ipairs(package.searchers) do
            local f, extra = searcher(name)
            if type(f) == 'function' then
                return f, extra
            elseif type(f) == 'string' then
                msg = msg .. "\n\t" .. f
            end
        end
        error(("module '%s' not found:%s"):format(name, msg))
    end
    local function require(name)
        local m = package.loaded[name]
        if m ~= nil then
            return m
        end
        local initfunc, extra = findloader(name)
        local r = initfunc(name, extra)
        if r == nil then
            r = true
        end
        package.loaded[name] = r
        return r
    end
    package.searchpath = nil
    package.searchers = { searcher_lua }
    env.package = package
    env.require = require
end
