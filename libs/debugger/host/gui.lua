require 'iuplua'
require 'scintilla'
local ev = require 'debugger.event'

iup.SetGlobal('UTF8MODE', 'YES')
iup.SetGlobal('UTF8MODE_FILE', 'YES')

local tabs = iup.tabs  {
    SHOWCLOSE = 'YES',
}

local function window_create(title)
    local window = iup.scintilla {
        MARGINWIDTH0 = '30',	-- line number
        STYLEFONT33 = 'Consolas',
        STYLEFONTSIZE33 = '14',
        STYLEVISIBLE33 = 'NO',
        USEPOPUP = 'NO',
        EXPAND = 'YES',
        WORDWRAP = 'CHAR',
        APPENDNEWLINE = 'NO',
        CARETSTYLE = 'INVISIBLE',
        READONLY = 'YES',
        LEXERLANGUAGE = 'lua',
        STYLEFGCOLOR1 = '0 128 0',    -- 1-comment
        STYLEFGCOLOR2 = '0 128 0',    -- 2-comment
        STYLEFGCOLOR4 = '255 128 0',  -- 4-Number
        STYLEFGCOLOR5 = '0 0 255',    -- 5-Keyword0
        STYLEFGCOLOR6 = '164 0 164',  -- 6-String
        STYLEFGCOLOR7 = '164 0 164',  -- 7-Character
        STYLEFGCOLOR10 = '20 20 200', --10-Operator
        STYLEFGCOLOR13 = '200 80 40', --13-Keyword2
        KEYWORDS0 = 'and break do else elseif end false for function goto if in local nil not or repeat return then true until while',
        KEYWORDS1 = 'ipairs error utf8 rawset tostring select tonumber _VERSION loadfile xpcall string rawlen print rawequal setmetatable require getmetatable next package coroutine io _G math collectgarbage os table dofile pcall load module rawget debug assert type pairs bit32',

        --STYLEBOLD10 = 'YES',

        MARGINWIDTH0 = '16',
        MARGINTYPE0 = 'SYMBOL',
        MARGINSENSITIVE0 = 'YES',
        MARGINMASK0 = '14',

        MARGINWIDTH1 = '24',
        MARGINTYPE1 = 'NUMBER',
        MARGINMASK1 = '0',

        MARKERFGCOLOR1 = '255 0 0',
        MARKERBGCOLOR1 = '255 0 0',
        MARKERSYMBOL1 = 'CIRCLE',

        MARKERBGCOLOR2 = '0 255 0',
        MARKERALPHA2 = '80',
        MARKERSYMBOL2 = 'BACKGROUND',

        MARKERFGCOLOR3 = '0 0 0',
        MARKERBGCOLOR3 = '0 255 0',
        MARKERALPHA3 = '80',
        MARKERSYMBOL3 = 'SHORTARROW',
    }

    window.breakpoints = {}

    function window:marginclick_cb(margin, lineno, _)
        if margin ~= 0 then
            return
        end
        if window.breakpoints[lineno + 1] then
            window.breakpoints[lineno + 1] = nil
            window['MARKERDELETE' .. lineno] = 1
        else
            window.breakpoints[lineno + 1] = true
            window['MARKERADD' .. lineno] = 1
        end
        ev.emit('gui-breakpoint', title, window.breakpoints)
    end
    window.TABTITLE = title
    return window
end

local function window_settext(wnd, text)
    wnd.READONLY = 'NO'
    wnd.VALUE = text
    wnd.READONLY = 'YES'

    tabs:append(wnd)
    iup.Map(wnd)
    iup.Refresh(tabs)

    local ln = 1 + math.floor(math.log(tonumber(wnd.LINECOUNT) or 0, 10))
    wnd.MARGINWIDTH1 = tostring(16 + 8*ln)
end

local play     = iup.button { TITLE = '▶️', FLAT = 'YES', CANFOCUS = 'NO', SIZE = '16x12' }
local stepover = iup.button { TITLE = '➡️', FLAT = 'YES', CANFOCUS = 'NO', SIZE = '16x12' }
local stepin   = iup.button { TITLE = '⤵️', FLAT = 'YES', CANFOCUS = 'NO', SIZE = '16x12' }
local stepout  = iup.button { TITLE = '⤴️', FLAT = 'YES', CANFOCUS = 'NO', SIZE = '16x12' }
local stop     = iup.button { TITLE = '⏹️', FLAT = 'YES', CANFOCUS = 'NO', SIZE = '16x12', ACTIVE = 'NO' }

function play:action()
    if self.TITLE == '▶️' then
        ev.emit('gui-toolbar', 'continue')
    else
        ev.emit('gui-toolbar', 'pause')
    end
end
function stepover:action()
    ev.emit('gui-toolbar', 'stepover')
end
function stepin:action()
    ev.emit('gui-toolbar', 'stepin')
end
function stepout:action()
    ev.emit('gui-toolbar', 'stepout')
end
function stop:action()
    ev.emit('gui-toolbar', 'stop')
end

local dlg = iup.dialog {
    iup.vbox { iup.hbox { play, stepover, stepin, stepout, stop }, tabs},
    TITLE = 'Ant Debug',
    SIZE = '600x400'
}

dlg:show()

function dlg:k_any(c)
    if c == iup.K_F5 then
        if play.TITLE == '▶️' then
            play:action()
        end
        return iup.IGNORE
    elseif c == iup.K_F6 then
        if play.TITLE ~= '▶️' then
            play:action()
        end
        return iup.IGNORE
    elseif c == iup.K_F10 then
        stepover:action()
        return iup.IGNORE
    elseif c == iup.K_F11 then
        stepin:action()
        return iup.IGNORE
    elseif c == iup.XkeyShift(iup.K_F5) then
        stop:action()
        return iup.IGNORE
    elseif c == iup.XkeyShift(iup.K_F11) then
        stepout:action()
        return iup.IGNORE
    end
end

local m = {}

local wnds = {}
function m.openwindow(title)
    if not wnds[title] then
        local wnd = window_create(title)
        wnds[title] = wnd
        return wnd, false
    end
    return wnds[title], true
end

function m.settext(wnd, text)
    window_settext(wnd, text)
end

local pcWindow
local pcLineno
function m.setarrow(window, lineno)
    m.cleanarrow()
    pcWindow = window
    pcLineno = lineno - 1
    tabs.VALUE = pcWindow
    pcWindow['MARKERADD' .. pcLineno] = 2
    pcWindow['MARKERADD' .. pcLineno] = 3
    pcWindow.CARET = ('%d,0'):format(pcLineno + 20)
    pcWindow.CARET = ('%d,0'):format(pcLineno)
end

function m.cleanarrow()
    if pcWindow then
        pcWindow['MARKERDELETE' .. pcLineno] = 2
        pcWindow['MARKERDELETE' .. pcLineno] = 3
        pcWindow = nil
        pcLineno = nil
    end
end

function m.btn_run()
    play.TITLE = '▶️'
    stepover.ACTIVE = 'YES'
    stepin.ACTIVE = 'YES'
    stepout.ACTIVE = 'YES'
end

function m.btn_stop()
    play.TITLE = '⏸️'
    stepover.ACTIVE = 'NO'
    stepin.ACTIVE = 'NO'
    stepout.ACTIVE = 'NO'
end

function tabs:tabclose_cb(pos)
    local h = iup.GetChild(self, pos)
    if not h then
        return iup.CONTINUE
    end
    if pcWindow == h then
        m.cleanarrow()
    end
    for k, v in pairs(wnds) do
        if v == h then
            wnds[k] = nil
            return iup.CONTINUE
        end
    end
end 

function m.update()
    local msg = iup.LoopStep()
    if msg == iup.CLOSE then
        iup.Close()
        return true
    end
end

return m
