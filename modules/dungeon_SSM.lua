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

-- STATUS: 100% complete

-----------------------------------------------------------------------------------------------
-- All Bosses
-----------------------------------------------------------------------------------------------

function SSM:OnPublicEventStatsUpdate(self)

	if self.hlp.isBossDead.name == "Spiritmother Selene the Corrupted" then

		if self.hlp.isBossDead.dead == false then

			if self.hlp.event["Don't Blink"] == 0 then
				if not self.hlp.alreadyFailedChallenge then
					local sToChatMin = "Shadows weren't MOOed or killed."
					self:AddTooltips(sToChatMin)

					local sToChat = string.format("After everyone got blinded, there was no Shadow of Selene the Corrupted MOOed or killed. Challenge is lost.")
					self:InformOthers(sToChat, true, false)
					self.hlp.alreadyFailedChallenge = true --workaround for multiple tooltips happenning, probably function above is slower than EventStatsUpdate
				end
			end
		end
	end

	-- writes to people that they can ressurect up after all totems are placed
	if self.hlp.event["Spiritual Revival with Selene at full health"] == 1 then
		if not self.hlp.alreadyRezzedUp then

			if self.get.GroupMaxSize ~= 0 then -- only announces when in group
				for nGroupIndex=1, self.get.GroupMaxSize do
					if self.hlp.player[nGroupIndex].dead == true then
						local message = "You can ressurect now."
						ChatSystemLib.Command("/w "..self.hlp.player[nGroupIndex].name.." "..message)
					end
				end
			end
			self.hlp.alreadyRezzedUp = true
		end
	end
end


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

				if self.hlp.ShallaosStacks[i] > 5 then -- counts as fails when you reach more than 5 stacks, because 25 stacks is limit per a group
					local countedFails = self.hlp.ShallaosStacks[i]
					countedFails = countedFails - 5
					local oldFails = self.hlp.player[i].fails
					self.hlp.player[i].fails = oldFails + countedFails

					local sToChatMin = string.format("Got %s (+5) stacks from Shallaos.", countedFails)
					self:AddTooltip(self.hlp.player[i].name, sToChatMin)
				end

				-- shows number of stacks or word died (because players who die early have less stacks so it seems like they are better even thou in reality they aren't)
				local failsORdeath = ""
				if self.hlp.player[i].dead == true then
					failsORdeath = "died"
				else
					local failWord = "stacks"
					if self.hlp.ShallaosStacks[i] == 1 then
						failWord = "stack"
					end
					failsORdeath = string.format("%s %s", self.hlp.ShallaosStacks[i], failWord)
				end

				failsInfo = string.format("%s%s %s (%s)", failsInfo, additionalComma, self.hlp.player[i].name, failsORdeath)
			end
		end

		local sToChat = string.format("Who is the best player here? %s", failsInfo)
		self:InformOthers(sToChat, true, false)

	end
end

function SSM:OnCombatLogVitalModifier(self, tEventArgs)

	if tEventArgs.unitCaster:GetName() == "Spiritmother Selene's Echo" then

		-- automatic focus
		GameLib.GetPlayerUnit(1):SetAlternateTarget(tEventArgs.unitCaster)

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
						self:Rover(buff.nCount,false,getTarget.." resonance stacks")

						if self.get.GroupMaxSize == 0 then
							if buff.nCount > self.hlp.ShallaosStacks[1] then
								self.hlp.ShallaosStacks[1] = buff.nCount
							end
						else
							for nGroupIndex=1,self.get.GroupMaxSize do

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

	-----------------------------------------------------------------------------------------------
	-- Challenges that counts everytime
	-----------------------------------------------------------------------------------------------

	if getCaster == "Deadringer Shallaos" then

		-- workaround, no clue why Shallaos is exception from global boss incombat function, but it shouldnt fuck up with other things as well as it will be set false after she dies (which works)
		self.hlp.boss["Deadringer Shallaos"] = true

	end

	if getTarget == "Spiritmother Selene's Echo" then

		local SeleneHealth = tEventArgs.unitTarget:GetHealth()
		local SeleneMaxHealth = tEventArgs.unitTarget:GetMaxHealth()
		local SelenePercentage = SeleneHealth / SeleneMaxHealth

		self.hlp.SelenePercentage = SelenePercentage
		self:Debug(string.format("%3.0f", SelenePercentage))

	end

	-----------------------------------------------------------------------------------------------
	-- Challenges that counts only once per few seconds
	-----------------------------------------------------------------------------------------------
	function CountOnlyXSeconds()
		if getSpell == "Righteous Fire" and getCaster == "Torine Totem of Flame" then

			local sToChatMin = string.format("Was hit by %s.", getSpell)
			self:AddTooltip(getTarget, sToChatMin)

			local sToChat = string.format("%s was hit by %s. %s's challenge is lost.", getTarget, getSpell, getCaster)
			self:InformOthers(sToChat, true, false)

			self:CountFails(getTarget)
		end

		if getSpell == "Molten Wave" and getCaster == "Rayna Darkspeaker" then

			if self.hlp.boss["Rayna Darkspeaker"] then

				local sToChatMin = string.format("Was hit by %s.", getSpell)
				self:AddTooltip(getTarget, sToChatMin)

				local sToChat = string.format("%s was hit by %s. %s's challenge is lost. You are bad at dancing between fire walls.", getTarget, getSpell, getCaster)
				self:InformOthers(sToChat, true, false)

				self:CountFails(getTarget)
			end
		end

		if getSpell == "Plague Splatter" and getCaster == "Ondu Lifeweaver" then

			local sToChatMin = string.format("Was hit by %s.", getSpell)
			self:AddTooltip(getTarget, sToChatMin)

			local sToChat = string.format("%s was hit by %s. %s's challenge is lost. You have to be blind to miss telegraph that big.", getTarget, getSpell, getCaster)
			self:InformOthers(sToChat, true, false)

			self:CountFails(getTarget)
		end

		if getSpell == "Corruption Pustule" and getCaster == "Moldwood Swarmling" then

			local sToChatMin = string.format("Was hit by %s.", getSpell)
			self:AddTooltip(getTarget, sToChatMin)

			local sToChat = string.format("%s was hit by %s. Vitara's heart challenge is lost. If you can't run, kill him in less than 60s.", getTarget, getSpell, getCaster)
			self:InformOthers(sToChat, true, false)

			self:CountFails(getTarget)
		end
	end

	local actualGametime = GameLib.GetGameTime()

	if self.hlp.lastGametimeFailed == nil then
		self.hlp.lastGametimeFailed = {}
	end

	if self.hlp.lastGametimeFailed[getTarget] == nil then
		self.hlp.lastGametimeFailed[getTarget] = actualGametime
	end

	local lastTimeFailed = actualGametime - self.hlp.lastGametimeFailed[getTarget]

	if lastTimeFailed == 0 then
		CountOnlyXSeconds()
		self.hlp.lastGametimeFailed[getTarget] = actualGametime
	elseif lastTimeFailed > 1.5 then
		CountOnlyXSeconds()
		self.hlp.lastGametimeFailed[getTarget] = actualGametime
	end

end

function SSM:OnUnitCreated(self, unit)
	
	local getUnitName = unit:GetName()
	if getUnitName == "Spiritmother Selene" then

		-- automatically clears focus
		GameLib.GetPlayerUnit(1):SetAlternateTarget(0)

		local SelenePercentage = self.hlp.SelenePercentage * 100

		if (100 > SelenePercentage and SelenePercentage > 0) then
				
			local SelenePercentageString = string.format("%.f %%", SelenePercentage)

			if SelenePercentageString == 100 then
				SelenePercentageString = Apollo.FormatNumber(SelenePercentage, 2, true)
			end

			local sToChatMin = string.format("Spiritmother was at %s health.", SelenePercentageString)
			self:AddTooltips(sToChatMin)

			local sToChat = string.format("Spiritmother was at %s health. Challenge is lost. She has to be full at the end of battle.", SelenePercentageString)
			self:InformOthers(sToChat, true, false)

			self:AddFails()
		end
	end

	if getUnitName == "Spirit-Relic of Blood" then
		self.hlp.TorineRelicsUnit = unit
	end
end

function SSM:checkForRelicOfBlood(self)
	if self.hlp.TorineRelicsCount == 0 then
		local sToChat = "We forgot to collect Spirit-Relic of Blood."
		self:InformOthers(sToChat, false, false)

		-- set focus on torine relic and calls itself (will keep announcing untill collected)
		GameLib.GetPlayerUnit(1):SetAlternateTarget(self.hlp.TorineRelicsUnit)
		self.hlp.doesRelicBloodExist:Start()
	else
		GameLib.GetPlayerUnit(1):SetAlternateTarget(0)
	end
end

function SSM:OnUnitDestroyed(self, unit)

end

function SSM:OnLoad() end

Apollo.RegisterPackage(SSM, MAJOR, MINOR, {})