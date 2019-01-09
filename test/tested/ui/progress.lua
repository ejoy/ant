local nk = require "bgfx.nuklear"
local pvt = { value = 10 }
local pv  = 20

return function (nkimage)
    ui_header("进度条")

    nk.setFont(2)
    nk.layoutRow('dynamic',50,{0.1,0.2,0.7})
    nk.label("table")
	nk.label(pvt.value,"centered")
    nk.progress(pvt,100,true)
    nk.label("number")
	nk.label(pv,"centered")
	pv = nk.progress(pv,100,true)
	nk.setFont(1)
end 
