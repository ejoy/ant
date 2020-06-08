local util = {}

function util.get_mainqueue_transform_boundings(world, transformed_boundings)
	local mq = world:singleton_entity "main_queue"
	local filter = mq.primitive_filter
	for _, fname in ipairs{"opaticy", "translucent"} do
		local result = filter.result[fname]
		local visibleset = result.visible_set.n and result.visible_set or result
		local num = visibleset.n
		if num > 0 then
			for i=1, num do
				local prim = visibleset[i]
				transformed_boundings[#transformed_boundings+1] = prim.aabb
			end
		end
	end
end

function util.check_rendermesh_lod(meshscene, lod_scene)
	if meshscene.scenelods then
		if meshscene.scenelods[meshscene.scene] == nil then
			log.warn("not found scene from scenelods", meshscene.scene)
		end
	else
		if meshscene.scene ~= lod_scene then
			log.warn("default lod scene is not equal to lodidx")
		end
	end
end

function util.entity_bounding(entity)
	assert(false, "TODO")
	--if entity.can_render then
	--	local meshscene = entity.render-mesh
	--	local etrans = entity.transform.srt
	--	local scene = meshscene.scenes[meshscene.scene]
	--	local aabb = math3d.aabb()
	--	for _, mn in pairs(scene)	do
	--		local localtrans = mn.transform
	--		for _, g in ipairs(mn) do
	--			local b = g.bounding
	--			if b then
	--				aabb = math3d.aabb_transform(localtrans, math3d.aabb_merge(aabb, b.aabb))
	--			end
	--		end
	--	end
	--	aabb = math3d.aabb_transform(etrans, aabb)
	--	return math3d.aabb_isvalid(aabb) and aabb or nil
	--end
end
