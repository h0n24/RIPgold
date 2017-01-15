local MAJOR, MINOR = "Module:PA-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local PA = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
PA.null = setmetatable ({}, {
  __toinn = function () return "null" end
})

-- STATUS: 0% complete

-----------------------------------------------------------------------------------------------
-- All Bosses
-----------------------------------------------------------------------------------------------

function PA:OnPublicEventStatsUpdate(self)
end

function PA:OnCombat_IN(self, unitInCombat)
	if unitInCombat:GetName() == "Invulnotron" then
		GameLib.GetPlayerUnit(1):SetAlternateTarget(self.hlp.unitInvulnotron)
	end

	if unitInCombat:GetName() == "Iruki Boldbeard" then
		GameLib.GetPlayerUnit(1):SetAlternateTarget(self.hlp.unitIruki)
	end
end

function PA:OnCombat_OUT(self, unitInCombat)
	if unitInCombat:GetName() == "Invulnotron" then
		GameLib.GetPlayerUnit(1):SetAlternateTarget(0)
	end

	if unitInCombat:GetName() == "Iruki Boldbeard" then
		GameLib.GetPlayerUnit(1):SetAlternateTarget(0)
	end
end

function PA:OnCombatLogVitalModifier(self, tEventArgs)

end

function PA:OnCombatLogDamage(self, tEventArgs)

end

function PA:OnUnitCreated(self, unit)
	if getUnitName == "Invulnotron" then
		self.hlp.unitInvulnotron = unit
	end
	if getUnitName == "Iruki Boldbeard" then
		self.hlp.unitIruki = unit
	end
end

function PA:OnUnitDestroyed(self, unit)
	
end

function PA:OnLoad() end

Apollo.RegisterPackage(PA, MAJOR, MINOR, {})