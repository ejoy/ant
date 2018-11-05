--[[
    make_line(line_beg,line_end,color)
    make_cylinder(radius,height,slices,stacks,color)
    make_cone(base,height,slices,stacks,color)
    make_cube(color)
    make_plane(color)
]]

local geometry={}

local function make_circle_table(sint,cost,n,halfCircle)
    local size=math.abs(n)
    local angle
    if halfCircle==true then
        if n==0 then
            angle=math.pi
        else
            angle=math.pi/n
        end
    else
        if n==0 then
            angle=2*math.pi
        else
            angle=2*math.pi/n
        end
    end

    sint[1]=0
    cost[1]=1

    for i=2,size do
        sint[i]=math.sin(angle*(i-1))
        cost[i]=math.cos(angle*(i-1))
    end

    if halfCircle then
        sint[size+1]=0
        cost[size+1]=-1
    else
        sint[size+1]=sint[1]
        cost[size+1]=cost[1]
    end
end

function geometry.make_line(line_beg,line_end,color)
    local info={}
    local x1,y1,z1=line_beg.x,line_beg.y,line_beg.z
    local x2,y2,z2=line_end.x,line_end.y,line_end.z
    local vertices={
        "fffd",
        x1,y1,z1,color,
        x2,y2,z2,color,
    }
    local indices={
        0,1
    }
    info.line_beg=line_beg
    info.line_end=line_end
    info.color=color
    info.vertices=vertices
    info.vertex_count=2
    info.indices=indices
    info.index_count=2
    return info
end

function geometry.make_sphere(radius,slices,stacks,color)
    local info={}
    local vertices={}
    local indices={}
    local vertex_count,index_count
    if slices==0 or stacks<2 then
        return
    end
    vertex_count=slices*(stacks-1)+2

    local sint1={}
    local cost1={}
    local sint2={}
    local cost2={}

    make_circle_table(sint1,cost1,-slices,false)
    make_circle_table(sint2,cost2,stacks,true)

    local base=1
    vertices[base]="ffffffd"

    vertices[base+1]=0.0
    vertices[base+2]=0.0
    vertices[base+3]=radius
    vertices[base+4]=0.0
    vertices[base+5]=0.0
    vertices[base+6]=20.0
    vertices[base+7]=color

    local idx=8

    for i=2,stacks do
        for j=1,slices do
            local x = cost1[j]*sint2[i]
            local y = sint1[j]*sint2[i]
            local z = cost2[i]

            vertices[base+idx]=x*radius
            vertices[base+idx+1]=y*radius
            vertices[base+idx+2]=z*radius
            vertices[base+idx+3]=x
            vertices[base+idx+4]=y
            vertices[base+idx+5]=z
            vertices[base+idx+6]=color
            idx=idx+7
        end
    end

    vertices[base+idx]=0
    vertices[base+idx+1]=0
    vertices[base+idx+2]=-radius
    vertices[base+idx+3]=0.0
    vertices[base+idx+4]=0.0
    vertices[base+idx+5]=1.0
    vertices[base+idx+6]=color

    local j=1
    idx=1

    while j<=slices do
        indices[idx]=j
        indices[idx+1]=0
        idx=idx+2
        j=j+1
    end
    indices[idx]=1
    indices[idx+1]=0
    idx=idx+2

    local offset

    for i=0,stacks-3 do
        offset=1+i*slices
        for j=0,slices-1 do
            indices[idx]=offset+j+slices
            indices[idx+1]=offset+j
            idx=idx+2
        end
        indices[idx]=offset+slices
        indices[idx+1]=offset
        idx=idx+2
    end

    offset=1+(stacks-2)*slices
    for j=0,slices-1 do
        indices[idx]=vertex_count-1
        indices[idx+1]=offset+j
        idx=idx+2
    end

    indices[idx]=vertex_count-1
    indices[idx+1]=offset

    index_count=idx+1

    info.radius=radius
    info.slices=slices
    info.stacks=stacks
    info.color=color
    info.vertices=vertices
    info.indices=indices
    info.vertex_count=vertex_count
    info.index_count=index_count

    return info
end

function geometry.make_cylinder(radius, height, slices, stacks, color)
    local info={}
    local vertices={}
    local indices={}
	local index_count,vertex_count
	
	slices = slices > 1 and slices or 2
	stacks = stacks > 0 and stacks or 1

    local idx

    local radf=radius
	local zStep = height/stacks

    vertex_count=slices*(stacks+3)+2

    if vertex_count>65535 then
        error("Cylinder:tool many slices or stacks requested,indices will wrap!")
    end

    local sint={}
    local cost={}

    make_circle_table(sint, cost, -slices, false)

    z=0
    vertices[1]="ffffffd"
    vertices[2]=0.0
    vertices[3]=0.0
    vertices[4]=0.0
    vertices[5]=0.0
    vertices[6]=0.0
    vertices[7]=-1.0
    vertices[8]=color

    idx=9
    for j=1,slices do
        vertices[idx]=cost[j]*radf
        vertices[idx+1]=sint[j]*radf
        vertices[idx+2]=z
        vertices[idx+3]=0.0
        vertices[idx+4]=0.0
        vertices[idx+5]=-1.0
        vertices[idx+6]=color
        idx=idx+7
    end

    for i=1,stacks+1 do
        for j=1,slices do
            vertices[idx]=cost[j]*radf
            vertices[idx+1]=sint[j]*radf
            vertices[idx+2]=z
            vertices[idx+3]=cost[j]
            vertices[idx+4]=sint[j]
            vertices[idx+5]=0.0
            vertices[idx+6]=color
            idx=idx+7
        end
        z=z+zStep
    end

    z=z-zStep

    for j=1,slices do
        vertices[idx]=cost[j]*radf
        vertices[idx+1]=sint[j]*radf
        vertices[idx+2]=z
        vertices[idx+3]=0.0
        vertices[idx+4]=0.0
        vertices[idx+5]=1.0
        vertices[idx+6]=color
        idx=idx+7
    end

    vertices[idx]=0.0
    vertices[idx+1]=0.0
    vertices[idx+2]=height
    vertices[idx+3]=0.0
    vertices[idx+4]=0.0
    vertices[idx+5]=1.0
    vertices[idx+6]=color

    idx=1
    for j=0,slices-1 do
        indices[idx]=0
        indices[idx+1]=j+1
        idx=idx+2
    end

    indices[idx]=0
    indices[idx+1]=1
    idx=idx+2

    local offset

    for i=0,stacks-1 do
        offset=1+(i+1)*slices
        for j=0,slices-1 do
            indices[idx]=offset+j
            indices[idx+1]=offset+j+slices
            idx=idx+2
        end
        indices[idx]=offset
        indices[idx+1]=offset+slices
        idx=idx+2
    end

    offset=1+(stacks+2)*slices
    for j=0,slices-1 do
        indices[idx]=offset+j
        indices[idx+1]=vertex_count-1
        idx=idx+2
    end
    indices[idx]=offset
    indices[idx+1]=vertex_count-1

    index_count=idx+1

    info.radius=radius
    info.height=height
    info.slices=slices
    info.stacks=stacks
    info.color=color
    info.vertices=vertices
	info.indices=indices	
    info.vertex_count=vertex_count
    info.index_count=index_count

    return info
end

local function add_vertex(vertices, ...)
	local num = select('#', ...)
	assert(num == 7)
	for i=1, num do
		table.insert(vertices, select(i, ...))
	end
end

function geometry.make_cone(base,height,slices,stacks,color)
	slices = slices > 1 and slices or 2
	stacks = stacks > 0 and stacks or 1
	
    local vertices={}
	local indices={}
	
    local z = 0
    local r = base
	
    local cosn=(height/math.sqrt(height*height+base*base))
    local sinn=(base/math.sqrt(height*height+base*base))

    local vertex_count = slices * (stacks+2)+1

    if vertex_count > 65535 then
        error("too many slices or stacks requested,indices will wrap!")
    end

    local sint={}
    local cost={}
    make_circle_table(sint, cost, -slices, false)

	table.insert(vertices, "ffffffd")

	add_vertex(vertices, 0, 0, z, 0, 0, -1, color)

	for j=1,slices do
		add_vertex(vertices, cost[j]*r, sint[j]*r, z, 0, 0, -1, color)        
    end

	local zStep = height/stacks
	local rStep = base/stacks
    for i=0,stacks do
		for j=1,slices do
			add_vertex(vertices, cost[j]*r, sint[j]*r, z, cost[j]*cosn, sint[j]*cosn, sinn, color)            
        end
        z = z + zStep
        r = r - rStep
    end

	-- indices
	local function add_index_pairs(p1, p2)
		table.insert(indices, p1)
		table.insert(indices, p2)        
	end

	for j=0,slices-1 do
		add_index_pairs(0, j+1)
    end

	add_index_pairs(0, 1)    

    for i=0,stacks-1 do
        local offset = 1+(i+1)*slices
		for j=0,slices-1 do
			local b = offset+j
			add_index_pairs(b, b+slices)            
		end
		
		add_index_pairs(offset, offset+slices)        
	end
	
    local index_count=(slices+1)*2*(stacks+1)

    return {
		base=base,
		height=height,
		slices=slices,
		stacks=stacks,
		color=color,
		vertices=vertices,
		indices=indices,
		vertex_count=vertex_count,
		index_count=index_count,
	}
end

function geometry.make_cube(color)
	local vertices = {
		"ffffffd",
		--top
		-0.5, 0.5, -0.5, 
		0, 1, 0, 
		color,

		-0.5, 0.5, 0.5, 
		0.0, 1.0, 0.0, 
		color,

		0.5, 0.5, -0.5,
		0.0, 1.0, 0.0,
		color,

		0.5, 0.5, 0.5,
		0.0, 1.0, 0.0,
		color,

		--bottom    
		0.5, -0.5, -0.5,
		0.0, -1.0, 0.0,
		color,

		0.5, -0.5, 0.5,
		0.0, -1.0, 0.0,
		color,

		-0.5, -0.5, -0.5,
		0.0, -1.0, 0.0,
		color,

		-0.5, -0.5, 0.5,
		0.0, -1.0, 0.0,
		color,

		--left
		-0.5, 0.5, -0.5,
		-1.0, 0.0, 0.0,
		color,

		-0.5, -0.5, -0.5,
		-1.0, 0.0, 0.0,
		color,

		-0.5, 0.5, 0.5,
		-1.0, 0.0, 0.0,
		color,

		-0.5, -0.5, 0.5,
		-1.0, 0.0, 0.0,
		color,

		--right
		0.5, 0.5, 0.5,
		1.0, 0.0, 0.0,
		color,

		0.5, -0.5, 0.5,
		1.0, 0.0, 0.0,
		color,

		0.5, 0.5, -0.5,
		1.0, 0.0, 0.0,
		color,

		0.5, -0.5, -0.5,
		1.0, 0.0, 0.0,
		color,

		--front
		-0.5, 0.5, 0.5,
		0.0, 0.0, 1.0,
		color,

		-0.5, -0.5, 0.5,
		0.0, 0.0, 1.0,
		color,

		0.5, 0.5, 0.5,
		0.0, 0.0, 1.0,
		color,

		0.5, -0.5, 0.5,
		0.0, 0.0, 1.0,
		color,

		--back
		0.5, 0.5, -0.5,
		0.0, 0.0, -1.0,
		color,

		0.5, -0.5, -0.5,
		0.0, 0.0, -1.0,
		color,

		-0.5, 0.5, -0.5,
		0.0, 0.0, -1.0,
		color,

		-0.5, -0.5, -0.5,
		0.0, 0.0, -1.0,
		color,
	}
	 
	local indices = {}
    for i=0,23 do
        indices[i+1]=i
    end
    return {
		color=color,
		vertices=vertices,
		indices=indices,
		vertex_count=24,
		index_count=24
	}
end

function geometry.make_plane(color)
    local info={}
    local vertices={}
    local indices={}
    local base=1
    vertices[base]="ffffffd"
    vertices[base+1]=-0.5
    vertices[base+2]=0.5
    vertices[base+3]=0.0
    vertices[base+4]=0.0
    vertices[base+5]=0.0
    vertices[base+6]=1.0
    vertices[base+7]=color

    base=base+8
    vertices[base]=-0.5
    vertices[base+1]=-0.5
    vertices[base+2]=0.0
    vertices[base+3]=0.0
    vertices[base+4]=0.0
    vertices[base+5]=1.0
    vertices[base+6]=color

    base=base+7
    vertices[base]=0.5
    vertices[base+1]=0.5
    vertices[base+2]=0.0
    vertices[base+3]=0.0
    vertices[base+4]=0.0
    vertices[base+5]=1.0
    vertices[base+6]=color

    base=base+7
    vertices[base]=0.5
    vertices[base+1]=-0.5
    vertices[base+2]=0.0
    vertices[base+3]=0.0
    vertices[base+4]=0.0
    vertices[base+5]=1.0
    vertices[base+6]=color

    indices[1]=0
    indices[2]=1
    indices[3]=2
    indices[4]=3

    info.color=color
    info.vertices=vertices
    info.indices=indices
    info.vertex_count=4
    info.index_count=4

    return info
end

print("=========================================")
--test line
print("test line:")
local info=geometry.make_line({x=0,y=0,z=0},{x=1,y=1,z=1},0xff)
for k,v in pairs(info) do
    print(k,v)
end
print("=========================================")
--test sphere
print("test sphere:")
info=geometry.make_sphere(2,10,10,0xff)
for k,v in pairs(info) do
    print(k,v)
end
print("=========================================")
--test cylinder
print("test cylinder:")
info=geometry.make_cylinder(2,5,10,10,0xff)
for k,v in pairs(info) do
    print(k,v)
end
print("=========================================")
--test cone
print("test cone:")
info=geometry.make_cone(2,5,10,10,0xff)
for k,v in pairs(info) do
    print(k,v)
end
print("=========================================")
--test cube
print("test cube:")
info=geometry.make_cube(0xff)
for k,v in pairs(info) do
    print(k,v)
end
print("=========================================")
--test plane
info=geometry.make_plane(0xff)
for k,v in pairs(info) do
    print(k,v)
end

return geometry
