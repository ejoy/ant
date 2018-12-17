local root = os.getenv "ANTGE" or "../../.."
package.cpath = root .. "/clibs/?.dll" or root .. "/bin/?.dll"

local projectname = ...

-- only project name, not full project path
_G.DEBUG = true

local function log(...)
    if _G.DEBUG then
        print(...)
    end
end

log("ANTGE:", root)
log("input project name:", projectname)

local lfs = require "lfs"    

local projectpath = projectname
if projectname:match("[%w_%d]+") then
    local function personaldir()
        return os.getenv "HOME" ..  "/Documents"
    end
    local pd = lfs.personaldir or personaldir    
    projectpath = pd() .. "/" .. projectname
end

log("project path:", projectpath)

if lfs.attributes(projectpath, "mode") ~= "directory" then
    error(string.format("project path:%s, is not valid", projectpath))
end

local cwd = lfs.currentdir()

log("cwd:", cwd)

local shadercpath = root .. "/3rd/bgfx/.build/osx64_clang/bin/shadercRelease"
if lfs.attributes(shadercpath, "mode") ~= "file" then
    error(string.format("shaderc progrom:%s, is not valid, need to build shaderc progrom before run depoly.lua", shadercpath))
end

log("shaderc path:", shadercpath)

local shadersrc = "shaders/src"
local shaderdst = "shaders/metal"

log("shader src:", shadersrc, "shader result path:", shaderdst)

local function list_files(rootpath, files, op)
    for d in lfs.dir(rootpath) do        
        if d ~= "." and d ~= ".." then
            local fullpath = rootpath == "." and d or rootpath .. "/" .. d
            if lfs.attributes(fullpath, "mode") == "directory" then
                list_files(fullpath, files, op)
            else
                if op then
                    if op(fullpath) then
                        table.insert(files, fullpath)
                    end
                else
                    if lfs.attributes(fullpath, "mode") == "file" then
                        table.insert(files, fullpath)
                    end
                end
            end
        end
    end
end

local filesneeded_copy = {}

local shaderfiles = {}
list_files(shadersrc, shaderfiles, function (fullpath)
    log("found shader file:", fullpath)
    return fullpath:match("%.sc$") and not fullpath:match("varying%.def%.sc$")
end)

if _G.DEBUG then
   log("found all shader files:") 
   for _, sf in ipairs(shaderfiles) do
        log(sf)
   end
end

log("try compile shader:")

local stage_names = {
    v = "vertex",
    f = "fragment",
    c = "compute"
}

local function parent_dir(filename)
    return filename:match("(.+)[\\/]")
end

local function create_dirs(curpath)
    if lfs.attributes(curpath, "mode") == nil then
        local parentdir = parent_dir(curpath)
        if parentdir then
            create_dirs(parentdir)
        end
        
        log("create dir:", curpath)
        lfs.mkdir(curpath)
    end 
end
for _, f in ipairs(shaderfiles) do
    local stage = assert(f:match("([vf])s_.+$"))
    
    local cmdline = shadercpath
    local function add_arg(opt, arg)
        cmdline = cmdline .. " " .. opt
        cmdline = cmdline .. " " .. arg
    end
    add_arg("-f", f)

    local outfile = f:gsub(shadersrc, shaderdst):gsub("sc$", "bin")    
    log("outfile:", outfile)
    log("outfile parent dir:", parent_dir(outfile))
    create_dirs(parent_dir(outfile))
    add_arg("-o", outfile)

    add_arg("-i", root .. "/3rd/bgfx/src")
    add_arg("-i", root .. "/3rd/bgfx/examples/common")
    add_arg("-p", "metal")
    add_arg("--platform", "ios")
    add_arg("--type", stage_names[stage])

    log("build:\n", cmdline)

    local ret = io.popen(cmdline)
    local msg = ret:read "a"
    if msg and msg ~= "" then
        msg = msg:lower()
        if msg:find("warning") or msg:find("error") then
            log("cmdline:", cmdline, "compile message:", msg)
        end
    end

    if io.open(outfile) then
        table.insert(filesneeded_copy, outfile)
    end
end

local function copy_file(src, dst)
    if src ~= dst then
        local sf = io.open(src, "rb")
        local content = sf:read "a"
        sf:close()

        create_dirs(parent_dir(dst))

        local df = io.open(dst, "wb")        
        df:write(content)
        df:close()
    end
end

list_files(".", filesneeded_copy, function (fullpath)
    return fullpath:match("%.lua$")
end)

for _, f in ipairs(filesneeded_copy) do
    local dstfile = projectpath .. "/" .. f
    log(string.format("copy file from :%s, to:%s", f, dstfile))
    copy_file(f, dstfile)
end