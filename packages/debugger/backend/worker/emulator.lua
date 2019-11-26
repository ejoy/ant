local source = require 'backend.worker.source'
local variables = require 'backend.worker.variables'
local rdebug = require 'remotedebug.visitor'

local m = {}

local stacks = {}
local scopes = {}
local enable = false
local kVirtualFrameId <const> = 0xff0000

function m.open()
    enable = true
end

function m.close()
    enable = false
end

function m.stackTrace()
    if not enable then
        return {}
    end
    local res = {}
    for i, s in ipairs(stacks) do
        res[i] = s
    end
    return res
end

function m.getCode(sourceReference)
    for _, s in ipairs(stacks) do
        if s.source.sourceReference == sourceReference then
            return s.code
        end
    end
    return source.getCode(sourceReference)
end

function m.scopes(frameId)
    if not enable or frameId ~= kVirtualFrameId then
        return variables.scopes(frameId)
    end
    local scope = scopes[1]
    local res = {}
    local i = 1
    while true do
        local s = rdebug.indexv(scope, i)
        if s == nil then
            break
        end
        local var = variables.createRef(rdebug.fieldv(s, "value"), nil, "scopes")
        if var.variablesReference then
            res[#res+1] = {
                name = rdebug.fieldv(s, "name"),
                variablesReference = var.variablesReference,
                namedVariables = var.namedVariables,
                indexedVariables = var.indexedVariables,
                expensive = false,
            }
        end
        i = i + 1
    end
    return res
end

function m.eventCall(state, code, name)
    table.insert(stacks, 1, {
        id = kVirtualFrameId,
        code = code,
        name = name,
        source = source.create(code, true),
        column = 1,
    })
    return state == 'stepIn'
end

function m.eventReturn()
    source.removeCode(stacks[1].source.sourceReference)
    table.remove(stacks, 1)
    table.remove(scopes, 1)
end

function m.eventLine(state, line, scope)
    if state == 'stepIn' or state == 'stepOver' then
        stacks[1].line = line
        scopes[1] = scope
        return true
    end
    return false
end

return m
