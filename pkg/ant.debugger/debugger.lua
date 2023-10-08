local root = ...

if debug.getregistry()["lua-debug"] then
    local dbg = debug.getregistry()["lua-debug"]
    local empty = { root = dbg.root }
    function empty:init()
        return self
    end

    function empty:start()
        return self
    end

    function empty:attach()
        return self
    end

    function empty:event(what, ...)
        if what == "setThreadName" then
            dbg:event(what, ...)
        end
        return self
    end

    function empty:set_wait()
        return self
    end

    function empty:setup_patch()
        return self
    end

    return empty
end

local function detectLuaDebugPath(cfg)
    local PLATFORM
    local function isWindows()
        return package.config:sub(1, 1) == "\\"
    end
    do
        local function shell(command)
            --NOTICE: io.popen可能会多线程不安全
            local f = assert(io.popen(command, 'r'))
            local r = f:read '*l'
            f:close()
            return r:lower()
        end
        local function detect_windows()
            if os.getenv "PROCESSOR_ARCHITECTURE" == "AMD64" then
                PLATFORM = "win32-x64"
            else
                PLATFORM = "win32-ia32"
            end
        end
        local function detect_linux()
            local machine = shell "uname -m"
            if machine == "x86_64" or machine == "amd64" then
                PLATFORM = "linux-x64"
            elseif machine == "aarch64" then
                PLATFORM = "linux-arm64"
            else
                error "unknown ARCH"
            end
        end
        local function detect_android()
            PLATFORM = "linux-arm64"
        end
        local function detect_macos()
            if shell "uname -m" == "arm64" then
                PLATFORM = "darwin-arm64"
            else
                PLATFORM = "darwin-x64"
            end
        end
        local function detect_bsd()
            local machine = shell "uname -m"
            if machine == "x86_64" or machine == "amd64" then
                PLATFORM = "bsd-x64"
            else
                error "unknown ARCH"
            end
        end
        if isWindows() then
            detect_windows()
        else
            local name = shell 'uname -s'
            if name == "linux" then
                if shell 'uname -o' == 'android' then
                    detect_android()
                else
                    detect_linux()
                end
            elseif name == "darwin" then
                detect_macos()
            elseif name == "netbsd" or name == "freebsd" then
                detect_bsd()
            else
                error "unknown OS"
            end
        end
    end

    local rt = "/runtime/"..PLATFORM
    if cfg.latest then
        rt = rt.."/lua-latest"
    elseif _VERSION == "Lua 5.4" then
        rt = rt.."/lua54"
    elseif _VERSION == "Lua 5.3" then
        rt = rt.."/lua53"
    elseif _VERSION == "Lua 5.2" then
        rt = rt.."/lua52"
    elseif _VERSION == "Lua 5.1" then
        if (tostring(assert):match('builtin') ~= nil) then
            rt = rt.."/luajit"
            jit.off()
        else
            rt = rt.."/lua51"
        end
    else
        error(_VERSION.." is not supported.")
    end

    local ext = isWindows() and "dll" or "so"
    return root..rt..'/luadebug.'..ext
end

local function initDebugger(dbg, cfg)
    if type(cfg) == "string" then
        cfg = { address = cfg }
    end

    local luadebug = os.getenv "LUA_DEBUG_CORE"
    local updateenv = false
    if not luadebug then
        luadebug = detectLuaDebugPath(cfg)
        updateenv = true
    end
    local isWindows = package.config:sub(1, 1) == "\\"
    if isWindows then
        assert(package.loadlib(luadebug, 'init'))(cfg.luaapi)
    end

    ---@type LuaDebug
    dbg.rdebug = assert(package.loadlib(luadebug, 'luaopen_luadebug'))()
    if not os.getenv "LUA_DEBUG_PATH" then
        dbg.rdebug.setenv("LUA_DEBUG_PATH", root)
    end
    if updateenv then
        dbg.rdebug.setenv("LUA_DEBUG_CORE", luadebug)
    end

    local function utf8(s)
        if cfg.ansi and isWindows then
            return dbg.rdebug.a2u(s)
        end
        return s
    end
    dbg.root = utf8(root)
    dbg.address = cfg.address and utf8(cfg.address) or nil
end

local dbg = {}

function dbg:start(cfg)
    initDebugger(self, cfg)

    local bootstrap_lua = ([[
        package.path = %q
        require "bee.thread".bootstrap_lua = debug.getinfo(1, "S").source
    ]]):format(
        self.root..'/script/?.lua'
    )
    self.rdebug.start(("assert(load(%q))(...)"):format(bootstrap_lua)..([[
        local logpath = %q
        local log = require 'common.log'
        log.file = logpath..'/worker.log'
        require 'backend.master' .init(logpath, %q)
        require 'backend.worker'
    ]]):format(
        self.root
        , ("%q, %s"):format(dbg.address, cfg.client == true and "true" or "false")
    ))
    return self
end

function dbg:attach(cfg)
    initDebugger(self, cfg)

    local bootstrap_lua = ([[
        package.path = %q
        require "bee.thread".bootstrap_lua = debug.getinfo(1, "S").source
    ]]):format(
        self.root..'/script/?.lua'
    )
    self.rdebug.start(("assert(load(%q))(...)"):format(bootstrap_lua)..([[
        if require 'backend.master' .has() then
            local logpath = %q
            local log = require 'common.log'
            log.file = logpath..'/worker.log'
            require 'backend.worker'
        end
    ]]):format(
        self.root
    ))
    return self
end

function dbg:event(...)
    self.rdebug.event(...)
    return self
end

function dbg:set_wait(name, f)
    _G[name] = function(...)
        _G[name] = nil
        f(...)
        self:event 'wait'
    end
    return self
end

function dbg:setup_patch()
    local rawxpcall = xpcall
    function pcall(f, ...)
        return rawxpcall(f,
            function(msg)
                self:event("exception", msg)
                return msg
            end,
            ...)
    end

    function xpcall(f, msgh, ...)
        return rawxpcall(f,
            function(msg)
                self:event("exception", msg)
                return msgh and msgh(msg) or msg
            end
            , ...)
    end

    local rawcoroutineresume = coroutine.resume
    local rawcoroutinewrap   = coroutine.wrap
    local function coreturn(co, ...)
        self:event("thread", co, 1)
        return ...
    end
    function coroutine.resume(co, ...)
        self:event("thread", co, 0)
        return coreturn(co, rawcoroutineresume(co, ...))
    end

    function coroutine.wrap(f)
        local wf = rawcoroutinewrap(f)
        local _, co = debug.getupvalue(wf, 1)
        return function(...)
            self:event("thread", co, 0)
            return coreturn(co, wf(...))
        end
    end

    return self
end

debug.getregistry()["lua-debug"] = dbg

return dbg
