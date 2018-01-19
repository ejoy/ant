local require = import and import(...) or require

local math3d = require "math3d"
local ant = require "lbgfx"

local weak_mode = { __mode = "kv" }
local matcache = setmetatable({}, weak_mode)
local veccache = setmetatable({}, weak_mode)
local matindex = 0
local vecindex = 0
local matgroup = {}
local vecgroup = {}

local M = {}

function M.reset()
	matindex = 0
	vecindex = 0
end

function M.matrix(name, group)
	if name == nil then
		group = matcache
		matindex = matindex + 1
		name = matindex
	else
		group = group or matgroup
	end
	local mat = group[name]
	if mat == nil then
		mat = math3d.matrix()
		group[name] = mat
	end
	return mat
end

function M.vector(name, group)
	if name == nil then
		group = veccache
		vecindex = vecindex + 1
		name = vecindex
	else
		group = group or vecgroup
	end
	local vec = group[name]
	if vec == nil then
		vec = math3d.vector4()
		group[name] = vec
	end
	return vec
end

local mat = {}

function mat:projmat(fov, aspect, near, far, h)
	local ymax = near * math.tan(fov * math.pi / 360)
	local xmax = ymax * aspect
	return self:perspective(-xmax, xmax, -ymax, ymax, near, far, h == nil and ant.caps.homogeneousDepth or h)
end

function mat:orthomat(l,r,t,b,n,f)
	return self:ortho(l,r,t,b,n,f, ant.caps.homogeneousDepth)
end

local eye = math3d.vector3()
local at = math3d.vector3()
function mat:lookatp(ex,ey,ez,ax,ay,az)
	eye:pack(ex,ey,ez)
	at:pack(ax,ay,az)
	return self:lookat(eye,at)
end

local v = math3d.vector3()
function mat:rotmat(x,y,z)
	v:pack(x,y,z):rotmat(self)
	return self
end

function mat:scalemat(x,y,z)
	v:pack(x,y,z):scalemat(self)
	return self
end

function mat:transmat(x,y,z)
	v:pack(x,y,z):transmat(self)
	return self
end

function mat:srt(sx,sy,sz,rx,ry,rz,tx,ty,tz)
	v:pack(sx,sy,sz):scalemat(self)
	return self:rot(rx,ry,rz):trans(tx,ty,tz)
end

-- copy vector3 method to vector4
local vec = {
	"normalize",
	"dot",
	"cross",
	"length",
	"mul",
	"mulH",
}

local function init()
	local mat_meta = debug.getmetatable(math3d.matrix()).__index
	for k,v in pairs(mat) do
		mat_meta[k] = v
	end
	local vec3_meta = debug.getmetatable(math3d.vector3()).__index
	local vec4_meta = debug.getmetatable(math3d.vector4()).__index
	vec4_meta.vec4mul = vec4_meta.mul
	for _,name in ipairs(vec) do
		local method = assert(vec3_meta[name])
		vec4_meta[name] = method
	end
end

init()

return M
