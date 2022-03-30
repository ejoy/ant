local constructorTextNode = require "core.DOM.text"
local constructorElement = require "core.DOM.element"

return function (document, owner, handle, type)
    local TEXT_NODE <const> = 0
    local ELEMENT_NODE <const> = 1
    if type == TEXT_NODE then
        return constructorTextNode(document, owner, handle)
    elseif type == ELEMENT_NODE then
        return constructorElement(document, owner, handle)
    end
end
