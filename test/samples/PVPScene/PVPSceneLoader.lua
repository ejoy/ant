local math = import_package "ant.math"
local ms = math.stack
local fs = require "filesystem"
local computil = import_package "ant.render".components

local PVPScene = {}

function PVPScene.create_entitices(world)
	local scene_objects = {
		CampsiteDoor = {			
			srt = {{1, 1, 1}, {-90, -90, 0,}, {-12.95, 0.7867187, -14.03104}},
			mesh = fs.path "PVPScene/campsite-door.mesh",
			material = fs.path "PVPScene/scene-mat-shadow.material",
			children = {				
				srts = {
					{
						{},
						{t={124.35, 0.7867187, -14.03104}},
					}
				}
			}
		},		
		CampsiteWall={
			srt = {{1, 1, 1}, {-90, 90, 0,}, {-12.45, 0.7867187, -42.53104}},	
			mesh = fs.path "PVPScene/campsite-wall.mesh",
			material = fs.path "PVPScene/scene-mat-shadow.material",
			children = {				
				srts = {
					{
						{},
						{t={-12.45, 0.7867187, 14.06897}},
						{t={124.85, 0.7867187, -56.8310}},
						{t={124.85, 0.7867187, 28.36897}},
						{t={124.85, 0.7867187, 14.06897}},
						{t={124.85, 0.7867187, -42.5310}},
					}
				}
			}
		},		

		campsite_jianta = {
			srt = {{0.5, 0.5, 0.5}, {-90, 0, 0,}, {7.0, 0.96, -14.03104}},	
			mesh = fs.path "PVPScene/campsite-door-01.mesh",
			material = fs.path "PVPScene/scene-mat-shadow.material",
			children = {				
				srts = {
					{
						{},
						{t={27.0, 0.96, -14.03104}},
						{t={104.4, 0.96, -14.03104}},
						{t={84.4, 0.96, -14.03104}}
					}
				}
			}
		},

		tent = {
			srt = {{1, 1, 1}, {-90, 0, 0,}, {84.4, 0.96, -14.03104}},	
			relate_srts = {
				{{0, 0,0}, {0, 180, 0}, {-21.07, 5.218985, -8.18463}},
				{{0, 0,0}, {0, 0,0 },  {134.72, 5.218985, 17.32593}}
			},
			mesh = fs.path "PVPScene/tent-06.mesh",
			material = fs.path "PVPScene/tent-shadow.material",
			children = {				
				srts = {
					-- relate 1
					{
						{s={0.5, 0.5, 0.5}},	-- use parent
						{r={-90, 90, 0}, t={8.035471, -6.418437, -19.0813}},
						{r={-89.98, 0, 47.621}, t={5.804538, -6.418437, -10.04131}},
						{r={-90.0, 0, 0}, t={4.444535, -6.418437, -1.84131}},
						{r={-90.0, 0, 0}, t = {4.444535, -6.418437, 6.4487}},
						{r={-90.0, -35.40240, 0}, t={-1.835464, -6.418437, 6.368698}},
						{r={-90.0, -91.4971, 0}, t={-10.1, -6.418437, 6.2}},
						{r={-90.0, -91.4971, 0}, t={-18.14546, -6.418437, 5.858704}},
					},
					-- realte 2
					{
						{r={-90.0, 90.0, 0}, t={-10.14546, -6.418437, -19.0813} },
						{r={-90.0, 90.0, 0}, t={-2.935471, -6.418437, -19.0813}},
						{r={-90.0, -91.4971, 0}, t={6.64546, -6.418437, -42.858704}},
						{r={-90.0, -91.4971, 0}, t={14.56548, -6.418437, -42.858704}},
						{r={-89.98, 0.0, 47.621}, t={-10.104538, -6.418437, -28.54131}},
						{r={-90, -35.4024, 0}, t={-1.835464, -6.418437, -44.368698}},
						{r={-90, 0.0, 0}, t={-9.944534, -6.418437, -43.341309}},
						{r={-90, 0.0, 0}, t={-9.944534, -6.418437, -36.9487}},
					},
				},
			}
		},
		wood_build_eid = {
			srt = {	{1, 1, 1},	{-90, -90.7483, 0},  { 30.41463, 1.72, 7.152405 },},
			mesh = fs.path "PVPScene/woodbuilding-05.mesh",
			material = fs.path "PVPScene/scene-mat-shadow.material",
			children = {				
				srts = {
					{
						{}
					}
				}
			}
		},		
		woodother_46 = {			
			srt = {	{1, 1, 1},	{-90, -108.1401, 0},  { 33.882416, 0.149453, -32.164627 },},
			mesh = fs.path "PVPScene/woodother-46.mesh",
			material = fs.path "PVPScene/scene-mat-shadow.material",
			children = {				
				srts = {
					{
						{},
						{t={115.39, 0.149453, -27.164627}},
					},
				}
			}
		},
		woodother_45 = {
			srt = {{1, 1, 1}, {-90, 50.3198, 0},{-28.68, 2, -10.164627},},
			mesh = fs.path "PVPScene/woodother-45.mesh",
			material = fs.path "PVPScene/scene-mat-shadow.material",
			children = {				
				srts = {
					{
						{}
					}
				}
			}
		},
		woodother = {
			srt = {{1, 1, 1}, {-90, 0, 20}, {120, -1.741485, 34.06}},
			relate_srt = {{0, 0,0 }, {0, 0, 0}, {-2.1949, 1.842032, -39.867749}},
			mesh = fs.path "PVPScene/woodother-34.mesh",
			material = fs.path "PVPScene/scene-mat-shadow.material",
			children = {				
				srts = {
					{
						{},
						{r={-90, 0, 0}, t={116, -1.741485, 36.06}},
						{r={-90, 0, 20}, t={102.1759, -1.741485, 36.53}},
						{r={-90, 0, 0}, t={98.1759, -1.741485, 36.08}},
						{r={-90, -60, 0}, t={132.85, -1.741485, 33.62238}},
					}
				}
			}
		}
	}

	for name, scenedata in pairs(scene_objects) do
		local children = assert(scenedata.children)		
		local srts = assert(children.srts)
	
		local nameidx = 1
		for idx_array=1, #srts do			
			local srt_array = srts[idx_array]			
			for idx=1, #srt_array do
				local name = name .. "_" .. nameidx
				nameidx = nameidx + 1
				local srt = srt_array[idx]

				local eid = world:new_entity("scale", "rotation", "position",
				"can_render", "mesh", "material",
				"name")
				local e = world[eid]

				local s = srt.s or scenedata.srt[1]
				local r = srt.r or scenedata.srt[2]
				local t = srt.t or scenedata.srt[3]

				local rsrt = scenedata.relate_srts and scenedata.relate_srts[idx_array] or nil
				if rsrt then
					s = ms(s, rsrt[1], "+P")
					r = ms(r, rsrt[2], "+P")
					t = ms(t, rsrt[3], "+P")
				end

				ms(e.scale, s, "=")
				ms(e.rotation, r, "=")
				ms(e.position, t, "=")

				e.name = name

				computil.load_mesh(e.mesh, scenedata.mesh)
				computil.load_material(e.material, {scenedata.material})
			end
		end

	end
end

return PVPScene