--[[
	mouse order must: what, state
	keyboard order must: key, press, keystate
]]

local keyvalid_mousestate = {"RIGHT",}

return {
	tigger = {
		rotate = {
			-- {name='mouse', "LEFT", 	"MOVE",},
			{name='mouse', "RIGHT", "MOVE",},
		},
		hitstart = {
			{name='mouse', "LEFT", 	"DOWN"},
			{name='mouse', "RIGHT", "DOWN"},
		},
		hitend = {
			{name='mouse', "LEFT", 	"UP"},
			{name='mouse', "RIGHT", "UP"},
		},
	},
	constant = {
		move_forward = {
			{name = 'keyboard', scale=1,  mouse=keyvalid_mousestate, 'W'},
			{name = 'keyboard', scale=1,  mouse=keyvalid_mousestate, 'w'},
			{name = 'keyboard', scale=-1, mouse=keyvalid_mousestate, 'S'},
			{name = 'keyboard', scale=-1, mouse=keyvalid_mousestate, 's'},
		},

		move_right = {			
			{name = 'keyboard', scale=-1, mouse=keyvalid_mousestate, 'A'},
			{name = 'keyboard', scale=-1, mouse=keyvalid_mousestate, 'a'},
			{name = 'keyboard', scale=1,  mouse=keyvalid_mousestate, 'D'},
			{name = 'keyboard', scale=1,  mouse=keyvalid_mousestate, 'd'},
		},
		
		move_up = {
			{name = 'keyboard', scale=1,  mouse=keyvalid_mousestate, 'E'},
			{name = 'keyboard', scale=1,  mouse=keyvalid_mousestate, 'e'},
			{name = 'keyboard', scale=-1, mouse=keyvalid_mousestate, 'Q'},
			{name = 'keyboard', scale=-1, mouse=keyvalid_mousestate, 'q'},
		},
	}

}
