local subprocess = require "bee.subprocess"
local platform = require "bee.platform"
local fs = require "bee.filesystem"

local function WimcProcess(func)
    local proc <close> = assert(subprocess.spawn {
        "cmd", "/c", "wmic", "process", "get", "ExecutablePath,Name", "/FORMAT:list",
        searchPath = true,
        stdout = true,
        stderr = true,
    })
    local process = {}
    for line in proc.stdout:lines() do
        local k, v = line:match "^%s*(.-)%s*=%s*(.-)%s*$"
        if k then
            process[k] = v
        elseif process.Name then
            if func(process) then
                proc.stdout:read "a"
                assert(0 == proc:wait())
                return
            end
            process = {}
        end
    end
    if 0 ~= proc:wait() then
        print(proc.stderr:read "a")
        os.exit(false)
    end
end

local function psProcess(func)
    --TODO
end

local function process_adb()
    local path
    if platform.os == "windows" then
        WimcProcess(function (process)
            if process.Name == "adb.exe" then
                path = process.ExecutablePath
                return true
            end
        end)
    else
        psProcess(function (process)
            if process.Name == "adb" then
                path = process.ExecutablePath
                return true
            end
        end)
    end
    return path
end

local function find_adb()
    if platform.os == "windows" then
        local LocalAppData = os.getenv "LocalAppData"
        if LocalAppData then
            local path = LocalAppData:gsub("\\", "/") .. "/Android/Sdk/platform-tools/adb.exe"
            if fs.exists(path) then
                return path
            end
        end
    end
end

return process_adb() or find_adb() or ""
