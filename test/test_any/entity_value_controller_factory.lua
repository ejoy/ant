local log = log and log(...) or print

require "iupluacontrols"

local iupcontrols   = import_package "ant.iupcontrols"
local editor = import_package "ant.editor"
local math = import_package "ant.math"
local ms = math.stack
local su = import_package "ant.serialize"

local entity_value_controller_factory = {}

function  entity_value_controller_factory.real( name,value,fun )
    -- body
    local value_str = string.format("%7g",value)
    local text_ctrl = iup.text {
        value = value_str,
        MASK = iup.MASK_FLOAT,
        MULTILINE = "NO",
        EXPAND = "HORIZONTAL",
    }
    local old_str = value_str
    function text_ctrl:valuechanged_cb(value)
        if fun(tonumber(value)) then
            old_str = value
        else
            text_ctrl.value = old_str
        end
    end
    local mb = iup.hbox({
        iup.label {title = string.format("%s:",name) },
        text_ctrl
    })
    return mb
end


function entity_value_controller_factory.boolean( name,value,fun )
    local value_str = value and "ON" or "OFF"
    local toggle = iup.toggle {
        title = name,
        value = value_str,

    }
    local cur_bvalue = value
    function toggle:valuechanged_cb()
        local value = (toggle.value == "ON" )
        if fun(value) then
            cur_bvalue = value
        else
            toggle.value = (cur_bvalue and "ON" or "OFF")
        end
    end
    return toggle
end

function entity_value_controller_factory.string( name,value,fun )
    local value_str = tostring(value)
    local text_ctrl = iup.text {
        value = value_str,
        MULTILINE = "NO",
        EXPAND = "HORIZONTAL",
    }
    local old_str = value_str
    function text_ctrl:valuechanged_cb(value)
        if fun(value) then
            old_str = value
        else
            text_ctrl.value = old_str
        end
    end
    local mb = iup.hbox({
        iup.label {title = string.format("%s:",name) },
        text_ctrl,
    })
    return mb
end

function entity_value_controller_factory.int( name,value,fun )
    local value_str = string.format("%s",name)
    local text_ctrl = iup.text {
        value = value_str,
        MASK = iup.MASK_INT,
        MULTILINE = "NO",
        EXPAND = "HORIZONTAL",
    }
    local old_str = value_str
    function text_ctrl:valuechanged_cb(value)
        if fun(tonumber(value)) then
            old_str = value
        else
            text_ctrl.value = old_str
        end
    end
    local mb = iup.hbox({
        iup.label {title = string.format("%s:",name) },
        text_ctrl
    })
    return mb
end

function entity_value_controller_factory.vector( name,value,fun )
    local real4 = value
    local gridbox = iup.gridbox {
        numdiv = 4
    }
    local mb = iup.hbox({
        iup.label {title = string.format("%s:",name) },
        gridbox,
    })
    for i = 1,4 do
        local value_str = string.format("%7g",real4[i])
        local text_ctrl = iup.text {
            value = value_str,
            MASK = iup.MASK_FLOAT,
            MULTILINE = "NO",
            EXPAND = "HORIZONTAL",
        }
        iup.Append(gridbox,text_ctrl)
    end

    return mb
end

function entity_value_controller_factory.uniformdata(name,value,fun)
    return entity_value_controller_factory.vector(name,value,fun)
end

function entity_value_controller_factory.matrix( name,value,fun )
    local real16 = value
    local gridbox = iup.gridbox {
        numdiv = 4
    }
    local mb = iup.vbox({
        iup.label {title = string.format("%s:",name) },
        gridbox,
    })
    for i = 1,16 do
        local value_str = string.format("%7g",real16[i])
        local text_ctrl = iup.text {
            value = value_str,
            MASK = iup.MASK_FLOAT,
            MULTILINE = "NO",
            EXPAND = "HORIZONTAL",
        }
        iup.Append(gridbox,text_ctrl)
    end

    return mb
end

function entity_value_controller_factory.color(name,value,fun)
    local label = iup.label {
        title = string.format("%s:%s(todo)",name,value)
    }
    return label
end

return entity_value_controller_factory