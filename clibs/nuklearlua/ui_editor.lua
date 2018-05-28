local nk = require "nuklearlua"
local string = require "string"

local edit_text = { value = 'edit box mode: write your text here ...\n'}
return function ()
      -- when you special background flag,this window will always stay underlayer ,"background"    
		---[[
			nk.setFont( font_msyh_idx )
			if nk.windowBegin("Sample",(1200-500)/5,100,400,300,"movable","border","title","scalable","minimizable","closable") then
				-- dynamci/static, height,cols
				nk.layoutRow("dynamic",20,1);
				nk.button( "Sample A"  ) 
				nk.layoutRow("dynamic",480,1);  
				nk.edit("edit box",edit_text)
                -- windowBegin 内部增加其他图形元素，layoutRow,edit 会影响 windowBegin 的minimizable ，closable 等属性
				-- 需要注意检查修改
			end 
			nk.windowEnd()
			nk.setFont( 0 )
		--]]
end 
