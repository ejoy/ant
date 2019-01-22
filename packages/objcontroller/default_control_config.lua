return {
	tigger = {
		rotate = {
			{name = 'mouse_move', state = {LEFT=true},}
		},
		hitpos = {
			{name = 'mouse_click', what='LEFT', press=true, state={LEFT=true}}
		},
	},
	constant = {
		move_forward = {
			{name = 'keyboard', key = 'W', value=1, state = {}},
			{name = 'keyboard', key = 'w', value=1, state = {}},
		},
		move_backward = {			
			{name = 'keyboard', key = 'S', value=-1, state = {}},
			{name = 'keyboard', key = 's', value=-1, state = {}},
		},
		move_left = {			
			{name = 'keyboard', key = 'A', value=-1, state = {}},
			{name = 'keyboard', key = 'a', value=-1, state = {}}
		},
		move_right = {		
			{name = 'keyboard', key = 'D', value=1, state = {}},
			{name = 'keyboard', key = 'd', value=1, state = {}}
		
		},
		move_up = {			
			{name = 'keyboard', key = 'Q', value=1, state = {}},
			{name = 'keyboard', key = 'q', value=1, state = {}}
		},
		move_down = {			
			{name = 'keyboard', key = 'E', value=-1, state = {}},
			{name = 'keyboard', key = 'e', value=-1, state = {}}
		},
	}

}
