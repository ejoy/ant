--TODO: remove they
require "log"
require "filesystem"
require "directory"

local vfs = require "vfs"

local registered = {}

local pm_loadfile; do
    local function errmsg(err, filename, real_filename)
        local first, last = err:find(real_filename, 1, true)
        if not first then
            return err
        end
        return err:sub(1, first-1) .. filename .. err:sub(last+1)
    end
    local supportFirmware <const> = package.preload.firmware ~= nil
    if supportFirmware then
        function pm_loadfile(realpath, path)
            local f, err = io.open(realpath, 'rb')
            if not f then
                err = errmsg(err, path, realpath)
                return nil, err
            end
            local str = f:read 'a'
            f:close()
            return load(str, '@' .. path)
        end
    else
        function pm_loadfile(realpath, path)
            local f, err = io.open(realpath, 'rb')
            if not f then
                err = errmsg(err, path, realpath)
                return nil, err
            end
            local str = f:read 'a'
            f:close()
            return load(str, '@' .. realpath)
        end
    end
end

local function searchpath(name, path)
    name = string.gsub(name, '%.', '/')
    for c in string.gmatch(path, '[^;]+') do
        local filename = string.gsub(c, '%?', name)
        if vfs.type(filename) ~= nil then
            return filename
        end
    end
    return nil, "no file '"..path:gsub(';', "'\n\tno file '"):gsub('%?', name).."'"
end

local function sandbox_env(packagename)
    local env = setmetatable({}, {__index=_G})
    local _LOADED = {}
    local _PRELOAD = package.preload
    local PATH = "/pkg/"..packagename..'/?.lua'

    local function searcher_preload(name)
        local func = _PRELOAD[name]
        if func then
            return func, ":preload:"
        end
        return ("no field package.preload['%s']"):format(name)
    end

    local function searcher_lua(name)
        local filename = name:gsub('%.', '/')
        local path = PATH:gsub('%?', filename)
        local realpath = vfs.realpath(path)
        if realpath then
            local func, err = pm_loadfile(realpath, path)
            if not func then
                error(("error loading module '%s' from file '%s':\n\t%s"):format(name, path, err))
            end
            return func, path
        end
        return "no file '"..path.."'"
    end

    function env.require(name)
        assert(type(name) == "string", ("bad argument #1 to 'require' (string expected, got %s)"):format(type(name)))
        local p = package.loaded[name] or _LOADED[name]
        if p ~= nil then
            return p
        end
        local initfunc, extra = searcher_preload(name)
        if type(initfunc) == "function" then
            debug.setupvalue(initfunc, 1, env)
            local r = initfunc(name, extra)
            if r == nil then
                r = true
            end
            package.loaded[name] = r
            return r
        end
        initfunc, extra = searcher_lua(name)
        if type(initfunc) == "function" then
            debug.setupvalue(initfunc, 1, env)
            local r = initfunc(name, extra)
            if r == nil then
                r = true
            end
            _LOADED[name] = r
            return r
        end
        local filename = name:gsub('%.', '/')
        local path = PATH:gsub('%?', filename)
        error(("module '%s' not found:\n\tno field package.preload['%s']\n\tno file '%s'"):format(name, name, path))
    end

    env.package = {
        config = table.concat({"/",";","?","!","-"}, "\n"),
        loaded = _LOADED,
        preload = _PRELOAD,
        path = PATH,
        cpath = "",
        searchpath = searchpath,
        searchers = {
            searcher_preload,
            searcher_lua,
        }
    }
    return env
end

local function loadenv(name)
    local env = registered[name]
    if not env then
        if vfs.type("/pkg/"..name) ~= 'dir' then
            error(('`/pkg/%s` is not a directory.'):format(name))
        end
        env = sandbox_env(name)
        registered[name] = env
    end
    return env
end

local function import(name)
    return loadenv(name).require "main"
end

---@diagnostic disable-next-line: lowercase-global
import_package = import

return {
    import = import,
    loadenv = loadenv,
}
