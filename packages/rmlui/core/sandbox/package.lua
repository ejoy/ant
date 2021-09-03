local fm = require "core.filemanager"

return function (env)
    local package = {
        config = table.concat({"/",";","?","!","-"}, "\n"),
        loaded = {},
        path = '?.lua'
    }
    local function searchpath(name, path)
        name = string.gsub(name, '%.', '/')
        for c in string.gmatch(path, '[^;]+') do
            local filename = string.gsub(c, '%?', name)
            if fm.exists(filename) then
                return filename
            end
        end
        return nil, "no file '"..path:gsub(';', "'\n\tno file '"):gsub('%?', name).."'"
    end
    local function searcher_lua(name)
        assert(type(package.path) == "string", "'package.path' must be a string")
        local path, err1 = searchpath(name, package.path)
        if not path then
            return err1
        end
        local func, err2 = loadfile(fm.vfspath(path), "bt", env)
        if not func then
            error(("error loading module '%s' from file '%s':\n\t%s"):format(name, path, err2))
        end
        return func, path
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
    package.searchpath = searchpath
    package.searchers = { searcher_lua }
    env.package = package
    env.require = require
end
