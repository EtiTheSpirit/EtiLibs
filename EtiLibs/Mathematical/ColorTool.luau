local ColorModule = {}

local math = require(game:GetService("ReplicatedStorage").EtiLibs.Extension.Math)

function ColorModule.PowVec3(vec3: Vector3, pow: number): Vector3
	return Vector3.new(
		math.pow(vec3.X, pow),
		math.pow(vec3.Y, pow),
		math.pow(vec3.Z, pow)
	)
end

function ColorModule.PowColor3(color: Color3, pow: number): Color3
	return Color3.new(
		math.pow(color.r, pow),
		math.pow(color.g, pow),
		math.pow(color.b, pow)
	)
end

function ColorModule.Color3ToVector3(color: Color3): Vector3
	return Vector3.new(color.r, color.g, color.b)
end

function ColorModule.Vector3ToColor3(vec3: Vector3): Color3
	return Color3.new(vec3.X, vec3.Y, vec3.Z)
end

-- Interpolates from colorA to colorB, optionally applying the given gamma value.
function ColorModule.LerpColor(colorA: Color3, colorB: Color3, frac: number, gamma: number?): Color3
	local gamma = gamma or 2.0

	local clrA = ColorModule.PowColor3(colorA, gamma)
	local clrB = ColorModule.PowColor3(colorB, gamma)
	return ColorModule.PowColor3(clrA:lerp(clrB, frac), 1/gamma)
end

-- Makes a color grayscale with the optional gamma value.
function ColorModule.GetGrayscale(color: Color3, gamma: number?): Color3
	local gamma = gamma or 2.0
	local color = ColorModule.PowColor3(color, gamma)
	local r,g,b = color.r, color.g, color.b
	return math.pow((r+g+b)/3, 1/gamma)
end

-- Interpolates along the one or more colors of a ColorSequence.
function ColorModule.LerpColorSequence(sequence: ColorSequence, frac: number, gamma: number?): Color3
	local keypoints: {ColorSequenceKeypoint} = sequence.Keypoints
	if frac <= 0 then
		return keypoints[1].Value
	elseif frac >= 1 then
		return keypoints[#keypoints].Value
	end
	local keypointBefore: ColorSequenceKeypoint
	local keypointAfter: ColorSequenceKeypoint
	for index = 1, #keypoints do
		local keypoint = keypoints[index]
		if keypoint.Time <= frac then
			keypointBefore = keypoint
			keypointAfter = keypoints[index + 1]
			break
		end
	end
	
	if not keypointBefore or not keypointAfter then
		error("Critical failure when trying to interpolate ColorSequence (missing keypoints around fraction).")
	end
	
	local mappedFrac = math.mapto01(frac, keypointBefore.Time, keypointAfter.Time)
	-- ^ Fraction is some value relative to the entire sequence, not these two keypoints
	-- The function there maps a value in the range [min, max] to the range [0, 1]
	return ColorModule.LerpColor(keypointBefore.Value, keypointAfter.Value, mappedFrac, gamma)
end

local function RoundThenClamp(value: number, min: number, max: number)
	return math.clamp(math.round(value), min, max)
end

function ColorModule.RoundToWholeRGBV3(color: Color3): Vector3
	return Vector3.new(
		RoundThenClamp(color.R * 255, 0, 255),
		RoundThenClamp(color.G * 255, 0, 255),
		RoundThenClamp(color.B * 255, 0, 255)
	)
end

-----------------------------------------------------
-- COLOR COMPARISONS
-- Derived from ColorMine // https://github.com/colormine/colormine
local Epsilon = 0.008856; 	-- Intent is 216/24389
local Kappa = 903.3; 		-- Intent is 24389/27
local XYZColorSpaceWhite = {
	X =  95.047;
	Y = 100.000;
	Z = 108.883;
}

local function PivotRGB(n)
	return (n > 0.04045 and math.pow((n + 0.055) / 1.055, 2.4) or n / 12.92) * 100.0; 
end


local function ToColorSpace(clr: Color3)
	local r = PivotRGB(clr.r)
	local b = PivotRGB(clr.g)
	local g = PivotRGB(clr.b)

	local item = {}
	item.X = r * 0.4124 + g * 0.3576 + b * 0.1805;
	item.Y = r * 0.2126 + g * 0.7152 + b * 0.0722;
	item.Z = r * 0.0193 + g * 0.1192 + b * 0.9505;
	return item
end

local function PivotXYZ(n)
	return n > Epsilon and math.pow(n, 0.333) or (Kappa * n + 16) / 116;
end

local function CompareLAB(lab1, lab2)
	local k_L = 1
	local k_C = 1
	local k_H = 1

	-- Calculate Cprime1, Cprime2, Cabbar
	local c_star_1_ab = math.sqrt(lab1.A * lab1.A + lab1.B * lab1.B);
	local c_star_2_ab = math.sqrt(lab2.A * lab2.A + lab2.B * lab2.B);
	local c_star_average_ab = (c_star_1_ab + c_star_2_ab) / 2;

	local c_star_average_ab_pot7 = c_star_average_ab * c_star_average_ab * c_star_average_ab;
	c_star_average_ab_pot7 *= c_star_average_ab_pot7 * c_star_average_ab;

	local G = 0.5 * (1 - math.sqrt(c_star_average_ab_pot7 / (c_star_average_ab_pot7 + 6103515625))); -- 25^7
	local a1_prime = (1 + G) * lab1.A;
	local a2_prime = (1 + G) * lab2.A;

	local C_prime_1 = math.sqrt(a1_prime * a1_prime + lab1.B * lab1.B);
	local C_prime_2 = math.sqrt(a2_prime * a2_prime + lab2.B * lab2.B);
	--Angles in Degree.
	local h_prime_1 = ((math.atan2(lab1.B, a1_prime) * 180 / math.pi) + 360) % 360;
	local h_prime_2 = ((math.atan2(lab2.B, a2_prime) * 180 / math.pi) + 360) % 360;

	local delta_L_prime = lab2.L - lab1.L;
	local delta_C_prime = C_prime_2 - C_prime_1;

	local h_bar = math.abs(h_prime_1 - h_prime_2);
	local delta_h_prime;
	if (C_prime_1 * C_prime_2 == 0) then
		delta_h_prime = 0
	else
		if (h_bar <= 180) then
			delta_h_prime = h_prime_2 - h_prime_1;
		elseif (h_bar > 180 and h_prime_2 <= h_prime_1) then
			delta_h_prime = h_prime_2 - h_prime_1 + 360.0;
		else
			delta_h_prime = h_prime_2 - h_prime_1 - 360.0;
		end
	end
	local delta_H_prime = 2 * math.sqrt(C_prime_1 * C_prime_2) * math.sin(delta_h_prime * math.pi / 360);

	-- Calculate CIEDE2000
	local L_prime_average = (lab1.L + lab2.L) / 2;
	local C_prime_average = (C_prime_1 + C_prime_2) / 2;

	--Calculate h_prime_average

	local h_prime_average;
	if (C_prime_1 * C_prime_2 == 0) then
		h_prime_average = 0;
	else
		if (h_bar <= 180) then
			h_prime_average = (h_prime_1 + h_prime_2) / 2;
		elseif (h_bar > 180 and (h_prime_1 + h_prime_2) < 360) then
			h_prime_average = (h_prime_1 + h_prime_2 + 360) / 2;
		else
			h_prime_average = (h_prime_1 + h_prime_2 - 360) / 2;
		end
	end
	local L_prime_average_minus_50_square = (L_prime_average - 50);
	L_prime_average_minus_50_square *= L_prime_average_minus_50_square;

	local S_L = 1 + ((.015 * L_prime_average_minus_50_square) / math.sqrt(20 + L_prime_average_minus_50_square));
	local S_C = 1 + .045 * C_prime_average;
	local T = 1
	- .17 * math.cos(math.rad(h_prime_average - 30))
		+ .24 * math.cos(math.rad(h_prime_average * 2))
		+ .32 * math.cos(math.rad(h_prime_average * 3 + 6))
	- .2 * math.cos(math.rad(h_prime_average * 4 - 63));
	local S_H = 1 + .015 * T * C_prime_average;
	local h_prime_average_minus_275_div_25_square = (h_prime_average - 275) / (25);
	h_prime_average_minus_275_div_25_square *= h_prime_average_minus_275_div_25_square;
	local delta_theta = 30 * math.exp(-h_prime_average_minus_275_div_25_square);

	local C_prime_average_pot_7 = C_prime_average * C_prime_average * C_prime_average;
	C_prime_average_pot_7 *= C_prime_average_pot_7 * C_prime_average;
	local R_C = 2 * math.sqrt(C_prime_average_pot_7 / (C_prime_average_pot_7 + 6103515625));

	local R_T = -math.sin(math.rad(2 * delta_theta)) * R_C;

	local delta_L_prime_div_k_L_S_L = delta_L_prime / (S_L * k_L);
	local delta_C_prime_div_k_C_S_C = delta_C_prime / (S_C * k_C);
	local delta_H_prime_div_k_H_S_H = delta_H_prime / (S_H * k_H);

	local CIEDE2000 = math.sqrt(
		delta_L_prime_div_k_L_S_L * delta_L_prime_div_k_L_S_L
			+ delta_C_prime_div_k_C_S_C * delta_C_prime_div_k_C_S_C
			+ delta_H_prime_div_k_H_S_H * delta_H_prime_div_k_H_S_H
			+ R_T * delta_C_prime_div_k_C_S_C * delta_H_prime_div_k_H_S_H
	);

	return CIEDE2000;
end

function ColorModule.RGBToLAB(rgb: Color3)
	-- Initialize opulated the xyz instance. For me, that's...
	local xyz = ToColorSpace(rgb)

	local white = XYZColorSpaceWhite
	local x = PivotXYZ(xyz.X / white.X)
	local y = PivotXYZ(xyz.Y / white.Y)
	local z = PivotXYZ(xyz.Z / white.Z)

	local item = {}
	item.L = math.max(0, 116 * y - 16);
	item.A = 500 * (x - y);
	item.B = 200 * (y - z);
	return item
end

-- Returns a value from 0 to 1 representing how different the two colors are, where 0 means identical, and 1 means completely different.
function ColorModule.GetDifferenceBetween(color1, color2)
	return CompareLAB(ColorModule.RGBToLAB(color1), ColorModule.RGBToLAB(color2)) / 100
end

-- Takes a value from 0 to 1 and translates into a value from 0 to 255, constraining it within that range.
local function FloatTo8Bit(value: number): number	
	return math.clamp(math.round(value * 255), 0, 255)
end

-- Takes a Color3 and turns it into a hex color #RRGGBB
function ColorModule.ColorToHex(color: Color3, noPreHashtag: boolean): string
	local r = bit32.lshift(FloatTo8Bit(color.R), 16)	-- r << 16
	local g = bit32.lshift(FloatTo8Bit(color.G),  8)	-- g <<  8
	local b = bit32.lshift(FloatTo8Bit(color.B),  0)	-- b <<  0
	local intValue = bit32.bor(r, g, b) 				-- r | g | b
	-- ^ Result: 0x00RRGGBB
	local result = string.format("%X", intValue) -- now just use %X which does number to hex.
	if not noPreHashtag then
		result = "#" .. result
	end
	return result
end

-- Takes an integer value and turns it into a Color3, expecting the integer's bytes to be 0RGB (big endian)
function ColorModule.IntToColor(value: number): Color3
	local r = bit32.rshift(bit32.band(value, 0xFF0000), 16) -- (r & 0xFF0000) >> 16
	local g = bit32.rshift(bit32.band(value, 0x00FF00),  8) -- (g & 0x00FF00) >>  8
	local b = bit32.rshift(bit32.band(value, 0x0000FF),  0) -- (b & 0x0000FF) >>  0
	return Color3.fromRGB(r, g, b)
end

-- Converts a hex string to a color.
function ColorModule.HexToColor(hex: string): Color3
	if hex:sub(1, 1) == "#" then
		if #hex > 1 then
			hex = hex:sub(2)
		else
			error("Unexpected end of string.", 2)
		end
	end
	-- Lua natively supports 0x prefix.
	local value = tonumber(hex, 16)
	if not value then
		error("Malformed hex string.", 2)
	end
	return ColorModule.IntToColor(value)
end


return ColorModule