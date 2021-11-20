--!strict
-- Physics Utility 
-- Eti 12 November 2021 to --
-- Handles a few common operations needed for physics simulations.
-- Also provides alias methods to create certain constraints using Roblox's newer standards and physics systems.
local PhysicsUtil = {}

local INFINITY = math.huge
local PI = math.pi
local TAU = PI * 2
local HALFPI = PI / 2
local EPSILON = 1e-6

local ZERO_VECTOR = Vector3.new()
local DOWN_VECTOR = Vector3.new(0, -1, 0)
local UP_VECTOR = Vector3.new(0, 1, 0)

-- Makes a linear velocity object that can be used to control the part's velocity.
-- It uses vector velocity by default.
function PhysicsUtil.MakeVelocityController(part: BasePart): LinearVelocity
	local attachment = Instance.new("Attachment")
	attachment.Name = "VelocityController"
	
	local linearVel = Instance.new("LinearVelocity")
	linearVel.MaxForce = 100000
	linearVel.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVel.Parent = attachment
	
	attachment.Parent = part
	return linearVel
end

-- Returns two values, which describe the creature's general radius and height.
-- The radius is calculated from the HumanoidRootPart's X or Z size (whichever is larger)
-- The height is calculated from the height of the entire model.
-- Note that the input model expects the primary part to be set to the root.
function PhysicsUtil.GetCreatureSpecialBounds(creatureModel: Model): (number, number)
	local rootPart: BasePart = creatureModel.PrimaryPart :: BasePart -- TODO: When Luau RFC #whatever gets added, replace with "!" instead of "::BasePart"
	if not rootPart then error("Model does not have a primary part.", 2) end

	local maxXZ: number = math.max(rootPart.Size.X, rootPart.Size.Z)
	local height: number = creatureModel:GetExtentsSize().Y

	return maxXZ / 2, height
end

-- Preconstructs a capsule collider for the given creature model. 
-- This capsule is appropriately scaled, and has a keep-upright constraint in it.
function PhysicsUtil.AddCapsuleColliderToCreature(creature: Model): Model
	local radius, height = PhysicsUtil.GetCreatureSpecialBounds(creature)
	local capsule = PhysicsUtil.MakeCapsuleCollider(radius, height)
	
	local rootCFrame = creature:GetPivot()
	-- Use the fact that Sonaria's root parts are at the feet (on the bottom of the part)
	local feetY = rootCFrame.Y - ((creature.PrimaryPart::BasePart).Size.Y / 2)
	local position = CFrame.new(rootCFrame.X, feetY + (height / 2), rootCFrame.Z)

	capsule:PivotTo(position * CFrame.fromOrientation(rootCFrame:ToOrientation()) * CFrame.fromOrientation(0, 0, math.pi / 2))
	local weld = PhysicsUtil.Weld(creature.PrimaryPart::BasePart, capsule.PrimaryPart::BasePart)
	weld.Name = "CapsuleConnector"
	
	capsule.Parent = creature
	return capsule
end

-- Creates a force that can be used to keep an object's local Y axis parallel to the world space Y axis.
-- This has the ability to use infinite force, granted rigidy is left enabled.
-- Can optionally be made non-rigid, which may have negative side effects (it's not advised)
function PhysicsUtil.MakeKeepUpright(part: BasePart, disableRigidity: boolean?): AlignOrientation
	local a0 = Instance.new("Attachment")
	local constraint = Instance.new("AlignOrientation")
	a0.Name = "KeepUprightAttachment"
	
	constraint.Name = "KeepUpright"
	constraint.RigidityEnabled = not disableRigidity
	constraint.MaxAngularVelocity = 3000
	constraint.ReactionTorqueEnabled = false
	
	-- Below: Configure the alignment such that it needs only one reference attachment, which allows it to use alignment types.
	constraint.Mode = Enum.OrientationAlignmentMode.OneAttachment
	constraint.PrimaryAxis = Vector3.new(0, 1, 0)
	constraint.PrimaryAxisOnly = true
	constraint.AlignType = Enum.AlignType.Parallel -- Parallel to the primary axis.
	
	constraint.Attachment0 = a0
	constraint.Parent = a0
	a0.Parent = part
	return constraint
end

-- Creates a new AlignOrientation that only affects rotation on the world-space Y axis. Intended to be used with a KeepUpright setup.
-- Attachment1 is unset.
function PhysicsUtil.MakeYawController(part: BasePart): AlignOrientation
	local a0 = Instance.new("Attachment")
	local constraint = Instance.new("AlignOrientation")
	a0.Name = "YawControllerAttachment"

	constraint.Name = "YawController"
	constraint.RigidityEnabled = false
	constraint.MaxTorque = 35000
	constraint.MaxAngularVelocity = 100
	constraint.ReactionTorqueEnabled = false
	constraint.Responsiveness = 300

	-- Below: Configure the alignment such that it needs only one reference attachment, which allows it to use alignment types.
	constraint.Mode = Enum.OrientationAlignmentMode.TwoAttachment
	constraint.PrimaryAxis = Vector3.new(0, 1, 0)
	constraint.PrimaryAxisOnly = true
	constraint.AlignType = Enum.AlignType.Parallel -- Parallel to the primary axis.

	constraint.Attachment0 = a0
	constraint.Parent = a0
	a0.Parent = part
	return constraint
end

-- Creates a WeldConstraint, manually emulating legacy Weld's C0 and C1 properties.
-- This will CFrame part1 based on part0's CFrame coupled with C0/C1, like what original welds do.
-- By default, the constraint is parented to part0, but it is returned for ease of access.
-- Optionally, the parent parameter can be declared to change its parent.
function PhysicsUtil.Weld(part0: BasePart, part1: BasePart, C0: CFrame?, C1: CFrame?, parent: Instance?): WeldConstraint
	if not C0 then C0 = CFrame.new() end
	if not C1 then C1 = CFrame.new() end
	local C0 = C0::CFrame
	local C1 = C1::CFrame
	
	part1.CFrame = part0.CFrame * C0 * C1:Inverse()
	
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = parent or part0
	
	return constraint
end

-- Makes a capsule collider with the given radius and height. This uses three parts welded together so that the physics engine handles them
-- as one solid assembly.
-- The radius and height are measured by the complete size of the entire assembly.
-- If the resulting height is zero, then a single sphere is returned.
-- An input height less than the diameter (input radius * 2) will be clamped upwards so that the height results in a sphere.
-- Optionally, a CFrame parameter can be specified, which moves the capsule to the given CFrame.
function PhysicsUtil.MakeCapsuleCollider(radius: number, height: number, cf: CFrame?): Model
	local mdl = Instance.new("Model")
	mdl.Name = "Capsule"

	local diameter = radius * 2
	local resultingCylinderSize = height - diameter 

	if resultingCylinderSize <= 0 then
		-- This is kind of a strange situation because the height is shorter than physically possible for a capsule.
		-- The minimum possible size is a sphere with the given radius, kind of like how a circle can be described as a cylinder with 0 height.
		-- A capsule with 0 height is just a sphere.
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(radius, radius, radius)
		ball.Transparency = 1
		ball.TopSurface = Enum.SurfaceType.Smooth
		ball.BottomSurface = Enum.SurfaceType.Smooth
		ball.Parent = mdl
		mdl.PrimaryPart = ball
		return mdl
	end

	local ball0 = Instance.new("Part")
	local ball1 = Instance.new("Part")
	local cylinder = Instance.new("Part")
	
	ball0.Name = "SpherePositive" -- Cylinders are around the X axis. This one is move by positive X height/2
	ball1.Name = "SphereNegative" -- Opposite of ^
	cylinder.Name = "Cylinder" -- What, was I supposed to name it "Shaft"?

	ball0.TopSurface = Enum.SurfaceType.Smooth
	ball0.BottomSurface = Enum.SurfaceType.Smooth
	ball1.TopSurface = Enum.SurfaceType.Smooth
	ball1.BottomSurface = Enum.SurfaceType.Smooth
	cylinder.TopSurface = Enum.SurfaceType.Smooth
	cylinder.BottomSurface = Enum.SurfaceType.Smooth
	
	-- Note to future programmers:
	-- I don't know if anyone will actually want to do this, but if you're thinking "Oh, why not just make a pill mesh and use that?"
	-- It's because Roblox's ball and cylinder part types use legitimate real-deal radial collision
	-- In other words, a roblox sphere might not *look* very highpoly, but as far as the physics engine is concerned, it's a *perfect* sphere.
	-- Mesh collision won't be able to replicate that and you not only introduce added complexity because now it's gotta calculate triangle collision,
	-- and as an added bonus, you also make the collisions less accurate. So don't actually do it.
	-- Yes, these 3 parts is more performant than a mesh. Stop asking.
	ball0.Shape = Enum.PartType.Ball
	ball1.Shape = Enum.PartType.Ball
	cylinder.Shape = Enum.PartType.Cylinder

	ball0.Size = Vector3.new(diameter, diameter, diameter)
	ball1.Size = ball0.Size
	cylinder.Size = Vector3.new(resultingCylinderSize, diameter, diameter)

	ball0.RootPriority = -127
	ball1.RootPriority = -127
	cylinder.RootPriority = 63

	ball0.Transparency = 1
	ball1.Transparency = 1
	cylinder.Transparency = 1

	ball0.CFrame = CFrame.new(resultingCylinderSize / 2, 0, 0)
	ball1.CFrame = CFrame.new(-resultingCylinderSize / 2, 0, 0)

	local weld0 = Instance.new("WeldConstraint")
	local weld1 = Instance.new("WeldConstraint")
	weld0.Name = "Ball0Weld"
	weld1.Name = "Ball1Weld"

	ball0.Parent = cylinder
	ball1.Parent = cylinder

	weld0.Part0 = cylinder
	weld0.Part1 = ball0

	weld1.Part0 = cylinder
	weld1.Part1 = ball1

	weld0.Parent = cylinder
	weld1.Parent = cylinder

	cylinder.Parent = mdl
	mdl.PrimaryPart = cylinder
	
	-- So it's known: This is being done down here with two major intents in mind:
	-- #1: Creating parts as close to the origin as possible = best accuracy due to float inaccuracy
	-- #2: PivotTo caches these original (accurate) positions so that future PivotTo calls don't get messed up.
	if cf then
		mdl:PivotTo(cf)
	end
	
	return mdl
end

-- Intended to check the lower half of a sphere for collision, specifically for use in seeing if a capsule collider is on the ground.
function PhysicsUtil.CheckCapsuleGroundCollision(at: Vector3, radius: number, facesAround: number, levelsDown: number, params: RaycastParams?, worldRoot: WorldRoot?)
	local worldRoot = worldRoot or workspace
	-- Start by casting straight down
	local cast = worldRoot:Raycast(at, Vector3.new(0, -radius, 0), params)
	if cast then
		return true
	end
	for x = 2, levelsDown + 1 do
		for y = 1, facesAround + 1 do
			-- Below: Offset levelsDown to avoid a redundant (facesAround) casts all going straight down.
			-- Also offset it by starting at 2, which prevents horizontal checks.
			local angle = CFrame.fromOrientation(-(x / (levelsDown + 2)) * HALFPI, ((y - 1) / facesAround) * TAU, 0)
			if worldRoot:Raycast(at, angle.LookVector * radius, params) then
				return true
			end
		end
	end
	return false
end

-- A very niche function that checks stairstep collision, that is, if the surface in front of the given feetPos (front defined by direction)
-- is hit by a short ray, and an equal raycast slightly further out (how much further depends on the max slope angle) and raised to the hips
-- does NOT hit anything, then it returns true and an nullable "slope factor" with the intent of the character adding to their Y velocity to automatically
-- step up the stair or slope.
function PhysicsUtil.CheckStairstepCollision(feetPos: Vector3, radius: number, maxStepHeight: number, direction: Vector3, castDivisions: number, arcRangeRadians: number, maxSlopeAngleRadians: number, params: RaycastParams?, worldRoot: WorldRoot?): (boolean, number?)
	local worldRoot = worldRoot or workspace
	
	local cap = castDivisions - 1

	-- MaxSlopeAngle
	-- Forward factor is sin(MaxSlopeAngle)
	-- height is constant (hips.Y - feet.Y)
	-- sin(angle) gives me the height local to 1
	-- create a vector from the height at sin(angle)
	-- find what this vector's x component (if it's 2D) is when y intersects 1
	local unitHeight = math.sin(maxSlopeAngleRadians)
	local unitLength = math.cos(maxSlopeAngleRadians)
	local scaledUnitHeight = 1 / unitHeight
	local distance = scaledUnitHeight * unitLength * maxStepHeight

	-- Check hips first. If hips hit, then it's completely useless to check feet
	local hipPos = feetPos + Vector3.new(0, maxStepHeight, 0)
	local baseDirHips = CFrame.lookAt(hipPos, hipPos + direction)
	local baseDirFeet = CFrame.lookAt(feetPos, feetPos + direction)
	for i = 0, cap do
		local progress = i / cap
		local angle = (arcRangeRadians * progress) - (arcRangeRadians / 2)
		local target = (baseDirHips * CFrame.fromOrientation(0, angle, 0)).LookVector * radius + (baseDirHips.LookVector * distance)
		if worldRoot:Raycast(hipPos, target, params) then
			return false, nil
		end
	end

	for i = 0, cap do
		local progress = i / cap
		local angle = (arcRangeRadians * progress) - (arcRangeRadians / 2)
		local target = (baseDirFeet * CFrame.fromOrientation(0, angle, 0)).LookVector * radius
		local cast =  worldRoot:Raycast(feetPos, target, params)

		if cast then
			local factor = cast.Normal:Dot(UP_VECTOR)
			return true, factor
		end
	end

	return false, nil
end

table.freeze(PhysicsUtil) -- no
return PhysicsUtil