local rootdir = os.getenv("ANTGE") or "."

local argc = select('#', ...)
if argc < 1 then
    error(string.format("3 arguments need, input filename, output filename, rendertype"))
end

local infile = select(1, ...)

dofile(rootdir .. "/libs/init.lua")

local template_filecontent = [[
shader_src = '%s'
]]

local lnkfile = infile .. ".lnk"

template_filecontent = string.format(template_filecontent, infile)

local winfile =  require "winfile"

local lnk = winfile.open(lnkfile, "wb")
lnk:write(template_filecontent)
lnk:close()