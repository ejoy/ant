local event = require "core.event"

local m = {}

local E = {}

function m.add(document, func)
    local L = E[document]
    L[#L+1] = func
    return {func}
end

function m.remove(document, id)
    local L = E[document]
    if not L then
        return
    end
    local func = id[1]
    for i = 1, #L do
        if L[i] == func then
            table.remove(L, i)
            break
        end
    end
end

function m.dispatch(document, ...)
    local L = E[document]
    local funcs = {}
    table.move(L, 1, #L, 1, funcs)
    for i = 1, #funcs do
        local func = funcs[i]
        func(...)
    end
end

function event.OnDocumentCreate(document)
    E[document] = {}
end

function event.OnDocumentDestroy(document)
    E[document] = nil
end

return m
