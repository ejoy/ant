local path = require 'new-debugger.path'

local sourcePool = {}
local codePool = {}

local function serverPathToClientPatn(p)
    -- TODO: utf8 or ansi
    -- TODO: skipFiles
    -- TODO: sourceMap
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
        return {
            path = serverPathToClientPatn(source:sub(2))
        }
    elseif h == '=' then
        -- TODO
        return {}
    else
        return {
            ref = codeReference(source)
        }
    end
end

local m = {}

function m.create(source)
    if not sourcePool[source] then
        sourcePool[source] = create(source)
    end
    return sourcePool[source]
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
