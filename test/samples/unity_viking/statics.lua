
local Statics = {	
	total_triangles = 0,
	num_mesh_30000 = 0,	
	num_mesh_10000 = 0,
	num_mesh_5000 = 0,
	num_mesh_1000 = 0,
	num_mesh_500 = 0,
	num_mesh = 0, 
}

function Statics.add( group )
	if group.ib.num_indices then 
		local num_triangles = group.ib.num_indices /3
		total_triangles = total_triangles + num_triangles
		if(num_triangles >30000) then 
			num_mesh_30000 = num_mesh_30000 + 1
		elseif (num_triangles >10000 ) then 
			num_mesh_10000 = num_mesh_10000 + 1
		elseif (num_triangles >5000 ) then 
			num_mesh_5000 = num_mesh_5000 + 1
		elseif (num_triangles >1000 ) then 
			num_mesh_1000 = num_mesh_1000 + 1
		elseif (num_triangles >500 ) then 
			num_mesh_500 = num_mesh_500 + 1
		else
			num_mesh = num_mesh + 1
		end 
	end 
end 

function Statics.reset()
	total_triangles = 0
	num_mesh_30000 = 0	
	num_mesh_10000 = 0
	num_mesh_5000 = 0
	num_mesh_1000 = 0
	num_mesh_500 = 0
	num_mesh = 0 
end 

function Statics.collect(world)
	for _, eid in world:each "viewid" do
		local rq = world[eid]
		if rq.visible ~= false then
			local viewid = rq.viewid		

			local filter = rq.primitive_filter
			local render_properties = filter.render_properties
			local results = filter.result

			local result = results.opaque
			if #result >1 then 
				local numopaque = result.cacheidx - 1
				
				for i=1, numopaque do
					local prim = result[i]
					
					local mg = assert(prim.mgroup)
					local ib, vb = mg.ib, mg.vb           

					Statics.add(mg)
				end
			end 

		end
	end 
end

function Statics.print()
	print(" total_triangles = ",total_triangles)
	print(" num_mesh >= 30000 ", num_mesh_30000)
	print(" num_mesh >= 10000 ", num_mesh_10000)
	print(" num_mesh >= 5000", num_mesh_5000 )
	print(" num_mesh >= 1000", num_mesh_1000 )
	print(" num_mesh >= 500",  num_mesh_500 )
	print(" num_mesh <  500",  num_mesh )


end 

return Statics 
