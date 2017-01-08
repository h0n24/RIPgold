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

-----------------------------------------------------------------------------------------------
-- All Bosses
-----------------------------------------------------------------------------------------------

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

		-- testing purposes
		-- for chanellerIndex=1,4 do
		-- 	function doesThundercallExist()
		-- 	   local getThundercallReady = GameLib.GetUnitById(self.hlp.WindInvokerChanellerID[chanellerIndex]) ~= nil
		-- 	end

		-- 	if pcall(doesThundercallExist) then
		-- 		local getThundercallReady = GameLib.GetUnitById(self.hlp.WindInvokerChanellerID[chanellerIndex])
		-- 		if getThundercallReady then
		-- 			SendVarToRover("chaneller"..GameLib.GetGameTime(),getThundercallReady)

		-- 			SendVarToRover("chaneller valid"..GameLib.GetGameTime(),getThundercallReady:IsValid())
		-- 			SendVarToRover("chaneller nameplate"..GameLib.GetGameTime(),getThundercallReady:ShouldShowNamePlate())
		-- 		end
		-- 	end
		-- end

		-- end of testing purposes

		if self.hlp.WindInvokerChannelerTargetable then
			if unit:GetName() == "Hostile Invisible Unit for Fields (0 hit radius)" then
				--SendVarToRover("unit created ".. GameLib.GetGameTime(), unit)
				self.hlp.WindInvokerInvisibleUnitID = unit:GetId()
				STL:getPlayerWithCircle(self, unit)
				self.hlp.doesChannelerExists:Start()
			end
		end
	end
end

function STL:OnUnitDestroyed(self, unit)
	
	if self.hlp.boss["Blade-Wind the Invoker"] then
		if unit:GetName() == "Hostile Invisible Unit for Fields (0 hit radius)" then
			local unitID = unit:GetId()
			if unitID == self.hlp.WindInvokerInvisibleUnitID then
				STL:getCircleDistances(self, unit)
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- First Boss: Blade-Wind the Invoker
-----------------------------------------------------------------------------------------------

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

	--return self
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

	--return self
end

function STL:getPlayerWithCircle(self, unit)
	
	local circlePosition = unit:GetPosition()

	-- testing purposes
	-- for chanellerIndex=1,4 do
	-- 	function doesThundercallExist()
	-- 	   local getThundercallReady = GameLib.GetUnitById(self.hlp.WindInvokerChanellerID[chanellerIndex]) ~= nil
	-- 	end

	-- 	if pcall(doesThundercallExist) then
	-- 		local getThundercallReady = GameLib.GetUnitById(self.hlp.WindInvokerChanellerID[chanellerIndex])
	-- 		if getThundercallReady then
	-- 			SendVarToRover("chaneller"..GameLib.GetGameTime(),getThundercallReady)

	-- 			SendVarToRover("chaneller nameplate"..GameLib.GetGameTime(),getThundercallReady:ShouldShowNamePlate())

	-- 		end
	-- 	end
	-- end

	-- end of testing purposes

	local getGroupMaxSize = GroupLib.GetGroupMaxSize() -- its 5 when in group, 0 when alone
	if getGroupMaxSize == 0 then
		function GetPlayerName()
		   local getName = GameLib.GetPlayerUnit(1):GetName() ~= nil
		end

		if pcall(GetPlayerName) then
			local getCurrentPlayerName = GameLib.GetPlayerUnit(1):GetName()
			local playerPosition = GameLib.GetPlayerUnit(1):GetPosition()

			self.hlp.WindInvokerTargetPlayer["name"] = getCurrentPlayerName
			self.hlp.WindInvokerTargetPlayer["x"] = playerPosition["x"]
			self.hlp.WindInvokerTargetPlayer["z"] = playerPosition["z"]
		end
	else
		for nGroupIndex=1,getGroupMaxSize do 
			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)

			if getGroupMember ~= nil then

				local getGroupMemberUnit = GroupLib.GetUnitForGroupMember(nGroupIndex)

				if getGroupMemberUnit ~= nil then
					local playerPosition = getGroupMemberUnit:GetPosition()

					local diff_x = math.abs(circlePosition["x"] - playerPosition["x"])
					local diff_z = math.abs(circlePosition["z"] - playerPosition["z"])
					local diffs = math.sqrt(math.pow(diff_x, 2) + math.pow(diff_z, 2))

					self.hlp.WindInvokerDiffs[nGroupIndex] = diffs
				end
			end
		end
	
		local isNearest = self.hlp.WindInvokerDiffs[1]
		local isNearestPlayer = 1

		for nGroupIndex=1,getGroupMaxSize do
			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)

			if getGroupMember ~= nil then
				local getGroupMemberUnit = GroupLib.GetUnitForGroupMember(nGroupIndex)

				if getGroupMemberUnit ~= nil then
					local getGroupMemberName = getGroupMember.strCharacterName

					if self.hlp.WindInvokerDiffs[nGroupIndex] < isNearest then
						isNearest = self.hlp.WindInvokerDiffs[nGroupIndex]
						isNearestPlayer = nGroupIndex
					end
				end
			end
		end

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

			local channelerRadius = 7.89 -- the best constant I've found after numbers of tries, still only guess, not real constant
			if shortestDistance > channelerRadius then
				local missedDistance = shortestDistance - channelerRadius

				SendVarToRover(self.hlp.WindInvokerTargetPlayer["name"].. " "..GameLib.GetGameTime(), missedDistance)
				SendVarToRover("shortestDistance "..GameLib.GetGameTime(), shortestDistance)
				missedDistance = Apollo.FormatNumber(missedDistance, 2, true)

				if self.hlp.event["Stormchaser"] == 1 then -- new function, in testing

				--if missedDistance ~= 9.99 then --workaround for some random happening bug, chance that players will drop circle at this location is minor → possibly not happening after self.hlp.WindInvokerChannelerTargetable being true
					local sToChatMin = string.format("Missed placing AOE by %s m.", missedDistance)
					self:AddTooltip(self.hlp.WindInvokerTargetPlayer["name"], sToChatMin)

					local sToChat = string.format("%s missed placing AOE by %s m.", self.hlp.WindInvokerTargetPlayer["name"], missedDistance)
					--self:InformOthers(sToChat, true, false)
					self:InformOthers(sToChat, false, false)
					--self:Debug(sToChat)

					self:CountFails(self.hlp.WindInvokerTargetPlayer["name"])
				--end

				end

				if self.hlp.event["Stormchaser"] == 0 then -- new function, in testing

				--if missedDistance ~= 9.99 then --workaround for some random happening bug, chance that players will drop circle at this location is minor → possibly not happening after self.hlp.WindInvokerChannelerTargetable being true
					local sToChatMin = string.format("Missed placing circle by %s m.", missedDistance)
					self:AddTooltip(self.hlp.WindInvokerTargetPlayer["name"], sToChatMin)

					local sToChat = string.format("%s missed placing circle by %s m.", self.hlp.WindInvokerTargetPlayer["name"], missedDistance)
					--self:InformOthers(sToChat, true, false)
					self:InformOthers(sToChat, false, false)
					--self:Debug(sToChat)

					self:CountFails(self.hlp.WindInvokerTargetPlayer["name"])
				--end

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