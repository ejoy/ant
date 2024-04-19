local ecs 	= ...
local world	= ecs.world
local w		= world.w

local assetmgr 		= require "main"
local ext_meshbin 	= require "ext_meshbin"

local imesh = {}

imesh.init_mesh = ext_meshbin.init
imesh.delete_mesh = ext_meshbin.delete

local function append_mesh(mesh, meshout)
	local function update_buffer(b, ob)
		if b then
			local om 	= ob.memory
			local str 	= b.str
			om.list[#om.list+1] = str
			om[3]		= om[3] + #str

			ob.num 		= ob.num + b.num
			ob.declname = b.declname
			ob.flag		= b.flag
		end
	end

	update_buffer(mesh.vb, meshout.vb)
	update_buffer(mesh.vb2,meshout.vb2)
	update_buffer(mesh.ib, meshout.vb)

	meshout.vbnums[#meshout.vbnums+1] = mesh.vb.num
	meshout.ibnums[#meshout.ibnums+1] = mesh.ib.num
end

local function init_buffer() return {start=0, num=0, memory = {list={}, nil, 1, 0} } end

local function tobuffer(b)
	if b.num > 0 then
		b.memory[1] = table.concat(b.memory.list, "")
		b.memory.list = nil
		return b
	end
end

local function build_offset(nums)
	if #nums > 0 then
		local offsets = {0}
		for i=1, #nums-1 do
			offsets[#offsets+1] = offsets[#offsets] + nums[i]
		end
		return offsets
	end
end

local function build_meshlist(meshout)
	local vboffsets, iboffsets = build_offset(meshout.vbnums), build_offset(meshout.ibnums)
	return{
		mesh = ext_meshbin.init{
			vb	= tobuffer(meshout.vb),
			vb2	= tobuffer(meshout.vb2),
			ib  = tobuffer(meshout.ib),
		},
		vbnums		= meshout.vbnums,
		ibnums		= meshout.ibnums,
		vboffsets	= vboffsets,
		iboffsets	= iboffsets,
	} 
end

function imesh.build_meshes(files)
	local meshout = {
		vb = init_buffer(),
		vb2= init_buffer(),
		ib = init_buffer(),
		vbnums = {},
		ibnums = {},
	}
	for _, mf in ipairs(files) do
		local mesh = assetmgr.resource(mf)
		append_mesh(mesh, meshout)
	end

	return build_meshlist(meshout)
end

return imesh
