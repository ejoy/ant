local fs = require "filesystem"

local function sandbox_env(root, pkgname)
    local env = setmetatable({}, {__index=_G})
    local _LOADED = {}

    local function searchpath(name, path)
        local err = ''
        name = string.gsub(name, '%.', '/')
        for c in string.gmatch(path, '[^;]+') do
            local filename = string.gsub(c, '%?', name)
            local f = fs.open(fs.path(filename))
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
        local path, err1 = searchpath(name, env.package.path)
        if not path then
            if package.loaded[name] then
                return true
            end
            return err1
        end
        local func, err2 = fs.loadfile(fs.path(path))
        if not func then
            error(("error loading module '%s' from file '%s':\n\t%s"):format(name, path, err2))
        end
        return func, path
    end

    local function require_load(name)
        local msg = ''
        local _SEARCHERS = env.package.searchers
        assert(type(_SEARCHERS) == "table", "'package.searchers' must be a table")
        for i, searcher in ipairs(_SEARCHERS) do
            local f, extra = searcher(name)
            if type(f) == 'function' then
                return f, extra, i
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
        local init, extra, idx = require_load(name)
        if not init or (idx >= 3 and package.loaded[name]) then
            _LOADED[name] = package.loaded[name]
            return _LOADED[name]
        end
        debug.setupvalue(init, 1, env)
        local res = init(name, extra)
        if res ~= nil then
            _LOADED[name] = res
        end
        if _LOADED[name] == nil then
            _LOADED[name] = true
		end
		if idx >= 3 then
			package.loaded[name]= _LOADED[name]
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
	env._PACKAGENAME = pkgname
    return env
end

return {
    env = sandbox_env,
}
