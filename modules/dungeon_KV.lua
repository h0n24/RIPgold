local MAJOR, MINOR = "Module:KV-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local KV = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
KV.null = setmetatable ({}, {
  __toinn = function () return "null" end
})

-- STATUS: 100% complete
-- What can be improved: last boss registers buffs in real time (can prevent bug at situation if he collects orb and then gets killed at the same time)

-----------------------------------------------------------------------------------------------
-- All Bosses
-----------------------------------------------------------------------------------------------

function KV:OnPublicEventStatsUpdate(self)
end

function KV:OnCombat_IN(self, unitInCombat)

	if unitInCombat:GetName() == "Slavemaster Drokk" then
		-- workaround if player get hit by Phase Blast before Slavemaster Drokk
		if self.hlp.alreadyFailedChallenge then
			self.hlp.alreadyFailedChallenge = false
		end
	end

	if unitInCombat:GetName() == "Forgemaster Trogun" then
		--self:Debug("Forgemaster reset stacks.")
		self.hlp.TrogunStacksCounted = false
		self.hlp.TrogunStacks = 0
	end
end

function KV:OnCombat_OUT(self, unitInCombat)
	if self.hlp.TrogunStacks > 0 then
		if self.hlp.TrogunStacksCounted == false then

			local sToChatMin = "Forgemaster got stacks of Primal Fire."
			self:AddTooltips(sToChatMin)

			local sToChat = string.format("Forgemaster got stacks of Primal Fire. The challenge is lost.", self.hlp.TrogunStacks)
			self:InformOthers(sToChat, true, false)

			self:AddFails()
			self.hlp.TrogunStacksCounted = true
		end
	end

end

function KV:OnCombatLogVitalModifier(self, tEventArgs)

	if self.hlp.boss["Forgemaster Trogun"] then

		function IsTerablinded()
		   local getBossBuffs = tEventArgs.unitTarget:GetBuffs().arBeneficial[1]:GetName() ~= nil
		end

		if pcall(IsTerablinded) then

			if tEventArgs.unitTarget:GetBuffs().arBeneficial[1]:GetName() == "Essence of Primal Fire" then

				local sToChat = string.format("Forgemaster got stacks of Primal Fire. The challenge is lost.", getTarget)

				self:CountFails(getTarget)
				self:InformOthers(sToChat, true, false)

				local sToChatMin = string.format("Forgemaster got stacks of Primal Fire.", getSpell)
				self:AddTooltip(getTarget, sToChatMin)
				
			end
		end
	end
end

function KV:OnCombatLogDamage(self, tEventArgs)

	local getSpell = tEventArgs.splCallingSpell:GetName()
	local getCaster = tEventArgs.unitCaster:GetName()
	local getTarget = tEventArgs.unitTarget:GetName()

	if self.hlp.boss["Grond the Corpsemaker"] then

		if getSpell == "Bone Clamp" and getCaster == "Bone Cage" then

			local sToChatMin = string.format("Felt into %s.", getSpell)
			self:AddTooltip(getTarget, sToChatMin)

			local sToChat = string.format("%s felt into %s. Grond the Corpsemaker's challenge is lost. Can't you just look under your feet?", getTarget, getSpell, getCaster)
			self:InformOthers(sToChat, true, false)

			self:CountFails(getTarget)
		end

	end

	if getSpell == "Homing Barrage" and getCaster == "Slavemaster Drokk" then

		local sToChatMin = string.format("Was hit by %s.", getSpell)
		self:AddTooltip(getTarget, sToChatMin)

		local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Come on, that AOE is smaller than a Korean dick... How did you catch it?", getTarget, getSpell, getCaster)
		self:InformOthers(sToChat, true, false)

		self:CountFails(getTarget)
	end

	if getSpell == "Phase Blast" and getCaster == "Eldan Phase Blaster" then

		local sToChatMin = string.format("Was hit by %s.", getSpell)
		self:AddTooltip(getTarget, sToChatMin)

		local sToChat = string.format("%s was hit by %s. And obviously challenge is lost. Yeah, so you wanna get vaporized... And wanna fuck the most easiest challenge. Well done. Well done.", getTarget, getSpell, getCaster)
		self:InformOthers(sToChat, true, false)

		self:CountFails(getTarget)
	end

	-- Register stacks of Trogun on Trogun delivering damage (will not register if he catches orb and then he got killed because for this function to hapen he has to do some spell)
	if getCaster == "Forgemaster Trogun" then

		function IsForgemasterBuffed()
		   local BossBuffs = tEventArgs.unitCaster:GetBuffs().arBeneficial[1].splEffect:GetName() ~= nil
		end

		if pcall(IsForgemasterBuffed) then
			local getBossBuffs = tEventArgs.unitCaster:GetBuffs()

			if getBossBuffs.arBeneficial[1].splEffect:GetName() == "Essence of Primal Fire" then
				self.hlp.TrogunStacks = getBossBuffs.arBeneficial[1].nCount
				self:Debug("Trogun has " .. self.hlp.TrogunStacks .. " stacks.")
			end
		end
	end

end

function KV:OnUnitCreated(self, unit)

end

function KV:OnUnitDestroyed(self, unit)
	
end

function KV:OnLoad() end

Apollo.RegisterPackage(KV, MAJOR, MINOR, {})