--
-- How to Use
--
-- 1. Open VSCode
-- 2. Install extension `sumneko.lua`
-- 3. Add setting "Lua.runtime.plugin": "misc/lsp-plugin.lua"
--

local fs = require "bee.filesystem"
local furi = require "file-uri"
local packages = {}
local package_names = {}
local interfaces = {}

do
    local ws = require "workspace"
    local workspaceFolder = fs.path(ws.path)
    local searchFolder = {
        "packages",
        "test",
        "tools",
    }
    local function searchPackage(folder)
        if not fs.exists(folder / "package.lua") then
            return
        end
        local info = dofile((folder / "package.lua"):string())
        if not info then
            return
        end
        return info.name, info.entry
    end

    local function findAllEcsFiles(folder, ecsFiles)
        for p in fs.pairs(folder) do
            if fs.is_directory(p) then
                findAllEcsFiles(p, ecsFiles)
            else
                if p:equal_extension ".ecs" then
                    ecsFiles[#ecsFiles+1] = p
                end
            end
        end
    end

    local ecsFiles = {}

    for _, folder in ipairs(searchFolder) do
        local f = workspaceFolder / folder
        findAllEcsFiles(f, ecsFiles)
        for path in fs.pairs(f) do
            if fs.is_directory(path) then
                local ok, name, entry = pcall(searchPackage, path)
                if ok and name then
                    package_names[name] = ("%s.%s"):format(folder, path:filename():string())
                    if entry then
                        packages[name] = ("%s.%s.%s"):format(folder, path:filename():string(), entry)
                    end
                end
            end
        end
    end

    local function build_ecs_env()
        local c
        local function def() return c end
        c = setmetatable({}, {
            __call = def,
            __index = def,
        })
    
        local i
        local subname
        local interfacename
        i = setmetatable({}, {
            __call = function (t, n)
                if subname == nil then
                    interfaces[n] = {}
                    interfacename = n
                    return i
                end
    
                if subname == "implement" then
                    local ii = assert(interfaces[interfacename])
                    local f = n:gsub("/", ".")
                    ii.implement_file = f:gsub(".lua$", "")
                end
                subname = nil
                return i
            end,
            __index = function (t, n)
                subname = n
                return i
            end
        })
        return {
            interface   = i,
            system      = c,
            policy      = c,
            component   = c,
            import      = c,
        }
    end
    

    local ecs_env = build_ecs_env()

    local function load_ecs_file(f)
        local content, err = loadfile(f:string(), "t", ecs_env)
        if content == nil then
            error(("read file faild:%s, error:%s"):format(f:string(), err))
        end
        return content()
    end
    for _, f in ipairs(ecsFiles) do
        pcall(load_ecs_file, f)
    end
end

function OnSetText(uri, text)
    --local path = fs.path(furi.decode(uri))
    local diffs = {}
    for rstart, rfinish, nstart, name, nfinish in text:gmatch [=[()import_package()%s*["']()([^"']+)()["']]=] do
        if packages[name] then
            diffs[#diffs+1] = {
                start = rstart,
                finish = rfinish-1,
                text  = 'require',
            }
            diffs[#diffs+1] = {
                start = nstart,
                finish = nfinish-1,
                text  = packages[name],
            }
        end
    end

    for rstart, rfinish, nstart, name, nfinish in text:gmatch [=[()ecs%.import%.interface()%s*["']()([^"']+)()["']]=] do
        local pkgname, interfacename = name:match "([^|]+)|(.+)"
        if package_names[pkgname] == nil then
            print("package not found:", pkgname, package_names[pkgname])
            goto continue
        end

        local ii = interfaces[interfacename]
        if ii == nil then
            print("not found interface name:", interfacename)
            goto continue
        end
        
        diffs[#diffs+1] = {
            start = rstart,
            finish = rfinish-1,
            text  = 'require',
        }
        local rtext = ("%s.%s"):format(package_names[pkgname], ii.implement_file)
        diffs[#diffs+1] = {
            start = nstart,
            finish = nfinish-1,
            text  = rtext,
        }

        ::continue::

    end
    return diffs
end
