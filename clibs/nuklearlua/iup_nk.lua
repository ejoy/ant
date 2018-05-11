local nk = require 'nuklearlua'
local string = require 'string'
local editor = require 'editor'

-- ui value table
local settings = {
	numLights = 512,
	showGBuffer = true;
	showScissorRects = false;
	animateMesh = true;
	lightAnimationSpeed = 0.3
}

-- slider 
local function slider(key,title,min,max)
	local value = settings[key];
	local integer = math.type(value) == "integer"
	local label = iup.label { title = value,size = "30" }
	local val = iup.val {
		min = min,
		max = max,
		value = value,
		valuechanged_cb = function(self)
			local v = tonumber(self.value)
			if integer then 
				v = math.floor(v)
				label.title   = string.format("%d",v)
				settings[key] = v;
			else 
				settings[key] = v;
				label.title = string.format("%.2f",v)
			end 
		end 
	}
	
	return iup.hbox {
		iup.label{ title = title..":"},  -- slider name
		val,               -- slider 
		label,             -- value 
	}
end

local canvas = iup.canvas{   }

local ctrl_frame = iup.frame {
	title = "IUP Nuklear Framework",
	iup.vbox {
		slider("numLights","Num Lights",1,2048),
	},

}

dlg = iup.dialog {
	iup.hbox {
		iup.vbox {
			ctrl_frame,
			margin = "10x10",
		},
		canvas,
	},
	title = "IUP Sample",
	size = "HALFxHALF",
}

local function mainloop()
	editor()
	nk.mainloop() 
end

function install_mainloop(f)
	iup.SetIdle( function ()
		local ok , err = xpcall(f, debug.traceback)
		if not ok then
			print(err)
			iup.SetIdle()
		end
		return iup.DEFAULT
	end )
end 

---[[
function platform_init(args) 
	print(args.nwh)
	nk.setWindow( args )  -- {} --
	nk.init()   
	font_msyh_idx = nk.loadFont("font/msyh.ttf",16) 
end 
--]]

local function init()

	platform_init { nwh = iup.GetAttributeData(canvas,"HWND"), } 
	--nk.setWindow { nwh = iup.GetAttributeData(canvas,"HWND"), }  --( args )
	--nk.init()    

    install_mainloop( mainloop )
end 


function canvas:resize_cb(w,h)
	if init then 
		init(self)
		init = nil 
	end 
	nk.setWindowSize(w,h);
end
---[[
function canvas:action(x,y)
	-- after resize window,must be redraw all context in canvas window 
	-- or don't defined action ,will redraw canvas auto.
	--mainloop()
end 
--]]

-- mouse callback
function canvas:button_cb(button,pressed,x,y,status)
	-- left =49，middle=50，right =51
	if pressed == 0 then
		print("button ="..button.." released")
	else
		print("button ="..button.." pressed")
	end 
	nk.mouse(button,x,y,pressed)
end 
function canvas:motion_cb(x,y)
	print("mouse( ".."x= "..x..", y= "..y.." )")
	nk.motion(x,y)
end 
function canvas:wheel_cb(delta,x,y,status)
	print("wheel delta="..delta..",x="..x,"y="..y)
end 

-- key callback 
function canvas:keypress_cb(code,pressed)
	if(pressed) then
		print("code= "..code.." is pressed")
	else 
	    print("code= "..code.." is released")
	end 
	if(code == K_UP) then
	  code = code >>16
	  print("code shift "..code)
	end 
end 


-- run app --
dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

if( iup.MainLoopLevel() == 0) then
  nk.mainloop() 
  iup.MainLoop()  

  iup.Close()
  print("iup_nk shutdown\n")
end


