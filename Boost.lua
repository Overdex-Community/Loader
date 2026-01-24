local L=game:GetService("Lighting")
local H={}

local function s(o,p)
	H[o]=H[o] or {}
	if H[o][p]==nil then H[o][p]=o[p] end
end

local function h(o)
	if o:IsA("BasePart") then
		s(o,"Transparency")
		s(o,"Material")
		o.Transparency=1
		o.Material=Enum.Material.Plastic
	elseif o:IsA("Decal") or o:IsA("Texture") then
		s(o,"Transparency")
		o.Transparency=1
	elseif o:IsA("ParticleEmitter")
		or o:IsA("Trail")
		or o:IsA("Fire")
		or o:IsA("Smoke")
		or o:IsA("Sparkles") then
		s(o,"Enabled")
		o.Enabled=false
	elseif o:IsA("PointLight")
		or o:IsA("SpotLight")
		or o:IsA("SurfaceLight") then
		s(o,"Enabled")
		o.Enabled=false
	end
end

s(L,"GlobalShadows")
s(L,"FogEnd")
s(L,"Brightness")
s(L,"EnvironmentDiffuseScale")
s(L,"EnvironmentSpecularScale")

L.GlobalShadows=false
L.FogEnd=1e9
L.Brightness=0
L.EnvironmentDiffuseScale=0
L.EnvironmentSpecularScale=0

for _,o in ipairs(workspace:GetDescendants()) do
	pcall(h,o)
end

workspace.DescendantAdded:Connect(function(o)
	pcall(h,o)
end)
