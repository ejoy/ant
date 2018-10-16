local util = {}
util.__index = util

function util.default_config()
	return {
		--[[
			layout element inlcude 6 char, like : n30nif
			first char is attribute type, includes:			
				p	-->	position
				n	--> normal
				T	--> tangent
				b	--> bitangent
				t	--> texcoord
				c	--> color
				i	--> indices
				w	--> weight
			second char is element count, can be 1, 2 3 and 4
			third char is channel index, can be [0, 7], 0 is default number
			forth char is normalize flag, n for normalize data, N for NOT normalize data
			fifth char is as integer flag, i for as integer data, I for NOT interger data
			sixth char is element type, f for float, h for half float, u for uint8, U for uint10, i for int16
			examples : 
				n30nif means : 	normal with 3 element(x,y,z) at channel 0 
								normalize to [0, 1], as integer data, save as float type
				p3 means: position with 3 element(x,y,z) at channel 0, NOT normalize and NOT as int, using float type
				T means: tangent with 3 element(x,y,z) at channel 0, NOT normalize and NOT as int, using float type
			
			layout string can be used to create bgfx_vertex_decl_t
		]] 
		layout = {
			"p3|n30nIf|T|b|t20|c40",
		},
		flags = {
			invert_normal 	= false,
			flip_uv 		= true,
			ib_32 			= false,	-- if index num is lower than 65535
		},
		animation = {
			load_skeleton 	= true,
			ani_list 		= "all", 	-- or {"walk", "stand"}
			cpu_skinning 	= false,
		},
	}
end

-- need move to bgfx c module
function util.create_decl(vb_layout)
	local decl = {}
	for e in vb_layout:gmatch("%w+") do 
		assert(#e == 6)
		local function get_attrib(e)
			local t = {	
				p = "POSITION",	n = "NORMAL", T = "TANGENT",	b = "BITANGENT",
				i = "INDICES",	w = "WEIGHT",
				c = "COLOR", t = "TEXCOORD",
			}
			local a = e:sub(1, 1)
			local attrib = assert(t[a])
			if attrib == "COLOR" or attrib == "TEXCOORD" then
				local channel = e:sub(3, 3)
				return attrib .. channel
			end

			return attrib
		end
		local attrib = get_attrib(e)
		local num = tonumber(e:sub(2, 2))

		local function get_type(v)					
			local t = {	
				u = "UINT8", U = "UINT10", i = "INT16",
				h = "HALF",	f = "FLOAT",
			}
			return assert(t[v])
		end

		local normalize = e:sub(4, 4) == "n"
		local asint= e:sub(5, 5) == "i"
		local type = get_type(e:sub(6, 6))

		table.insert(decl, {attrib, num, type, normalize, asint})
	end

	local bgfx = require "bgfx"
	return bgfx.vertex_decl(decl)
end

return util