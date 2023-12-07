local m = {}

function m:init()
    self.Element = require "core.DOM.element"
    self.Text = require "core.DOM.text"
    self.Node = require "core.DOM.node"
    self.Document = require "core.DOM.document"
    self.Window = require "core.DOM.window"
end

return m
