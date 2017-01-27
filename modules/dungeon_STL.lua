local MAJOR, MINOR = "Module:STL-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local STL = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
STL.null = setmetatable ({}, {
  __toinn = function () return "null" end
})

-- STATUS: 90% complete
-- Missing: second boss adds kill in 15 seconds

-- What needs more testing: Not sure first boss works every time, not sure about the right distance of shield of Channelers
-- Theoretically possible bug: when two channelers are dead at the same moment

-----------------------------------------------------------------------------------------------
-- All Bosses
-----------------------------------------------------------------------------------------------

function STL:checkForBossDeaths(self)

end

function STL:OnPublicEventStatsUpdate(self)
	if self.hlp.boss["Blade-Wind the Invoker"] then
		if self.hlp.event["Stormchaser"] == 0 then 
			if self.hlp.varsForChallengeActive ~= nil then
				if self.hlp.varsForChallengeActive.alreadyfailed == false then
					local sToChat = string.format("Blade-Wind the Invoker's challenge is lost.")
					self:InformOthers(sToChat, true, false)
				end
			end
		end
	end
end

function STL:OnCombat_IN(self, unitInCombat)

end

function STL:OnCombat_OUT(self, unitInCombat)

end

function STL:OnCombatLogVitalModifier(self, tEventArgs)

end

function STL:OnCombatLogDamage(self, tEventArgs)

	local getSpell = tEventArgs.splCallingSpell:GetName()
	local getCaster = tEventArgs.unitCaster:GetName()
	local getTarget = tEventArgs.unitTarget:GetName()

	if getCaster == "Blade-Wind the Invoker" then

		-- workaround, no clue why Invoker is exception from global boss incombat function, but it shouldnt fuck up with other things as well as it will be set false after he dies (which works)
		self.hlp.boss["Blade-Wind the Invoker"] = true

		-- workaround, spell Shock is being casted when Channelers get out of invulnerable shield -> so it proceeds in aoe counting phase
		if getSpell == "Shock" then
			self.hlp.WindInvokerChannelerTargetable = true
		end

	end

	if getSpell == "Twister" and getCaster == "Aethros Twister" then

		local sToChatMin = string.format("Was hit by %s.", getSpell)
		self:AddTooltip(getTarget, sToChatMin)

		local sToChat = string.format("%s was hit by %s. Aethros's challenge is lost. What's so problematic at dancing between tornados?", getTarget, getSpell, getCaster)
		self:InformOthers(sToChat, true, false)

		self:CountFails(getTarget)
	end

	if getSpell == "Lightning Strike" and getCaster == "Stormtalon" then

		local sToChatMin = string.format("Was hit by %s.", getSpell)
		self:AddTooltip(getTarget, sToChatMin)

		local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Remember! Run around after moo and don't stay in the middle of moving telegraph.", getTarget, getSpell, getCaster)
		self:InformOthers(sToChat, true, false)

		self:CountFails(getTarget)
	end

end

function STL:OnUnitCreatedBeforeEnteringDungeon(self, unit)
	-- Warning! Checking for "Thundercall Channeler unit has to be before checking for dungeons because it happens before entring the dungeon in function OnPublicEventStatsUpdate()

	-- has to be outside InitializeVars() becouse it would get reseted after game creates Channelers
	if self.hlp.WindInvokerChanellerID == nil then
		self.hlp.WindInvokerChanellerID = { 
			[1] = 0, [2] = 0, [3] = 0, [4] = 0 
		}
	end

	if unit:GetName() == "Thundercall Channeler" then
		STL:getChannelerID(self, unit)
	end
end

function STL:OnUnitCreated(self, unit)

	if self.hlp.boss["Blade-Wind the Invoker"] then

		if self.hlp.WindInvokerChannelerTargetable then
			if unit:GetName() == "Hostile Invisible Unit for Fields (0 hit radius)" then
				
				self.hlp.WindInvokerInvisibleUnitID = unit:GetId()
				self.hlp.WindInvokerInvisibleUnitTime[unit:GetId()] = GameLib.GetGameTime()
				STL:getPlayerWithCircle(self, unit)
				self.hlp.doesChannelerExists:Start()
			end
		end
	end
end

function STL:OnUnitDestroyed(self, unit)
	
	if self.hlp.boss["Blade-Wind the Invoker"] then
		if unit:GetName() == "Hostile Invisible Unit for Fields (0 hit radius)" then
			local getWindInvokerInvisibleUnitTime = self.hlp.WindInvokerInvisibleUnitTime[unit:GetId()]
			if getWindInvokerInvisibleUnitTime ~= nil then
				
				local timeDifference = GameLib.GetGameTime() - getWindInvokerInvisibleUnitTime
				if timeDifference > 3 then
					-- some random occuring unit, possibly lightning animation from boss or some other players animation (SS or Engi), RIPcoding & THX carabino
				elseif timeDifference > 1.4 then
					local unitID = unit:GetId()
					if unitID == self.hlp.WindInvokerInvisibleUnitID then
						STL:getCircleDistances(self, unit)
					end
				end
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- First Boss: Blade-Wind the Invoker
-----------------------------------------------------------------------------------------------

-- how it currently works (and maybe it can be coded way better, any ideas wellcome, spend developing this over 96 hours... RIPme)
-- 1) before party enters dungeon (OnUnitCreatedBeforeEnteringDungeon) there are 4 Thundercall Channeler created, algorithm catches first Channeler ID and then tries 3 IDs before that ID and 3 after so it fills up variable with 4 channeler IDs
-- 2) when engaging boss isBossDead and isInCombat function is called & saved into variable (like any other boss)
-- 3) when boss casts "Shock" phase of creating circles starts (way faster to check for Shock than for shield updates)
-- 4) at nearly same time two "invisible units" are created, one is circle that has to be placed under channeler, one thats connected with shock animation (i really wish circle had some name, would be 100% easier)
-- 5) when invisible unit is created, distance between it and nearest player is saved
-- 6) when "invisible unit" is destroyed, id of that unit is checked, it has to be the same as from one before created and also the time treshold has to be less than 3 seconds and more than 1.4 seconds (can'b be static number of seconds because server latency makes difference between units fluid)
-- 6) when invisible unit is destroyed, distance between it and nearest player is saved
-- 7) distance of that destroyed unit towards 4 thundercall channelers is measured and one with smallest distance is picked
-- 6) firstly "challenge lost" is announced and then player that missed. Both of messages are separate for because theoretically my alghoritm can fail (at future there can be different modifier, when latency over 3 seconds etc...) and so there is failback function that registers when OnPublicEventStatsUpdate happens (= challenge disappears from Event Tracker) 

function STL:getChannelerID(self, unit)

	-- workaround for "feature" when sometimess channeler is first from all four chennelers and sometimes last from all which makes different ID ranges
	local ThundercallChannelerID = unit:GetId()
	local numberBasePosition = -4
	for actualPosition=1,7 do
		local numberPosition = numberBasePosition + actualPosition
		local testedID = ThundercallChannelerID + numberPosition
		local doesExist = GameLib.GetUnitById(testedID)

		if doesExist ~= nil then
			local doesHaveName = GameLib.GetUnitById(testedID):GetName()
			if doesHaveName == "Thundercall Channeler" then
				local numberID = math.abs(numberPosition) + 1
				self.hlp.WindInvokerChanellerID[numberID] = testedID
			end
		end
	end
end

function STL:checkForChannelerDeaths(self)

	if self.hlp.isInDungeon then 
		for chanellerIndex=1,4 do

			function doesThundercallExist()
			   local getThundercallPosition = GameLib.GetUnitById(self.hlp.WindInvokerChanellerID[chanellerIndex]):IsDead() ~= nil
			end

			if pcall(doesThundercallExist) then
				local getThundercallPosition = GameLib.GetUnitById(self.hlp.WindInvokerChanellerID[chanellerIndex]):IsDead()
				if getThundercallPosition then
					self.hlp.WindInvokerChanellerID[chanellerIndex] = 0
				end
			end
		end
	end
end

function STL:getPlayerWithCircle(self, unit)
	
	local circlePosition = unit:GetPosition()

	if self.get.GroupMaxSize == 0 then
		function GetPlayerName()
		   local getName = GameLib.GetPlayerUnit():GetName() ~= nil
		end

		if pcall(GetPlayerName) then
			local getCurrentPlayerName = GameLib.GetPlayerUnit():GetName()
			local playerPosition = GameLib.GetPlayerUnit():GetPosition()

			self.hlp.WindInvokerTargetPlayer["name"] = getCurrentPlayerName
			self.hlp.WindInvokerTargetPlayer["x"] = playerPosition["x"]
			self.hlp.WindInvokerTargetPlayer["z"] = playerPosition["z"]
		end
	else
		local shortestDistance = 999
		local isNearestPlayer = 1

		for nGroupIndex=1,self.get.GroupMaxSize do 
			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)

			if getGroupMember ~= nil then

				local getGroupMemberUnit = GroupLib.GetUnitForGroupMember(nGroupIndex)

				if getGroupMemberUnit ~= nil then
					local playerPosition = getGroupMemberUnit:GetPosition()

					local diff_x = math.abs(circlePosition["x"] - playerPosition["x"])
					local diff_z = math.abs(circlePosition["z"] - playerPosition["z"])
					local diffs = math.sqrt(math.pow(diff_x, 2) + math.pow(diff_z, 2))

					if diffs < shortestDistance then
						shortestDistance = diffs
						isNearestPlayer = nGroupIndex
					end
				end
			end
		end

		self.hlp.WindInvokerTargetPlayer["name_before"] = self.hlp.WindInvokerTargetPlayer.name
		self.hlp.WindInvokerTargetPlayer["name"] = GroupLib.GetGroupMember(isNearestPlayer).strCharacterName
		local targetedPlayerPosition = GroupLib.GetUnitForGroupMember(isNearestPlayer):GetPosition()
		self.hlp.WindInvokerTargetPlayer["x"] = targetedPlayerPosition["x"]
		self.hlp.WindInvokerTargetPlayer["z"] = targetedPlayerPosition["z"]
	end
end

function STL:getCircleDistances(self, unit)

	local shortestDistance = 999
	for n=1,4 do
		local actualDistance = STL:getCircleDistance(self, unit, n)

		if actualDistance ~= nil then
			if actualDistance < shortestDistance then
				shortestDistance = actualDistance
			end
		end
	end

	if shortestDistance ~= 999 then 

		-- workaround with gametime to prevent "feature" when circle occurs two times at the same time
		local actualGametime = GameLib.GetGameTime()
		if self.hlp.WindInvokerLastGametime ~= actualGametime then

			--local channelerRadius = 7.89 -- the best constant I've found after numbers of tries, still only guess, not real constant
			local channelerRadius = 8.17 -- the best constant I've found after numbers of tries, still only guess, not real constant
			if shortestDistance > channelerRadius then
				local missedDistance = shortestDistance - channelerRadius

				missedDistance = Apollo.FormatNumber(missedDistance, 2, true)
				self.hlp.varsForChallengeActive.alreadyfailed = true

				local sToChat = "Blade-Wind the Invoker's challenge is lost."
				self:InformOthers(sToChat, true, false)

				if self.hlp.WindInvokerTargetPlayer["name_before"] ~= self.hlp.WindInvokerTargetPlayer["name"] then
					if self.get.GroupMaxSize == 0 then
						local sToChatMin = string.format("Missed placing circle by %s m.", missedDistance)
						self:AddTooltip(self.hlp.WindInvokerTargetPlayer["name"], sToChatMin)

						local sToChat = string.format("%s missed placing circle by %s m.", self.hlp.WindInvokerTargetPlayer["name"], missedDistance)
						self:InformOthers(sToChat, false, true)
						self:CountFails(self.hlp.WindInvokerTargetPlayer["name"])
					else
						self:Debug("Nearest player name when circle created and destroyed are not the same. Skipping announcing because it can be 50% false positive.")
					end
				else
					local sToChatMin = string.format("Missed placing circle by %s m.", missedDistance)
					self:AddTooltip(self.hlp.WindInvokerTargetPlayer["name"], sToChatMin)

					local sToChat = string.format("%s missed placing circle by %s m.", self.hlp.WindInvokerTargetPlayer["name"], missedDistance)
					self:InformOthers(sToChat, false, true)
					self:CountFails(self.hlp.WindInvokerTargetPlayer["name"])
				end

			end
		end
		self.hlp.WindInvokerLastGametime = actualGametime
	end
end

function STL:getCircleDistance(self, unit, chanellerID)

	function doesThundercallExist()
	   local getBossBuffs = GameLib.GetUnitById(self.hlp.WindInvokerChanellerID[chanellerID]):GetPosition() ~= nil
	end

	if pcall(doesThundercallExist) then

		local circlePosition = unit:GetPosition()
		local channelerPosition = GameLib.GetUnitById(self.hlp.WindInvokerChanellerID[chanellerID]):GetPosition()

		local diff_x = math.abs(circlePosition["x"] - channelerPosition["x"])
		local diff_z = math.abs(circlePosition["z"] - channelerPosition["z"])
		local diffs = math.sqrt(math.pow(diff_x, 2) + math.pow(diff_z, 2))

		return diffs
	end
end

function STL:OnLoad() end

Apollo.RegisterPackage(STL, MAJOR, MINOR, {})