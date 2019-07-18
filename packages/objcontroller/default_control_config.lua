local keyvalid_mousestate = {what="RIGHT", state = "DOWN"}

return {
	tigger = {
		rotate = {
			{name = 'mouse', what="LEFT",	state="MOVE",},
			{name = 'mouse', what="RIGHT", 	state="MOVE",},
		},
		hitstart = {
			{name = 'mouse', what='LEFT', 	state="DOWN"},
			{name = 'mouse', what='RIGHT', 	state="DOWN"},
		},
		hitend = {
			{name = 'mouse', what='LEFT', 	state="UP"},
			{name = 'mouse', what='RIGHT', 	state="UP"},
		},
	},
	constant = {
		move_forward = {
			{name = 'keyboard', key = 'W', scale=1,  mouse=keyvalid_mousestate},
			{name = 'keyboard', key = 'w', scale=1,  mouse=keyvalid_mousestate},
			{name = 'keyboard', key = 'S', scale=-1, mouse=keyvalid_mousestate},
			{name = 'keyboard', key = 's', scale=-1, mouse=keyvalid_mousestate},
		},

		move_left = {			
			{name = 'keyboard', key = 'A', scale=-1, mouse=keyvalid_mousestate},
			{name = 'keyboard', key = 'a', scale=-1, mouse=keyvalid_mousestate},
			{name = 'keyboard', key = 'D', scale=1, mouse=keyvalid_mousestate},
			{name = 'keyboard', key = 'd', scale=1, mouse=keyvalid_mousestate},
		},
		
		move_up = {			
			{name = 'keyboard', key = 'Q', scale=1, mouse=keyvalid_mousestate},
			{name = 'keyboard', key = 'q', scale=1, mouse=keyvalid_mousestate},
			{name = 'keyboard', key = 'E', scale=-1, mouse=keyvalid_mousestate},
			{name = 'keyboard', key = 'e', scale=-1, mouse=keyvalid_mousestate},
		},
	}

}
