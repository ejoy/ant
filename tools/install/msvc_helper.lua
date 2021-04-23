local sp = require 'subprocess'
local fs = require 'filesystem.cpp'

local function Is64BitWindows()
    -- https://docs.microsoft.com/en-us/archive/blogs/david.wang/howto-detect-process-bitness
    return os.getenv "PROCESSOR_ARCHITECTURE" == "AMD64" or os.getenv "PROCESSOR_ARCHITEW6432" == "AMD64"
end

local ProgramFiles = Is64BitWindows() and 'ProgramFiles(x86)' or 'ProgramFiles'
local vswhere = fs.path(os.getenv(ProgramFiles)) / 'Microsoft Visual Studio' / 'Installer' / 'vswhere.exe'

local function strtrim(str)
    return str:gsub("^%s*(.-)%s*$", "%1")
end

local InstallDir
local function installpath()
    if InstallDir then
        return InstallDir
    end
    local process = assert(sp.spawn {
        vswhere,
        '-latest',
        '-utf8',
        '-products', '*',
        '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
        '-property', 'installationPath',
        stdout = true,
    })
    local result = strtrim(process.stdout:read 'a')
    process.stdout:close()
    local code = process:wait()
    if code ~= 0 then
        os.exit(code, true)
    end
    assert(result ~= "", "can't find msvc.")
    InstallDir = fs.path(result)
    return InstallDir
end

local function vcrtpath(platform)
    local RedistVersion = (function ()
        local verfile = installpath() / 'VC' / 'Auxiliary' / 'Build' / 'Microsoft.VCRedistVersion.default.txt'
        local f = assert(io.open(verfile:string(), 'r'))
        local r = f:read 'a'
        f:close()
        return strtrim(r)
    end)()
    local ToolVersion = (function ()
        local verfile = installpath() / 'VC' / 'Auxiliary' / 'Build' / 'Microsoft.VCToolsVersion.default.txt'
        local f = assert(io.open(verfile:string(), 'r'))
        local r = f:read 'a'
        f:close()
        return strtrim(r)
    end)()
    local ToolsetVersion = (function ()
        local verfile = installpath() / 'VC' / 'Tools' / 'MSVC' / ToolVersion / 'include' / 'yvals_core.h'
        local f = assert(io.open(verfile:string(), 'r'))
        local r = f:read 'a'
        f:close()
        return r:match '#define%s+_MSVC_STL_VERSION%s+(%d+)'
    end)()
    return installpath() / 'VC' / 'Redist' / 'MSVC' / RedistVersion / platform / ('Microsoft.VC'..ToolsetVersion..'.CRT')
end

local function ucrtpath(platform)
    --TODO
    local registry = require 'bee.registry'
    local reg = registry.open [[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Kits\Installed Roots]]
    local path = fs.path(reg.KitsRoot10) / 'Redist'
    local res, ver
    local function accept(p)
        if not fs.is_directory(p) then
            return
        end
        local ucrt = p / 'ucrt' / 'DLLs' / platform
        if fs.exists(ucrt) then
            local version = 0
            if p ~= path then
                version = p:filename():string():gsub('10%.0%.([0-9]+)%.0', '%1')
                version = tonumber(version)
            end
            if not ver or ver < version then
                res, ver = ucrt, version
            end
        end
    end
    accept(path)
    for p in path:list_directory() do
        accept(p)
    end
    if res then
        return res
    end
end

local function copy_vcrt(platform, target)
    fs.create_directories(target)
    for dll in vcrtpath(platform):list_directory() do
        if dll:filename() ~= fs.path "vccorlib140.dll" then
            fs.copy_file(dll, target / dll:filename(), true)
        end
    end
end

local function copy_ucrt(platform, target)
    fs.create_directories(target)
    for dll in ucrtpath(platform):list_directory() do
        fs.copy_file(dll, target / dll:filename(), true)
    end
end

return {
    copy_vcrt = copy_vcrt,
    copy_ucrt = copy_ucrt,
}
