local ecs 	= ...
local world	= ecs.world
local w		= world.w

local assetmgr 		= require "main"
local ext_meshbin 	= require "ext_meshbin"

local imesh = {}

imesh.init_mesh = ext_meshbin.init
imesh.delete_mesh = ext_meshbin.delete

local function meshset_append(meshset, mesh)
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

	update_buffer(mesh.vb, meshset.vb)
	update_buffer(mesh.vb2,meshset.vb2)
	update_buffer(mesh.ib, meshset.ib)

	meshset.vbnums[#meshset.vbnums+1] = mesh.vb.num
	meshset.ibnums[#meshset.ibnums+1] = mesh.ib.num
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

local function meshset_build(meshset)
	local vboffsets, iboffsets = build_offset(meshset.vbnums), build_offset(meshset.ibnums)
	return{
		mesh = ext_meshbin.init{
			vb	= tobuffer(meshset.vb),
			vb2	= tobuffer(meshset.vb2),
			ib  = tobuffer(meshset.ib),
		},
		vbnums		= meshset.vbnums,
		ibnums		= meshset.ibnums,
		vboffsets	= vboffsets,
		iboffsets	= iboffsets,
	} 
end

local function meshset_create()
	return {
		vb = init_buffer(),
		vb2= init_buffer(),
		ib = init_buffer(),
		vbnums = {},
		ibnums = {},
	}
end


function imesh.build_meshes(files)
	local meshset = meshset_create()
	for _, mf in ipairs(files) do
		local mesh = assetmgr.resource(mf)
		meshset_append(meshset, mesh)
	end

	return meshset_build(meshset)
end

imesh.meshset_create= meshset_create
imesh.meshset_append= meshset_append
imesh.meshset_build	= meshset_build

return imesh
