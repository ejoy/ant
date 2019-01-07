local nk = require "bgfx.nuklear"

return function()
	-- 可能需要增加子group 功能，windowBegin/End 不允许嵌套，应用发现
	ui_header("文字布局")
	nk.useFont(1)
	nk.layoutRow('dynamic', 50,1 )
	nk.label("1.Single Line,Hello,Workspace!","left","#FF0000")
	nk.label('2.Single Line,First Line !',"centered","#00FF00")

	nk.layoutRow('static', 50,{180,60,160}  )
	nk.label("1.Single Line,Hello,Workspace!","left","#FF0000")
	nk.label('2.Single Line,First Line !',"centered","#00FF00")
	nk.label('3.Single Line,First Line !',"left","#0000FF")

	nk.layoutRow('static',50,180,2)
	nk.label("1.Hello,Workspace!")
	nk.label('2.First Line !',"left")
	nk.label('3.Second Line !',"centered")
	nk.label("4.Third Line !", "right","#FF0000")
	
	nk.useFont(2)
	nk.layoutRow('dynamic', 50, {0.33,0.33,0.33} )
	nk.label("1.[Hello,Workspace!")
	nk.label('2.[First Line !',"left")
	nk.label('3.[Second Line !',"right")

	nk.layoutRow('dynamic', 50, {0.25,0.25,0.25,0.25} )
	nk.label('1.[Static Second Line !',"centered")
	nk.label("2.[Static Third Line !", "right","#FF0000FF")
	nk.label('3.[Static Second Line !',"left")
	nk.label("4.[Static Third Line !", "centered","#FF0000FF")


end
