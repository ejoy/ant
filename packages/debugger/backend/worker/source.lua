local fs = require 'backend.worker.filesystem'
local ev = require 'backend.event'
local crc32 = require 'backend.worker.crc32'

local sourcePool = {}
local codePool = {}
local knownClientPath = {}
local skipFiles = {}
local sourceMaps = {}
local workspaceFolder = nil
local sourceUtf8 = true

local function makeSkipFile(pattern)
    pattern = pattern:gsub("%$%{([^}]*)%}", {
        exe = fs.program_path()
    })
    skipFiles[#skipFiles + 1] = ('^%s$'):format(fs.source_native(fs.source_normalize(pattern)):gsub('[%^%$%(%)%%%.%[%]%+%-%?]', '%%%0'):gsub('%*', '.*'))
end

ev.on('initializing', function(config)
    workspaceFolder = config.workspaceFolder
    sourceUtf8 = config.sourceCoding == 'utf8'
    skipFiles = {}
    sourceMaps = {}
    if config.skipFiles then
        for _, pattern in ipairs(config.skipFiles) do
            makeSkipFile(pattern)
        end
    end
    if config.sourceMaps then
        for _, pattern in ipairs(config.sourceMaps) do
            local sm = {}
            sm[1] = ('^%s$'):format(fs.source_native(fs.source_normalize(pattern[1])):gsub('[%^%$%(%)%%%.%[%]%+%-%?]', '%%%0'))
            if sm[1]:find '%*' then
                sm[1] = sm[1]:gsub('%*', '(.*)')
            end
            sm[2] = fs.path_normalize(pattern[2])
            sourceMaps[#sourceMaps + 1] = sm
        end
    end
end)

ev.on('terminated', function()
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
    return pattern[2]:gsub("%*", res[1])
end

local function covertPath(p)
    p = fs.fromwsl(p)
    local native = fs.path_native(fs.path_normalize(p))
    if knownClientPath[native] then
        p = knownClientPath[native]
        knownClientPath[native] = nil
    end
    return p
end

local function serverPathToClientPath(p)
    if not sourceUtf8 then
        p = fs.a2u(p)
    end
    local skip = false
    local nativePath = fs.source_native(fs.source_normalize(p))
    for _, pattern in ipairs(skipFiles) do
        if glob_match(pattern, nativePath) then
            skip = true
            break
        end
    end
    for _, pattern in ipairs(sourceMaps) do
        local res = glob_replace(pattern, nativePath)
        if res then
            return skip, covertPath(res)
        end
    end
    -- TODO: 忽略没有映射的source？
    return skip, covertPath(fs.source_normalize(p))
end

local function codeReference(s)
    local hash = crc32(s)
    while codePool[hash] do
        if codePool[hash] == s then
            return hash
        end
        hash = hash + 1
    end
    codePool[hash] = s
    return hash
end

local function splitline(source)
    local path, line, content = source:match "^--@([^:]+):(%d+)\n(.*)$"
    if path and line and content then
        return path, tonumber(line), content
    end
    return source:sub(2)
end

local function create(source)
    local h = source:sub(1, 1)
    if h == '@' then
        local serverPath = source:sub(2)
        local skip, clientPath = serverPathToClientPath(serverPath)
        if skip then
            return {
                skippath = clientPath,
            }
        end
        return {
            path = clientPath,
            protos = {},
        }
    elseif h == '=' then
        -- TODO
        return {}
    else
        local serverPath, line, content = splitline(source)
        if serverPath and line and content then
            local skip, clientPath = serverPathToClientPath(serverPath)
            if skip then
                return {
                    skippath = clientPath,
                }
            end
            return {
                path = clientPath,
                protos = {},
                startline = line,
                content = content
            }
        end
        return {
            sourceReference = codeReference(source),
            protos = {},
        }
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
    ev.emit('loadedSource', 'new', newSource)
    return newSource
end

function m.c2s(clientsrc)
    -- TODO: 不遍历？
    if clientsrc.sourceReference then
        local ref = clientsrc.sourceReference
        for _, source in pairs(sourcePool) do
            if source.sourceReference == ref then
                return {source}
            end
        end
    else
        local results = {}
        local nativepath = fs.path_native(fs.path_normalize(clientsrc.path))
        for _, source in pairs(sourcePool) do
            if source.path and not source.sourceReference and fs.path_native(fs.path_normalize(source.path)) == nativepath then
                source.path = clientsrc.path
                results[#results+1] = source
            end
        end
        if #results == 0 then
            knownClientPath[nativepath] = clientsrc.path
            return
        end
        return results
    end
end

function m.valid(s)
    return s.path ~= nil or s.sourceReference ~= nil
end

function m.output(s)
    if s.sourceReference ~= nil then
        return {
            name = '<Memory>',
            sourceReference = s.sourceReference,
        }
    elseif s.path ~= nil then
        return {
            name = fs.path_filename(s.path),
            path = fs.path_normalize(s.path),
        }
    end
end

function m.line(s, currentline)
    if s.startline then
        return currentline + s.startline - 2
    end
    return currentline
end

function m.getCode(ref)
    return codePool[ref]
end

function m.removeCode(ref)
    local code = codePool[ref]
    sourcePool[code]  = nil
    codePool[ref] = nil
end

function m.clientPath(p)
    if workspaceFolder then
        return fs.path_relative(p, workspaceFolder)
    end
    return fs.path_normalize(p)
end

function m.all_loaded()
    for _, source in pairs(sourcePool) do
        ev.emit('loadedSource', 'new', source)
    end
end

return m
