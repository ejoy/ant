local function sandbox_env(loadlua, openfile)
    local env = setmetatable({}, {__index=_G})
    local _LOADED = {}

    local function searchpath(name, path)
        local err = ''
        name = string.gsub(name, '%.', '/')
        for c in string.gmatch(path, '[^;]+') do
            local filename = string.gsub(c, '%?', name)
            local f = openfile(filename)
            if f then
                f:close()
                return filename
            end
            err = err .. ("\n\tno file '%s'"):format(filename)
        end
        return nil, err
    end

    local function searcher_lua(name)
        assert(type(env.package.path) == "string", "'package.path' must be a string")
        local filename, err = searchpath(name, env.package.path)
        if not filename then
            return err
        end
        local f, err = loadlua(filename)
        if not f then
            error(("error loading module '%s' from file '%s':\n\t%s"):format(name, filename, err))
        end
        return f, filename
    end

    local function require_load(name)
        local msg = ''
        local _SEARCHERS = env.package.searchers
        assert(type(_SEARCHERS) == "table", "'package.searchers' must be a table")
        for _, searcher in ipairs(_SEARCHERS) do
            local f, extra = searcher(name)
            if type(f) == 'function' then
                return f, extra
            elseif type(f) == 'string' then
                msg = msg .. f
            end
        end
        error(("module '%s' not found:%s"):format(name, msg))
    end

    function env.require(name)
        assert(type(name) == "string", ("bad argument #1 to 'require' (string expected, got %s)"):format(type(name)))
        local p = _LOADED[name]
        if p ~= nil then
            return p
        end
        local init, extra = require_load(name)
        debug.setupvalue(init, 1, env)
        local res = init(name, extra)
        if res ~= nil then
            _LOADED[name] = res
        end
        if _LOADED[name] == nil then
            _LOADED[name] = true
        end
        return _LOADED[name]
    end

    env.package = {
        config = table.concat({"/",";","?","!","-"}, "\n"),
        loaded = _LOADED,
        preload = package.preload,
        path = '?.lua',
        searchpath = searchpath,
        searchers = {}
    }
    for i, searcher in ipairs(package.searchers) do
        env.package.searchers[i] = searcher
    end
    env.package.searchers[2] = searcher_lua
    return env
end

return function(root, main, io_open)
    local function openfile(name, mode)
        return io_open(root .. '/' .. name, mode)
    end
    local function loadlua(name)
        local f, err = openfile(name, 'r')
        if f then
            local str = f:read 'a'
            f:close()
            return load(str, '@' .. root .. '/' .. name)
        end
        return nil, err
    end
    local init, err = loadlua(main)
    if not init then
        return nil, err
    end
    debug.setupvalue(init, 1, sandbox_env(loadlua, openfile))
    return init
end
