local fs = require "filesystem.cpp"
local load_ecs = require "tools.serialize.load_ecs"
local packages = {}

local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local object = {
    "system",
    "interface",
    "singleton",
    "policy",
    "transform",
}

local attribute = {
    "require_system",
    "require_policy",
    "require_interface",
    "require_singleton",
    "require_transform",
    "require_component",
    "unique_component",
    "input",
    "output",
}

local function write_file(filename, data)
    local res = table.concat(data, "\n")
    local f = assert(io.open(filename, "w"))
    f:write(res)
    f:close()
end

local function write_ecs(class, input, output)
    local imported = {}
    local function import(name)
        imported[name] = true
    end
    local function add_import(fullname)
        local packname = fullname:match "^([^|]*)|.*$"
        if packname then
            import(packname)
        end
    end
    local function write_method(s, o, methodname)
        for v in sortpairs(o.method) do
            s[#s+1] = ("    .%s %q"):format(methodname, v)
            add_import(v)
        end
    end
    for _, name in ipairs(class.import) do
        import(name)
    end
    local s = {}
    s[#s+1] = ("implement %q"):format(input)
    s[#s+1] = ""
    for _, objname in ipairs(object) do
        local objs = objname == "singleton" and class[objname] or class[objname][""]
        if objs then
            for name, o in sortpairs(objs) do
                s[#s+1] = ("%s %q"):format(objname, name)
                for _, attr in ipairs(attribute) do
                    if o[attr] then
                        for _, v in ipairs(o[attr]) do
                            s[#s+1] = ("    .%s %q"):format(attr, v)
                            add_import(v)
                        end
                    end
                end
                if o.method then
                    if objname == "system" then
                        write_method(s, o, "stage")
                    elseif objname == "interface" then
                        write_method(s, o, "method")
                    end
                end
                s[#s+1] = ""
            end
        end
    end
    local n = 3
    if next(imported) ~= nil then
        for name in sortpairs(imported) do
            table.insert(s, n, ("import \"@%s\""):format(name))
            n = n + 1
        end
        table.insert(s, n, "")
    end
    write_file(output, s)
end

local function convert_ecs(self, input)
    local output = fs.path(input):replace_extension ".ecs"
    local class = load_ecs(input:string())
    self.lst[#self.lst+1] = fs.relative(output, self.dir):string()
    write_ecs(class, fs.relative(input, self.dir):string(), output:string())
end

local function is_ecs_file(path)
    for line in io.lines(path:string()) do
        if line:match "^[%s]*local[%s]+ecs[%s]*=[%s]*%.%.%.[%s]*$" then
            return true
        end
    end
end

local function each_dir(self, dir, cb)
    for file in dir:list_directory() do
        if fs.is_directory(file) then
            each_dir(self, file, cb)
        else
            if is_ecs_file(file) then
                cb(self, file)
            end
        end
    end
end

local convert_package
local loaded = {}

local function test(name)
    local interface = require "packages.ecs.interface"
    local function loader(packname, filename)
        if not loaded[packname] then
            loaded[packname] = true
            convert_package(packname, packages[packname])
        end
        local f = loadfile((packages[packname] / filename):string())
        return f
    end
    local parser = interface.new(loader)
    local function load_package(packname)
        if loaded[packname] then
            return false
        end
        loaded[packname] = true
        convert_package(packname, packages[packname])
        parser:load(packname, "package.ecs")
        return true
    end
    load_package(name)
    parser:check()
end

function convert_package(name, input)
    local o = {
        dir = input,
        lst = {}
    }
    each_dir(o, input, convert_ecs)
    if #o.lst == 0 then
        return
    end
    local s = {}
    for _, name in ipairs(o.lst) do
        s[#s+1] = ("import %q"):format(name)
    end
    s[#s+1] = ""
    write_file((input / "package.ecs"):string(), s)
    test(name)
end

local function convert_all_package()
    for name, path in sortpairs(packages) do
        local ok, err = pcall(convert_package, name, path)
        if not ok then
            print(err)
        end
    end
end

local function init_package(path)
    local info = dofile((path / "package.lua"):string())
    packages[info.name] = path
end

local function init_all_package()
    for dir in fs.path "packages":list_directory() do
        if fs.is_directory(dir) then
            init_package(dir)
        end
    end
    init_package(fs.path("test/animation"))
end

init_all_package()
convert_all_package()
print "ok"
