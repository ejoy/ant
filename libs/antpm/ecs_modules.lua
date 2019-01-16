local vfsfs = require "filesystem"

local function glob_compile(pattern)
    return ("^%s$"):format(pattern:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0"):gsub("%*", ".*"))
end

local function glob_match(pattern, target)
    return target:match(pattern) ~= nil
end

local function accept_path(t, path)
    if t[path:string()] then
        return
    end
    t[#t+1] = path
    t[path:string()] = #t
end

local function expand_dir(t, pattern, dir)
    for file in dir:list_directory() do
        if vfsfs.is_directory(file) then
            expand_dir(t, pattern, file)
        else
            if glob_match(pattern, file:filename():string()) then
                accept_path(t, file)
            end
        end
    end
end

local function expand_path(t, path)
    local filename = path:filename():string()
    if filename:find("*", 1, true) == nil then
        accept_path(t, path)
        return
    end
    local pattern = glob_compile(filename)
    expand_dir(t, pattern, path:parent_path())
end

local function get_sources(root, sources)
    local result = {}
    local ignore = {}
    for _, source in ipairs(sources) do
        if source:sub(1,1) ~= "!" then
            expand_path(result, root / source)
        else
            expand_path(ignore, root / source:sub(2))
        end
    end
    for _, path in ipairs(ignore) do
        local pos = result[path]
        if pos then
            result[pos] = result[#result]
            result[result[pos]:string()] = pos
            result[path] = nil
            result[#result] = nil
        end
    end
    return result
end

return function (root, sources)
	local results = {}	
    for _, path in ipairs(get_sources(root, sources)) do
        for line in vfsfs.lines(path) do
            if line:match "^[%s]*local[%s]+ecs[%s]*=[%s]*%.%.%.[%s]*$" then
                results[#results+1] = path
                break
            end
        end
    end
    return results
end
