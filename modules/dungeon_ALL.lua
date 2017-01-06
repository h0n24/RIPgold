local MAJOR, MINOR = "Module:ALL-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local ALL = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
ALL.null = setmetatable ({}, {
  __toinn = function () return "null" end
})

-----------------------------------------------------------------------------------------------
-- Title
-----------------------------------------------------------------------------------------------

function ALL:OnUnitCreated(self, unit)

end

function ALL:OnUnitDestroyed(self, unit)
	
end

function ALL:OnLoad() end

Apollo.RegisterPackage(ALL, MAJOR, MINOR, {})