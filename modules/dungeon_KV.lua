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

-----------------------------------------------------------------------------------------------
-- All Bosses
-----------------------------------------------------------------------------------------------

function KV:OnCombat_IN(self, unitInCombat)

	if unitInCombat:GetName() == "Slavemaster Drokk" then
		-- workaround if player get hit by Phase Blast before Slavemaster Drokk
		if self.hlp.alreadyFailedChallenge then
			self.hlp.alreadyFailedChallenge = false
		end
	end
end

function KV:OnCombat_OUT(self, unitInCombat)

	if unitInCombat:GetName() == "Forgemaster Trogun" then
		if self.hlp.TrogunStacks > 0 then
			local sToChat = string.format("Forgemaster got stacks of Primal Fire. The challenge is lost.", self.hlp.TrogunStacks)
			self:AddFails()
			self:InformOthers(sToChat, true, false)
		end
	end
end

function KV:OnCombatLogVitalModifier(self, tEventArgs)
end

function KV:OnCombatLogDamage(self, tEventArgs)

	local getSpell = tEventArgs.splCallingSpell:GetName()
	local getCaster = tEventArgs.unitCaster:GetName()
	local getTarget = tEventArgs.unitTarget:GetName()

	if self.hlp.boss["Grond the Corpsemaker"] then

		if getSpell == "Bone Clamp" and getCaster == "Bone Cage" then

			local sToChat = string.format("%s felt into %s. Grond the Corpsemaker's challenge is lost. Can't you just look under your feet?", getTarget, getSpell, getCaster)
			self:CountFails(getTarget)
			self:InformOthers(sToChat, true, false)

		end

	end

	if getSpell == "Homing Barrage" and getCaster == "Slavemaster Drokk" then

		local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Come on, that AOE is smaller than Korean dick... How did you caught it?", getTarget, getSpell, getCaster)
		self:CountFails(getTarget)
		self:InformOthers(sToChat, true, false)

	end

	if getSpell == "Phase Blast" and getCaster == "Eldan Phase Blaster" then

		local sToChat = string.format("%s was hit by %s. And obviously challenge is lost. Yeah, so you wanna get vaporized... And wanna fuck the most easiest challenge. Well done. Well done.", getTarget, getSpell, getCaster)
		self:CountFails(getTarget)
		self:InformOthers(sToChat, true, false)

	end

	if getTarget == "Forgemaster Trogun" then

		function IsForgemasterBuffed()
		   local BossBuffs = tEventArgs.unitTarget:GetBuffs().arBeneficial[1].splEffect:GetName() ~= nil
		end

		if pcall(IsForgemasterBuffed) then
			local getBossBuffs = tEventArgs.unitTarget:GetBuffs()

			--if getBossBuffs.arBeneficial[1].strTooltip == "Primal Rage" then
			if getBossBuffs.arBeneficial[1].splEffect:GetName() == "Essence of Primal Fire" then
				self.hlp.TrogunStacks = getBossBuffs.arBeneficial[1].nCount
				self:Debug("Trogun have stacks: " .. self.hlp.TrogunStacks)
			end
		end
	end

	if getCaster == "Forgemaster Trogun" then

		function IsForgemasterBuffed()
		   local BossBuffs = tEventArgs.unitCaster:GetBuffs().arBeneficial[1].splEffect:GetName() ~= nil
		end

		if pcall(IsForgemasterBuffed) then
			local getBossBuffs = tEventArgs.unitCaster:GetBuffs()

			--if getBossBuffs.arBeneficial[1].strTooltip == "Primal Rage" then
			if getBossBuffs.arBeneficial[1].splEffect:GetName() == "Essence of Primal Fire" then
				self.hlp.TrogunStacks = getBossBuffs.arBeneficial[1].nCount
				self:Debug("Trogun have stacks: " .. self.hlp.TrogunStacks)
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