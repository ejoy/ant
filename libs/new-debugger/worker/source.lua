local path = require 'new-debugger.path'
local parser = require 'new-debugger.worker.parser'
local ev = require 'new-debugger.event'

local sourcePool = {}
local codePool = {}
local skipFiles = {}

ev.on('update-config', function(config)
    skipFiles = {}
    if config.skipFiles then
        for _, pattern in ipairs(config.skipFiles) do
            skipFiles[#skipFiles + 1] = path.normalize_native(pattern):gsub('[%^%$%(%)%%%.%[%]%+%-%?]', '%%%0'):gsub('%*', '.*')
        end
    end
end)

local function glob_match(pattern, target)
    return target:match(pattern) ~= nil
end

local function serverPathToClientPatn(p)
    -- TODO: utf8 or ansi
    -- TODO: sourceMap
    local nativePath = path.normalize_native(p)
    for _, pattern in ipairs(skipFiles) do
        if glob_match(pattern, nativePath) then
            return
        end
    end
    return path.normalize(p)
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
        local clientPath = serverPathToClientPatn(serverPath)
        if not clientPath then
            return {}
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

return m
