local MAJOR, MINOR = "Module:SSM-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local SSM = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
SSM.null = setmetatable ({}, {
  __toinn = function () return "null" end
})

-----------------------------------------------------------------------------------------------
-- All Bosses
-----------------------------------------------------------------------------------------------

function SSM:OnCombat_IN(self, unitInCombat)

	if unitInCombat:GetName() == "Rayna Darkspeaker" then
		-- workaround if player get hit by Torine Totems of Flame before Rayna Darkspeaker
		if self.hlp.alreadyFailedChallenge then
			self.hlp.alreadyFailedChallenge = false
		end
	end
end

function SSM:OnCombat_OUT(self, unitInCombat)

	if unitInCombat:GetName() == "Deadringer Shallaos" then

		local failsInfo = ""
		for i=1,5 do

			if self.hlp.player[i].name ~= "" then

				local additionalComma = ""
				if i > 1 then
					additionalComma = ","
				end

				local failWord = "stacks"
				if self.hlp.ShallaosStacks[i] == 1 then
					failWord = "stack"
				end

				if self.hlp.ShallaosStacks[i] > 5 then -- counts as fails when you reach more than 5 stacks, because 25 stacks is limit per a group
					local countedFails = self.hlp.ShallaosStacks[i]
					countedFails = countedFails - 5
					local oldFails = self.hlp.player[i].fails
					self.hlp.player[i].fails = oldFails + countedFails
				end

				failsInfo = string.format("%s%s %s (%s %s)", failsInfo, additionalComma, self.hlp.player[i].name, self.hlp.ShallaosStacks[i], failWord)
			end
		end

		local sToChat = string.format("Who is the best player here? %s", failsInfo)
		self:InformOthers(sToChat, true, false)

	end
end

function SSM:OnCombatLogVitalModifier(self, tEventArgs)

	if tEventArgs.unitCaster:GetName() == "Spiritmother Selene's Echo" then

		local SeleneHealth = tEventArgs.unitCaster:GetHealth()
		local SeleneMaxHealth = tEventArgs.unitCaster:GetMaxHealth()
		local SelenePercentage = SeleneHealth / SeleneMaxHealth
		self.hlp.SelenePercentage = SelenePercentage
	end

	if self.hlp.boss["Deadringer Shallaos"] then

		local getHarmfulBuffs = tEventArgs.unitTarget:GetBuffs().arHarmful
		if getHarmfulBuffs ~= nil then

			for i,buff in pairs(getHarmfulBuffs) do

				local getDebuffName = buff.splEffect:GetName()
				if getDebuffName ~= nil then

					if getDebuffName == "Resonance" then

						local getTarget = tEventArgs.unitTarget:GetName()
						--local sToChat = string.format("%s resonance stacks",getTarget)
						--SendVarToRover(sToChat, buff.nCount)
						local getGroupMaxSize = GroupLib.GetGroupMaxSize(); -- its 5 when in group, 0 when alone

						if getGroupMaxSize == 0 then
							self.hlp.ShallaosStacks[1] = buff.nCount
						else
							for nGroupIndex=1,getGroupMaxSize do

								local getGroupMember = GroupLib.GetGroupMember(nGroupIndex); 
								if getGroupMember ~= nil then

									local getGroupMemberName = getGroupMember.strCharacterName
									if getGroupMemberName == getTarget then
										-- workaround if, because you usually lose all stacks on death and it would give you 0
										if buff.nCount > self.hlp.ShallaosStacks[nGroupIndex] then
											self.hlp.ShallaosStacks[nGroupIndex] = buff.nCount
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

function SSM:OnCombatLogDamage(self, tEventArgs)

	local getSpell = tEventArgs.splCallingSpell:GetName()
	local getCaster = tEventArgs.unitCaster:GetName()
	local getTarget = tEventArgs.unitTarget:GetName()

	if getCaster == "Deadringer Shallaos" then

		-- workaround, no clue why Shallaos is exception from global boss incombat function, but it shouldnt fuck up with other things as well as it will be set false after she dies (which works)
		self.hlp.boss["Deadringer Shallaos"] = true

	end

	if getSpell == "Righteous Fire" and getCaster == "Torine Totem of Flame" then

		local sToChat = string.format("%s was hit by %s. %s's challenge is lost.", getTarget, getSpell, getCaster)
		self:CountFails(getTarget)
		self:InformOthers(sToChat, true, false)

	end

	if getSpell == "Molten Wave" and getCaster == "Rayna Darkspeaker" then

		local sToChat = string.format("%s was hit by %s. %s's challenge is lost. You are bad at dancing between fire walls.", getTarget, getSpell, getCaster)
		self:CountFails(getTarget)
		self:InformOthers(sToChat, true, false)

	end

	if getSpell == "Plague Splatter" and getCaster == "Ondu Lifeweaver" then

		local sToChat = string.format("%s was hit by %s. %s's challenge is lost. You have to be blind to miss telegraph that big.", getTarget, getSpell, getCaster)
		self:CountFails(getTarget)
		self:InformOthers(sToChat, true, false)

	end

	if getSpell == "Corruption Pustule" and getCaster == "Moldwood Swarmling" then

		local sToChat = string.format("%s was hit by %s. Vitara's heart challenge is lost. If you can't run, kill him in less than 60s.", getTarget, getSpell, getCaster)
		self:CountFails(getTarget)
		self:InformOthers(sToChat, true, false)

	end

	if getTarget == "Spiritmother Selene's Echo" then

		local SeleneHealth = tEventArgs.unitTarget:GetHealth()
		local SeleneMaxHealth = tEventArgs.unitTarget:GetMaxHealth()
		local SelenePercentage = SeleneHealth / SeleneMaxHealth

		self.hlp.SelenePercentage = SelenePercentage
		self:Debug(string.format("%3.0f", SelenePercentage))

	end

end

function SSM:OnUnitCreated(self, unit)
	
	local getUnitName = unit:GetName()
	if getUnitName == "Spiritmother Selene" then

		local SelenePercentage = self.hlp.SelenePercentage * 100

		if (100 > SelenePercentage and SelenePercentage > 0) then
				
			local SelenePercentageString = string.format("%.f %%", SelenePercentage);
			local sToChat = string.format("Spiritmother was at %s health. Challenge is lost. She has to be full at the end of battle.", SelenePercentageString)
			self:AddFails()
			self:InformOthers(sToChat, true, false)
		end
	end
end

function SSM:OnUnitDestroyed(self, unit)
	
end

function SSM:OnLoad() end

Apollo.RegisterPackage(SSM, MAJOR, MINOR, {})