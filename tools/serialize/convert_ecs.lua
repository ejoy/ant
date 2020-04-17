local fs = require "filesystem.cpp"
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

local function write_file(filename, data)
    local res = table.concat(data, "\n")
    local f = assert(io.open(filename:string(), "w"))
    f:write(res)
    f:close()
end

local function write_ecs(data, file)
    local s = {}
    local idx = 1
    while idx <= #data do
        local line = data[idx]
        assert(line.what ~= "implement")
        if line.what ~= "import" then
            break
        end
        idx = idx + 1
        s[#s+1] = ("import %q"):format(line.name)
    end
    if #s > 0 then
        s[#s+1] = ""
    end
    for i = idx, #data do
        local line = data[i]
        assert(line.what ~= "implement")
        s[#s+1] = ("%s %q"):format(line.what, line.name)
        for _, value in ipairs(line.value) do
            s[#s+1] = ("    .%s %q"):format(value.what, value.name)
        end
        s[#s+1] = ""
    end
    write_file(file, s)
end

local function each_dir(dir, cb)
    for file in dir:list_directory() do
        if fs.is_directory(file) then
            each_dir(file, cb)
        else
            if file:equal_extension ".ecs" then
                cb(file)
            end
        end
    end
end

local function getenv(result)
    local function readonly()
        error "readonly"
    end
    local function attribute_setter(contents)
        return function (self, what)
            return function (name)
                contents[#contents+1] = { what = what, name = name }
                return self
            end
        end
    end
    local function api(_, what)
        return function (name)
            local contents = {}
            local setter = attribute_setter(contents)
            result[#result+1] = { what = what, name = name, value = contents }
            return setmetatable({}, { __index = setter, __newindex = readonly })
        end
    end
    return setmetatable({}, { __index = api, __newindex = readonly })
end

local function load_ecs(file)
    local result = {}
    assert(loadfile(file:string(), "t", getenv(result)))()
    return result
end

local function need_implement(v)
    if v.what == "component" then
        return true
    end
    for _, value in ipairs(v.value) do
        if value.what == "method" then
            return true
        end
    end
    return false
end

local function convert_ecs(file)
    local data = load_ecs(file)
    local implement = data[1]
    if implement and implement.what == "implement" then
        table.remove(data, 1)
        for _, v in ipairs(data) do
            if need_implement(v) then
                table.insert(v.value, 1, implement)
            end
        end
    end
    write_ecs(data, file)
end

local function convert_package(name)
    each_dir(packages[name], convert_ecs)
end

local function convert_all_package()
    for name in sortpairs(packages) do
        local ok, err = pcall(convert_package, name)
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
    init_package(fs.path("test/samples/features"))
    init_package(fs.path("tools/modelviewer"))

end

init_all_package()
convert_all_package()
print "ok"
