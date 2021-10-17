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
        if not info.name or not info.entry then
            return
        end
        return info.name, info.entry
    end
    for _, folder in ipairs(searchFolder) do
        for path in fs.pairs(workspaceFolder / folder) do
            if fs.is_directory(path) then
                local ok, name, entry = pcall(searchPackage, path)
                if ok and name and entry then
                    packages[name] = ("%s.%s.%s"):format(folder, path:filename():string(), entry)
                end
            end
        end
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
    return diffs
end
