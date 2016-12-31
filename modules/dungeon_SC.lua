local MAJOR, MINOR = "Module:SC-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local SC = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
SC.null = setmetatable ({}, {
  __toinn = function () return "null" end
})

-----------------------------------------------------------------------------------------------
-- All Bosses
-----------------------------------------------------------------------------------------------

function SC:OnCombat_IN(self, unitInCombat)
end

function SC:OnCombat_OUT(self, unitInCombat)

	if unitInCombat:GetName() == "Stew-Shaman Tugga" then

		function IsTuggaStuffed()
		   local getBossBuffs = unitInCombat:GetBuffs().arBeneficial[1].splEffect:GetName() ~= nil
		end

		if pcall(IsTuggaStuffed) then

			local getBossBuffs = unitInCombat:GetBuffs().arBeneficial[1].splEffect:GetName()

			if getBossBuffs == "Devour Flesh" then

				local sToChat = "Stew-Shaman Tugga ate Devour Flesh during combat. The challenge is lost. Someone from this team can't interrupt at right time. Is that you, slacker?"
				self:AddFails()
				self:InformOthers(sToChat, true, false)
			end
		end
	end
end

function SC:OnCombatLogVitalModifier(self, tEventArgs)

	if self.hlp.boss["Mordechai Redmoon"] then

		function IsTerablinded()
		   local getBossBuffs = tEventArgs.unitTarget:GetBuffs().arHarmful[1].strTooltip ~= nil
		end

		if pcall(IsTerablinded) then

			if tEventArgs.unitTarget:GetBuffs().arHarmful[1].strTooltip == "Blinded!" then

				local getTarget = tEventArgs.unitTarget:GetName()
				local sToChat = string.format("%s was blinded. Mordechai Redmoon's challenge is lost. Remember to always look out to prevent this!", getTarget)

				self:CountFails(getTarget)
				self:InformOthers(sToChat, true, false)

			end
		end
	end

	if self.hlp.boss["Bosun Octog"] then

		function IsBosunBroken()
		   local getBossBuffs = tEventArgs.unitCaster:GetBuffs().arHarmful[1].strTooltip ~= nil
		end

		if pcall(IsBosunBroken) then

			local getBossBuffs = tEventArgs.unitCaster:GetBuffs()
			if getBossBuffs.arHarmful[1].strTooltip == "Broken Armor" then
				self.hlp.OctogStacks = getBossBuffs.arHarmful[1].nCount
			end
		end
	end
end

function SC:OnCombatLogDamage(self, tEventArgs)

	local getSpell = tEventArgs.splCallingSpell:GetName()
	local getCaster = tEventArgs.unitCaster:GetName()
	local getTarget = tEventArgs.unitTarget:GetName()

	if getSpell == "Seismic Tremor" and getCaster == "Thunderfoot" then

		local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Is really that hard to jump?", getTarget, getSpell, getCaster)
		self:CountFails(getTarget)
		self:InformOthers(sToChat, true, false)

	end

	if getSpell == "Dark Fireball" and getCaster == "Laveka the Dark-Hearted" then

		local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Come on, just evade small circular AOE, you are not that bad, are you?", getTarget, getSpell, getCaster)
		self:CountFails(getTarget)
		self:InformOthers(sToChat, true, false)

	end

end

function SC:OnUnitCreated(self, unit)

end

function SC:OnUnitDestroyed(self, unit)
	
end

function SC:OnLoad() end

Apollo.RegisterPackage(SC, MAJOR, MINOR, {})