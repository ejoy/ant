local path = require 'new-debugger.path'
local parser = require 'new-debugger.backend.worker.parser'
local ev = require 'new-debugger.event'

local sourcePool = {}
local codePool = {}
local skipFiles = {}
local sourceMaps = {}
local workspaceFolder = nil

ev.on('initialized', function(config)
    workspaceFolder = config.workspaceFolder
    skipFiles = {}
    sourceMaps = {}
    if config.skipFiles then
        for _, pattern in ipairs(config.skipFiles) do
            skipFiles[#skipFiles + 1] = ('^%s$'):format(path.normalize_native(pattern):gsub('[%^%$%(%)%%%.%[%]%+%-%?]', '%%%0'):gsub('%*', '.*'))
        end
    end
    if config.sourceMaps then
        for _, pattern in ipairs(config.sourceMaps) do
            local sm = {}
            sm[1] = ('^%s$'):format(path.normalize_native(pattern[1]):gsub('[%^%$%(%)%%%.%[%]%+%-%?]', '%%%0'))
            if sm[1]:find '%*' then
                sm[1]:gsub('%*', '(.*)')
                local r = {}
                path.normalize(pattern[2]):gsub('[^%*]+', function (w) r[#r+1] = w end)
                sm[2] = r
            else
                sm[2] = path.normalize(pattern[2])
            end
            sourceMaps[#sourceMaps + 1] = sm
        end
    end
end)

ev.on('terminated', function()
    sourcePool = {}
    codePool = {}
    skipFiles = {}
    sourceMaps = {}
    workspaceFolder = nil
end)

local function glob_match(pattern, target)
    return target:match(pattern) ~= nil
end

local function glob_replace(pattern, target)
    local res = table.pack(target:match(pattern[1]))
    if res[1] == nil then
        return false
    end
    if type(pattern[2]) == 'string' then
        return pattern[2]
    end
    local s = {}
    for i, p in ipairs(pattern[2]) do
        s[#s + 1] = p
        s[#s + 1] = res[1]
    end
    return table.concat(s)
end

local function serverPathToClientPath(p)
    -- TODO: utf8 or ansi
    local skip = false
    local nativePath = path.normalize_native(p)
    for _, pattern in ipairs(skipFiles) do
        if glob_match(pattern, nativePath) then
            skip = true
            break
        end
    end
    for _, pattern in ipairs(sourceMaps) do
        local res = glob_replace(pattern, nativePath)
        if res then
            return skip, res
        end
    end
    -- TODO: 忽略没有映射的source？
    return skip, path.normalize(p)
end

local function codeReference(s)
    if not codePool[s] then
        codePool[#codePool + 1] = s
        codePool[s] = #codePool
    end
    return codePool[s]
end

local function create(source)
    local h = source:sub(1, 1)
    if h == '@' then
        local serverPath = source:sub(2)
        local skip, clientPath = serverPathToClientPath(serverPath)
        if skip then
            return { skippath = clientPath }
        end
        local src = { path = clientPath }
        local f = loadfile(serverPath)
        if f then
            parser(src, f)
        end
        return src
    elseif h == '=' then
        -- TODO
        return {}
    else
        local src = {
            ref = codeReference(source)
        }
        local f = load(source)
        if f then
            parser(src, f)
        end
        return src
    end
end

local m = {}

function m.create(source)
    local src = sourcePool[source]
    if src then
        return src
    end
    local newSource = create(source)
    sourcePool[source] = newSource
    ev.emit('source-create', newSource)
    return newSource
end

function m.open(clientpath)
    -- TODO: 不遍历？
    local nativepath = path.normalize_native(clientpath)
    for _, source in pairs(sourcePool) do
        if source.path and path.normalize_native(source.path) == nativepath then
            return source
        end
    end
end

function m.valid(s)
    return s.path ~= nil or s.ref ~= nil
end

function m.output(s)
    if s.path ~= nil then
        return {
            name = path.filename(s.path),
            path = path.normalize(s.path),
        }
    elseif s.ref ~= nil then
        return {
            name = '<Memory>',
            sourceReference = s.ref,
        }
    end
end

function m.getCode(ref)
    return codePool[ref]
end

function m.clientPath(p)
    return path.relative(p, workspaceFolder, '/')
end

return m
