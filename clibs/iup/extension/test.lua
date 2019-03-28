local iup = require "iuplua"

local iupex = require "iupextension"
-- iupex.co_initialize()
local img0,w0,h0 = iupex.icon_with_size("D:\\Program Files\\Shadowsocks.exe",0)
local img1,w1,h1 = iupex.icon_with_size("D:\\Program Files\\Shadowsocks.exe",1)
local img2,w2,h2 = iupex.icon_with_size("D:\\Ant\\ant\\packages\\animation\\util.lua",2)
local img3,w3,h3 = iupex.icon_with_size("D:\\Program Files\\Shadowsocks.exe",3)
local img4,w4,h4 = iupex.icon_with_size("D:\\Program Files\\Shadowsocks.exe",4)
-- iupex.co_uninitialize()

print(img0,w0,h0)
print(img1,w1,h1)
print(img2,w2,h2)
print(img3,w3,h3)
print(img4,w4,h4)
local miandlg = iup.dialog {
    iup.vbox{
        iup.label{ image = img0, title = "icon0" },
        iup.label{ image = img1, title = "icon1" },
        iup.label{ image = img2, title = "icon2" },
        iup.label{ image = img3, title = "icon3" },
        iup.label{ image = img4, title = "icon4" },
    },
	title = "exeicon",
	size = "HALFxHALF",
}

miandlg:showxy(iup.CENTER,iup.CENTER)

iup.MainLoop()
iup.Close()
