--!strict
-- Simple function that assigns a CFrame attribute to an instance by storing its matrix.
-- Attributes do not natively support the CFrame type (your guess is as good as mine) so this provides a wrapper that writes the entire matrix instead.
local CFrameAttribute = {}

function CFrameAttribute.Put(obj: Instance, name: string, cf: CFrame)
	obj:SetAttribute(name .. "_CFO", cf.Position)
	obj:SetAttribute(name .. "_CFLK", cf.LookVector)
	obj:SetAttribute(name .. "_CFRT", cf.RightVector)
	obj:SetAttribute(name .. "_CFUP", cf.UpVector)
end

function CFrameAttribute.Get(obj: Instance, name: string): CFrame
	local origin = obj:GetAttribute(name .. "_CFO")
	local look = obj:GetAttribute(name .. "_CFLK")
	local right = obj:GetAttribute(name .. "_CFRT")
	local up = obj:GetAttribute(name .. "_CFUP")
	return CFrame.fromMatrix(origin, right, up, look)
end

return CFrameAttribute