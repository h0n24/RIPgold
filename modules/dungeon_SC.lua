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

function SC:OnPublicEventStatsUpdate(self)
	if self.hlp.boss["Mordechai Redmoon"] then
		if self.hlp.event["Like Starin' at the Sun"] == 0 then
			local actualGametime = GameLib.GetGameTime()

			if self.hlp.lastTimeMordechaiChallengeStatus == nil then
				self.hlp.lastTimeMordechaiChallengeStatus = GameLib.GetGameTime()
			end

			local difference = actualGametime - self.hlp.lastTimeMordechaiChallengeStatus - 5 -- 5 second treshold in case someone gets blinded

			if self.hlp.lastTimeMordechaiChallengeStatus > 0 then
				local sToChatMin = "Mordechai wasn't blinded."
				self:AddTooltips(sToChatMin)

				local sToChat = string.format("Mordechai Redmoon wasn't blinded by Terraformer. When it says Terraformer Overcharging, you should tank him facing to middle.")
				self:InformOthers(sToChat, true, false)
			end
		end
	end
end

function SC:OnCombat_IN(self, unitInCombat)
	if unitInCombat:GetName() == "Mordechai Redmoon" then
		self.hlp.BlindedLastGametime = nil
		self.hlp.lastTimeMordechaiChallengeStatus = GameLib.GetGameTime()
	end
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

				local sToChatMin = "Stew-Shaman Tugga ate Devour Flesh during combat."
				self:AddTooltips(sToChatMin)
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

			function IsTerablindedInner()
				
				local sToChat = string.format("%s was blinded. Mordechai Redmoon's challenge is lost. Remember to always look out to prevent this!", getTarget)

				self:CountFails(getTarget)
				self:InformOthers(sToChat, true, false)

				local sToChatMin = string.format("Was blinded.", getSpell)
				self:AddTooltip(getTarget, sToChatMin)
			end

			if tEventArgs.unitTarget:GetBuffs().arHarmful[1].strTooltip == "Blinded!" then

				local getTarget = tEventArgs.unitTarget:GetName()
				local actualGametime = GameLib.GetGameTime()

				if self.hlp.BlindedLastGametime ~= nil then
					self.hlp.BlindedLastGametime = {}
				end

				if self.hlp.BlindedLastGametime[getTarget] ~= nil then
					self.hlp.BlindedLastGametime[getTarget] = actualGametime
				end

				local difference = actualGametime - self.hlp.BlindedLastGametime[getTarget]

				if difference == 0 then
					IsTerablindedInner()
				elseif difference > 10 then
					IsTerablindedInner()
				end

				self.hlp.BlindedLastGametime[getTarget] = actualGametime
			end
		end
	end

end

function SC:OnCombatLogDamage(self, tEventArgs)

	local getSpell = tEventArgs.splCallingSpell:GetName()
	local getCaster = tEventArgs.unitCaster:GetName()
	local getTarget = tEventArgs.unitTarget:GetName()

	if getSpell == "Seismic Tremor" and getCaster == "Thunderfoot" then

		local sToChatMin = string.format("Was hit by %s.", getSpell)
		self:AddTooltip(getTarget, sToChatMin)

		local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Is really that hard to jump?", getTarget, getSpell, getCaster)
		self:InformOthers(sToChat, true, false)

		self:CountFails(getTarget)
	end

	if getSpell == "Dark Fireball" and getCaster == "Laveka the Dark-Hearted" then

		local sToChatMin = string.format("Was hit by %s.", getSpell)
		self:AddTooltip(getTarget, sToChatMin)

		local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Come on, just evade small circular AOE, you are not that bad, are you?", getTarget, getSpell, getCaster)
		self:InformOthers(sToChat, true, false)

		self:CountFails(getTarget)
	end

	if getTarget == "Bosun Octog" then

		function IsBosunBroken()
		   local getBossBuffs = tEventArgs.unitCaster:GetBuffs().arHarmful[1].splEffect:GetName() ~= nil
		end

		if pcall(IsBosunBroken) then
			if tEventArgs.unitTarget:GetBuffs().arHarmful[1].splEffect:GetName() == "Broken Armor" then
				self.hlp.OctogStacks = getBossBuffs.arHarmful[1].nCount
				self:Debug("Octog have stacks: " .. self.hlp.OctogStacks)
			end
		end
	end

	if getCaster == "Bosun Octog" then

		function IsBosunBroken()
		   local getBossBuffs = tEventArgs.unitCaster:GetBuffs().arHarmful[1].splEffect:GetName() ~= nil
		end

		if pcall(IsBosunBroken) then
			if tEventArgs.unitCaster:GetBuffs().arHarmful[1].splEffect:GetName() == "Broken Armor" then
				self.hlp.OctogStacks = getBossBuffs.arHarmful[1].nCount
				self:Debug("Octog have stacks: " .. self.hlp.OctogStacks)
			end
		end
	end

end

function SC:OnUnitCreated(self, unit)

end

function SC:OnUnitDestroyed(self, unit)
	
end

function SC:OnLoad() end

Apollo.RegisterPackage(SC, MAJOR, MINOR, {})