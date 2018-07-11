local rdebug = require 'remotedebug'

local step = false
local bp = false
local linebp = false

local function update()
    if linebp then
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

function m.openStep()
    step = true
    update()
end

function m.closeStep()
    step = false
    update()
end

function m.openBP()
    bp = true
    update()
end

function m.closeBP()
    bp = false
    update()
end

function m.openLineBP()
    linebp = true
    update()
end

function m.closeLineBP()
    linebp = false
    update()
end

return m
