local fs = require 'bee.filesystem'
local sp = require 'bee.subprocess'
local arch = require "bee.platform".Arch
local platform_os = require 'frontend.platform_os' ()

local _M = {}

local macos = "macOS"
local windows = "Windows"
local entry_launch = "launch"

local function macos_check_rosetta_process(process)
    local rosetta_runtime <const> = "/usr/libexec/rosetta/runtime"
    if not fs.exists(rosetta_runtime) then
        return false
    end
    local p = sp.spawn {
        "/usr/bin/fuser",
        rosetta_runtime,
        stdout = true,
        stderr = true, -- for skip  fuser output
    }
    if not p then
        return false
    end
    local l = p.stdout:read "a"
    return l:find(tostring(process)) ~= nil
end

function _M.check_injectdll(injectdll)
    injectdll = injectdll or (WORKDIR / "bin" / "launcher.so"):string()
    if not fs.exists(injectdll) then
        return nil, "Not found launcher.so."
    end
    return injectdll
end

function _M.gdb_inject(pid, entry, injectdll, gdb_path)
    local injectdll, err = _M.check_injectdll(injectdll)
    if not injectdll then
        return false, err
    end
    gdb_path = gdb_path or "gdb"
    local pre_launcher = entry == entry_launch and
        {
            "-ex",
            "break main",
            "-ex",
            "c",
        } or {}

    local launcher = {
        "-ex",
        -- 6 = RTDL_NOW|RTDL_LOCAL
        ('print  (void*)dlopen("%s", 6)'):format(injectdll),
        "-ex",
        ('call ((void(*)())&%s)()'):format(entry),
        "-ex",
        "quit"
    }

    local p, err = sp.spawn {
        gdb_path,
        "-p", tostring(pid),
        "--batch",
        pre_launcher,
        launcher,
        stdout = true,
        stderr = true,
    }
    if not p then
        return false, "Spawn lldb failed:"..err
    end
    if p:wait() ~= 0 then
        return false, "stdout:"..p.stdout:read "a".."\nstderr:"..p.stderr:read "a"
    end
    return true
end

function _M.lldb_inject(pid, entry, injectdll, lldb_path)
    local injectdll, err = _M.check_injectdll(injectdll)
    if not injectdll then
        return false, err
    end
    lldb_path = lldb_path or "lldb"
    local pre_launcher = entry == entry_launch and
        {
            "-o",
            "breakpoint set -n main",
            "-o",
            "c",
        } or {}

    local launcher = {
        "-o",
        -- 6 = RTDL_NOW|RTDL_LOCAL
        ('expression (void*)dlopen("%s", 6)'):format(injectdll),
        "-o",
        ('expression ((void(*)())&%s)()'):format(entry),
        "-o",
        "quit"
    }

    local p, err = sp.spawn {
        lldb_path,
        "-p", tostring(pid),
        "--batch",
        pre_launcher,
        launcher,
        stdout = true,
        stderr = true,
    }
    if not p then
        return false, "Spawn lldb failed:"..err
    end
    if p:wait() ~= 0 then
        return false, "stdout:"..p.stdout:read "a".."\nstderr:"..p.stderr:read "a"
    end
    return true
end

function _M.macos_inject(process, entry, injectdll)
    local injectdll, err = _M.check_injectdll(injectdll)
    if not injectdll then
        return false, err
    end
    local helper = (WORKDIR / "bin" / "process_inject_helper"):string()
    local p, err = sp.spawn {
        "/usr/bin/osascript",
        "-e",
        ([[do shell script "%s %d %s %s" with administrator privileges with prompt "lua-debug"]]):format(helper, process, injectdll, entry),
        stderr = true,
    }
    if not p then
        return false, "Spawn osascript failed:"..err
    end
    if p:wait() ~= 0 then
        return false, p.stderr:read "a"
    end
    return true
end

function _M.windows_inject(process, entry)
    local inject = require 'inject'
    if not inject.injectdll(process
        , (WORKDIR / "bin" / "launcher.x86.dll"):string()
        , (WORKDIR / "bin" / "launcher.x64.dll"):string()
        , entry
        ) then
        return false, "injectdll failed."
    end
    return true
end

function _M.inject(process, entry, args)
    if platform_os ~= windows and platform_os ~= macos then
        return false, "unsupported inject"
    end
    if platform_os ~= windows and type(process) == "userdata" then
        process = process:get_id()
    end
    if args.inject == "gdb" then
        return _M.gdb_inject(process, entry, nil, args.inject_executable)
    elseif args.inject == 'lldb' then
        return _M.lldb_inject(process, entry, nil, args.inject_executable)
    elseif args.inject == 'hook' then
        if platform_os == macos then
            local is_launch = entry == entry_launch
            local is_rosetta = arch == "arm64" and macos_check_rosetta_process(process)
            local force_lldb = is_launch or is_rosetta
            if force_lldb then
                return false, "force use lldb when " .. (is_launch and entry or "rosetta") .. ", please try lldb inject."
            end
            local ok, err = _M.macos_inject(process, entry)
            if not ok then
                return false, err .. "\nretry or try lldb inject."
            end
            return true
        elseif platform_os == windows then
            return _M.windows_inject(process, entry)
        else
            return false, ("Inject (use %s) is not supported in %s."):format(args.inject, platform_os)
        end
    else
        return false, ("Inject (use %s) is not supported."):format(args.inject)
    end
end

return _M
