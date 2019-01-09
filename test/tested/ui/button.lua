local nk = require "bgfx.nuklear"

return function( nkimage )
	ui_header("按钮组合")
	nk.setFont(1)
	nk.layoutRow('dynamic',40,4)
	nk.button(nil,"#ff0000")     -- color
	nk.button("btn","plus")      -- symbol 
	nk.button("btn","minus")    
	nk.button("image",nk.subImage(nkimage,32,25,64,52))  -- label + image  maybe need align parameter
	nk.layoutRow('static',40,40,1)
    nk.button(nil,nk.subImage(nkimage,32,25,64,52) )     -- only image 
    nk.button(nil,"triangle up" )          		-- only symbol
    nk.button(nil,"triangle down" )         	-- only symbol

end
