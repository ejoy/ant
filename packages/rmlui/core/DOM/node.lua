local constructor = require "core.DOM.constructor"

return function (document, owner, handle, type)
    local TEXT_NODE <const> = 0
    local ELEMENT_NODE <const> = 1
    if type == TEXT_NODE then
        return constructor.Text(document, owner, handle)
    elseif type == ELEMENT_NODE then
        return constructor.Element(document, owner, handle)
    end
end
