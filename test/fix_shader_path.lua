package.cpath = "projects/msvc/vs_bin/Debug/?.dll"

package.path = table.concat({
    "engine/?.lua",
    "packages/?.lua",
}, ";")

local lfs = require "filesystem.local"
local fs_util = require "utility.fs_util"

local function rawtable(filename)
	local env = {}
	local r = assert(lfs.loadfile(filename, "t", env))
	r()
	return env
end

local files = fs_util.list_files(lfs.path ".", ".material", {})

for _, f in ipairs(files)do
    local c = rawtable(f)
    local shader = c.shader
    local function refine_shader_path(shaderpath)
        local pkgpath = "/pkg/ant.resources"
        local file = shaderpath:match(pkgpath .. "/shaders/src/(.+)$")

        local realpath = "/pkg/ant.resources/shaders/"
        if file then
            return realpath .. file
        end

        file = shaderpath:match(pkgpath .. "/shaders")
        if file == nil then
            file = shaderpath:match(pkgpath .. "/(.+)$")
            if file then
                return realpath .. file
            end
        end
    end

    local file = lfs.open(f, "rb")
    local filecontent = file:read "a"
    file:close()

    local changed
    for _, name in ipairs {"vs", "fs"} do
        local oldpath = shader[name]
        local newpath = refine_shader_path(oldpath)

        if newpath then
            print("shader path:", oldpath, newpath)
            filecontent = filecontent:gsub(oldpath, newpath)
            -- if not lfs.exists(lfs.path(newpath)) then
            --     print("new shader path not exist:", newpath)
            -- end
            changed = true
        end
    end

    local statepath = c.state
    if type(statepath) == "string" then
        if statepath:match "/pkg" == nil then
            local newpath
            if statepath:match "materials/states" then
                newpath = "/pkg/ant.resources/depiction/" .. statepath
            elseif statepath:match "states" then
                newpath = "/pkg/ant.resources/depiction/materials/" .. statepath
            else
                newpath = "/pkg/ant.resources/depiction/materials/states" .. statepath
            end

            filecontent = filecontent:gsub(statepath, newpath)
            changed = true
        end
    end

    if c.properties and c.properties.textures then
        local textures = c.properties.textures
        for k, v in pairs(textures)do
            local path = v.ref_path
            local newpath
            
            if path:match "/pkg" == nil then
                newpath = "/pkg/ant.resources/depiction/" .. path
            else
                local subfile = path:match "/pkg/ant.resources/(.+)%s*$"
                if subfile and subfile:match "depiction" == nil then
                    newpath = "/pkg/ant.resources/depiction/" .. subfile
                end
            end
            
            if newpath then
                filecontent = filecontent:gsub(path, newpath)
                changed = true
            end
        end
    end
    
    if changed then
        print("file changed:", f:string())
        file = lfs.open(f, "w")
        file:write(filecontent)
        file:close()
    end
end