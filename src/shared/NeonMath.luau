local M = {}
function M.clamp(value: number, low: number, high: number): number
	if value < low then return low elseif value > high then return high else return value end
end
function M.magnitude2D(x: number, z: number): number
	return math.sqrt(x * x + z * z)
end
function M.distance2D(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end
function M.directionTo(from: Vector3, to: Vector3): Vector3
	local dx = to.X - from.X
	local dz = to.Z - from.Z
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 0.001 then return Vector3.zero end
	return Vector3.new(dx / len, 0, dz / len)
end
function M.randomEdgePoint(halfSize: number): Vector3
	local side = math.random(1, 4)
	local along = math.random(-halfSize, halfSize) + math.random()
	if side == 1 then return Vector3.new(along, 0, -halfSize)
	elseif side == 2 then return Vector3.new(along, 0, halfSize)
	elseif side == 3 then return Vector3.new(-halfSize, 0, along)
	else return Vector3.new(halfSize, 0, along) end
end
return M
