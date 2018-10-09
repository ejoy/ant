local assetmgr = require "asset"
local fs = require "filesystem"
local path = require "filesystem.path"

local winfile = require "winfile"
local rawopen = winfile.open or io.open

local function gen_cache_path(srcpath)
	local outputfile = path.replace_ext(srcpath, "antmesh")
	return path.join("cache", outputfile)
end

return function(lk, readmode)
	local c = assetmgr.load(lk)
	local meshpath = c.mesh_src		
	meshpath = path.join(assetmgr.assetdir(), meshpath)
	if not fs.exist(meshpath) then
		error(string.format("file not exist : %s", meshpath))
	end

	local config = c.config
	local assimp = require "assimplua"
	
	local outputfile = gen_cache_path(c.mesh_src)
	path.create_dirs(path.parent(outputfile))
	local ext = path.ext(meshpath):lower()
	if ext == "bin" then
		assimp.convert_BGFXBin(meshpath, outputfile, config)
	elseif ext == "fbx" then
		assimp.convert_FBX(meshpath, outputfile, config)
	elseif ext == "ozz" then
		local ozzmesh_module = require "assimplua.ozzmesh"
		local ozzmesh = ozzmesh_module.new_ozzmesh(meshpath)

		local mapper = {
			p = "position", T = "tangent", n = "normal",
			b = "bitangent", t0 = "texcoord", c0 = "color",
			i = "indices", w = "weights",
		}
		
		local type_size = {
			f = 4, u = 1,
			S = 2,
		}

		local function data_extractor(attrib)
			local sizeInBytes = type_size[attrib.type] * attrib.count
			
			local offset = 1
			local data = attrib.data
			return function()
				local newoffset = offset + sizeInBytes
				assert(#data >= newoffset)
				local elems = data:sub(offset, newoffset - 1)
				offset = newoffset
				return elems
			end
		end

		local function init_extractor(part)
			local extractors = {}
			for k, attrib in pairs(part) do
				extractors[k] = data_extractor(attrib)
			end
			return extractors
		end

		local function write_to_antmesh()
			local streams = config.stream
			
			local group = {}
			local meshdata = {group = group}
			local vb = {}	

			local function stream_elems(s)
				local elems = {}
				for m in s:gmatch("[pTnbtciw]%d?") do
					table.insert(elems, m)
				end
				return elems
			end

			local vbraws = {}
			for _, s in ipairs(streams) do
				local selems = stream_elems(s)

				local buffer_tbl = {}
				local parts = ozzmesh.parts
				for _, part in ipairs(parts) do
					if #selems > 1 then
						local extractors = init_extractor(part)
						for _, m in ipairs(selems) do
							local name = mapper[m]
							if name then
								local extractor = extractors[name]
								if extractor then
									table.insert(buffer_tbl, extractor())			
								else
									error(string.format("not found extractor, name is : %s", name))
								end								
							else
								error(string.format("not found vertex info, need : %s", m))
							end
						end
					else
						local name = assert(mapper[s])
						local attrib = part[name]
						if attrib then
							table.insert(buffer_tbl, attrib.data)
						else
							if name ~= "weights" then
								error(string.format("not found vertex attrib in part: %s", name))
							end
						end
					end
				end
				vbraws[s] = table.concat(buffer_tbl)				
			end

			vb.vbraws = vbraws
			vb.num_vertices = ozzmesh.vertex_count
			
			local function gen_layout()
				local mapper = {
					position = "p30NIf", normal = "n30nIf", tangent = "T30nIf", bitanget = "b30nIf",
					color = "c30NIu", texcoord = "t30NIf",
					indices = "i00NIi",
					weights = "w00NIf",
				}
				local t = {}
				for k, v in pairs(ozzmesh.parts) do
					local elem = mapper[k]
					local count = v.count
					table.insert(t, elem:sub(1, 1) .. count .. elem:sub(3))
				end

				return table.concat(t, '|')
			end

			vb.layout = gen_layout()
			group.vb = vb


			local ib = {}
			ib.format = 2
			ib.ibraw = ozzmesh.indices.data
			ib.num_indices = ozzmesh.indices.num_indices

			group.ib = ib

			group.bounding = ozzmesh.bounding

			group.joint_remaps = ozzmesh.joint_remaps
			group.inverse_bind_poses = ozzmesh.inverse_bind_poses

			meshdata.bounding = ozzmesh.bounding

			local antmesh_writer = require "modelloader.writer"
			antmesh_writer(meshdata, outputfile, "wb")
		end

		write_to_antmesh()
		--assimp.convert_OZZ(meshpath, outputfile, config)
	else
		error(string.format("not support convert mesh format : %s, filename is : %s", ext, meshpath))
	end

	return rawopen(outputfile, readmode)
end