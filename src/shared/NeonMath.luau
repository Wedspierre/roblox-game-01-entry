-- NeonMath: the small 2D vector helpers the arena game needs.
-- Everything here is pure: same input, same output, no state.

local NeonMath = {}

function NeonMath.clamp(value: number, low: number, high: number): number
	if value < low then
		return low
	elseif value > high then
		return high
	else
		return value
	end
end

function NeonMath.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Length of a 2D (X, Z) vector, used to normalize move input.
function NeonMath.magnitude2D(x: number, z: number): number
	return math.sqrt(x * x + z * z)
end

-- Distance on the arena floor (XZ plane only; Y is always the floor).
function NeonMath.distance2D(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- A unit XZ direction from `from` toward `to`; (0, 0, 0) when they coincide.
function NeonMath.directionTo(from: Vector3, to: Vector3): Vector3
	local dx = to.X - from.X
	local dz = to.Z - from.Z
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 0.001 then
		return Vector3.zero
	end
	return Vector3.new(dx / len, 0, dz / len)
end

-- A random point inside the arena, at least `margin` studs from the edge.
function NeonMath.randomPointInArena(halfSize: number, margin: number): Vector3
	local span = halfSize - margin
	return Vector3.new(
		math.random(-span, span) + math.random(),
		0,
		math.random(-span, span) + math.random()
	)
end

-- A random point on one of the arena's four edges (where enemies spawn).
function NeonMath.randomEdgePoint(halfSize: number): Vector3
	local side = math.random(1, 4)
	local along = math.random(-halfSize, halfSize) + math.random()
	if side == 1 then
		return Vector3.new(along, 0, -halfSize)
	elseif side == 2 then
		return Vector3.new(along, 0, halfSize)
	elseif side == 3 then
		return Vector3.new(-halfSize, 0, along)
	else
		return Vector3.new(halfSize, 0, along)
	end
end

return NeonMath
