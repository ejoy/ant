local rdebug = require 'remotedebug'
local ev = require 'new-debugger.event'

local stepin = false
local step = false
local bp = false
local linebp = false

local function update()
    if linebp or stepin then
        rdebug.hookmask 'crl'
        return
    end
    if bp or step then
        rdebug.hookmask 'cr'
        return
    end
    rdebug.hookmask ''
end

local m = {}

function m.updateCoroutine(co)
    if linebp or stepin then
        rdebug.hookmask(co, 'crl')
        return
    end
    if bp or step then
        rdebug.hookmask(co, 'cr')
        return
    end
    rdebug.hookmask(co, '')
end

function m.openStep()
    if step then
        return
    end
    step = true
    update()
end

function m.closeStep()
    if not step then
        return
    end
    step = false
    update()
end

function m.openStepIn()
    if stepin then
        return
    end
    stepin = true
    update()
end

function m.closeStepIn()
    if not stepin then
        return
    end
    stepin = false
    update()
end

function m.openBP()
    if bp then
        return
    end
    bp = true
    update()
end

function m.closeBP()
    if not bp then
        return
    end
    bp = false
    linebp = false
    update()
end

function m.openLineBP()
    if linebp then
        return
    end
    if bp then
        linebp = true
        update()
    end
end

function m.closeLineBP()
    if not linebp then
        return
    end
    if bp then
        linebp = false
        update()
    end
end

function m.reset()
    stepin = false
    step = false
    bp = false
    linebp = false
    update()
end

ev.on('terminated', function()
    m.reset()
end)

return m
