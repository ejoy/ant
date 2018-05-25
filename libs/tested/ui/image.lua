local nk = require "bgfx.nuklear"


return function (nkimage)
		ui_header("显示图象","#dd00dd")
		nk.layoutRow('dynamic',310,{0.15,0.7,0.15} )
		nk.spacing(1) 
		nk.image( nkimage )
end 
