local fs = require "filesystem"

local function io_open(path)
    return fs.open(fs.path(path))
end

local function loadlua(f, name)
    local str = f:read 'a'
    f:close()
    return load(str, '@' .. name)
end

local function sandbox_env(root)
    local env = setmetatable({}, {__index=_G})
    local _LOADED = {}

    local function searchpath(name, path)
        local err = ''
        name = string.gsub(name, '%.', '/')
        for c in string.gmatch(path, '[^;]+') do
            local filename = string.gsub(c, '%?', name)
            local f = io_open(filename)
            if f then
                return filename, f
            end
            err = err .. ("\n\tno file '%s'"):format(filename)
        end
        return nil, err
    end

    local function searcher_lua(name)
        assert(type(env.package.path) == "string", "'package.path' must be a string")
        local filename, f = searchpath(name, env.package.path)
        if not filename then
            if package.loaded[name] then
                return true
            end
            return f
        end
        local func, err = loadlua(f, filename)
        if not func then
            error(("error loading module '%s' from file '%s':\n\t%s"):format(name, filename, err))
        end
        return func, filename
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
            elseif type(f) == 'boolean' then
                return
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
        if not init then
            return package.loaded[name]
        end
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
        path = root .. '/?.lua',
        searchpath = searchpath,
        searchers = {}
    }
    for i, searcher in ipairs(package.searchers) do
        env.package.searchers[i] = searcher
    end
    env.package.searchers[2] = searcher_lua
    return env
end

local function sandbox_require(root, main)
    return sandbox_env(root).require(main)
end

return {
    require = sandbox_require,
    env = sandbox_env,
}
