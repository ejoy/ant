return {
	tigger = {
		rotate = {
			{name = 'mouse_move', state = {LEFT=true},},
			{name = 'mouse_move', state = {RIGHT=true},}
		},
		hitstart = {
			{name = 'mouse_click', what='LEFT', press=true},
			{name = 'mouse_click', what='RIGHT', press=true}
		},
		hitend = {
			{name = 'mouse_click', what='LEFT', press=false},
			{name = 'mouse_click', what='RIGHT', press=false}
		}
	},
	constant = {
		move_forward = {
			{name = 'keyboard', key = 'W', scale=1, state = {}},
			{name = 'keyboard', key = 'w', scale=1, state = {}},
			{name = 'keyboard', key = 'S', scale=-1, state = {}},
			{name = 'keyboard', key = 's', scale=-1, state = {}},
		},

		move_left = {			
			{name = 'keyboard', key = 'A', scale=-1, state = {}},
			{name = 'keyboard', key = 'a', scale=-1, state = {}},
			{name = 'keyboard', key = 'D', scale=1, state = {}},
			{name = 'keyboard', key = 'd', scale=1, state = {}}
		},
		
		move_up = {			
			{name = 'keyboard', key = 'Q', scale=1, state = {}},
			{name = 'keyboard', key = 'q', scale=1, state = {}},
			{name = 'keyboard', key = 'E', scale=-1, state = {}},
			{name = 'keyboard', key = 'e', scale=-1, state = {}}
		},
	}

}
