local fs = require 'backend.worker.filesystem'
local ev = require 'backend.event'
local crc32 = require 'backend.worker.crc32'

local sourcePool = {}
local codePool = {}
local skipFiles = {}
local sourceMaps = {}
local workspaceFolder = nil
local sourceUtf8 = true

local function makeSkipFile(pattern)
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
                local r = {}
                fs.path_normalize(pattern[2]):gsub('[^%*]+', function (w) r[#r+1] = w end)
                sm[2] = r
            else
                sm[2] = fs.path_normalize(pattern[2])
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
    for _, p in ipairs(pattern[2]) do
        s[#s + 1] = p
        s[#s + 1] = res[1]
    end
    return table.concat(s)
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
            return skip, fs.fromwsl(res)
        end
    end
    -- TODO: 忽略没有映射的source？
    return skip, fs.fromwsl(fs.source_normalize(p))
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
        return {
            sourceReference = codeReference(source),
            protos = {},
        }
    end
end

local m = {}

function m.create(source, hide)
    local src = sourcePool[source]
    if src then
        return src
    end
    local newSource = create(source)
    sourcePool[source] = newSource
    if not hide then
        ev.emit('loadedSource', 'new', newSource)
    end
    return newSource
end

function m.c2s(clientsrc)
    -- TODO: 不遍历？
    if clientsrc.sourceReference then
        local ref = clientsrc.sourceReference
        for _, source in pairs(sourcePool) do
            if source.sourceReference == ref then
                return source
            end
        end
    else
        local nativepath = fs.path_native(fs.path_normalize(clientsrc.path))
        for _, source in pairs(sourcePool) do
            if source.path and not source.sourceReference and fs.path_native(fs.path_normalize(source.path)) == nativepath then
                return source
            end
        end
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

function m.getCode(ref)
    return codePool[ref]
end

function m.removeCode(ref)
    local code = codePool[ref]
    sourcePool[code]  = nil
    codePool[ref] = nil
end

function m.clientPath(p)
    return fs.path_relative(p, workspaceFolder)
end

function m.all_loaded()
    for _, source in pairs(sourcePool) do
        ev.emit('loadedSource', 'new', source)
    end
end

return m
