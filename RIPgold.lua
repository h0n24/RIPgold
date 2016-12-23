-----------------------------------------------------------------------------------------------
-- Client Lua Script for RIPgold
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

-- todo: first boss stl -> GameLib.GetUnitScreenPosition()
-- todo: reminder after 15s that you forgot to pick first relic in STL
-- Spirit Relic of Blood

 
require "Window"
require "GroupLib"
 
-----------------------------------------------------------------------------------------------
-- RIPgold Module Definition
-----------------------------------------------------------------------------------------------
local RIPgold = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function RIPgold:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function RIPgold:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)

	-- instance = {
	-- -- Persisted configuration: defaults.
	-- config = {
	--   achievements = {},
	-- },
	-- }
	-- setmetatable(instance, self)

	-- Apollo.RegisterAddon(instance, false, "", {
	-- "RIPgold.dung_stl",
	-- })

	-- return instance

end

-- local dung_stl
-- function RIPgold:LoadDependencies()
--   dung_stl = Apollo.GetPackage("RIPgold.dung_stl").tPackage
-- end
 

-----------------------------------------------------------------------------------------------
-- RIPgold OnLoad
-----------------------------------------------------------------------------------------------
function RIPgold:OnLoad()
	--self:LoadDependencies()

	--self.myClass = require("dung_stl")
	--self.myClass:helloWorld()
	--publicClass.helloWorld()

    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("RIPgold.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- RIPgold OnDocLoaded
-----------------------------------------------------------------------------------------------
function RIPgold:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "RIPgoldForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded",  "OnInterfaceMenuListHasLoaded", self)
		Apollo.RegisterEventHandler("ToggleRIPgoldUI", "OnRIPgoldOn", self)

		Apollo.RegisterSlashCommand("rip", "OnRIPgoldOn", self)
		Apollo.RegisterSlashCommand("rap", "HowManyFails", self)

		-- Do additional Addon initialization here
		Apollo.RegisterEventHandler("UnitEnteredCombat", "OnCombat", self)
		Apollo.RegisterEventHandler("CombatLogDamage", "OnCombatLogDamage", self)

		Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
		Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self)

		Apollo.RegisterEventHandler("CombatLogVitalModifier", "OnCombatLogVitalModifier", self)

		Apollo.RegisterEventHandler("PublicEventStart",	"OnPublicEventStart", self)
		Apollo.RegisterEventHandler("PublicEventStatsUpdate", "OnPublicEventStatsUpdate", self)

		Apollo.RegisterEventHandler("ChangeWorld", "OnWorldChange", self)

		-- first: seconds how often is repeated, second if its repeating
		self.checkDeadState = ApolloTimer.Create(1, true, "CheckForPlayerDeaths", self) 
		self.checkDeadState:Stop()

		self.helpers = {}

		self.helpers.doesChannelerExists = ApolloTimer.Create(1, true, "STL_checkForChannelerDeaths", self)
		self.helpers.doesChannelerExists:Stop()

		self.peMatch = nil
		self.isInDungeon = false

		self:InitializeVars()

		if not GroupLib.InRaid() then
			self:PreparePlayers()
		end

		-- has to be outside InitializeVars() becouse it would get reseted after game creates Channelers
		self.helpers.WindInvokerChanellerID = { 
			[1] = 0, [2] = 0, [3] = 0, [4] = 0 
		}

		--- testing purposes
		--self.isInDungeon = true
		--self.boss["Blade-Wind the Invoker"] = true

	end
end

-----------------------------------------------------------------------------------------------
-- RIPgold Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

function RIPgold:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "RIPgold", {"ToggleRIPgoldUI", "", ""}) --IconSprites:Icon_Windows_UI_CRB_Rival icon before (terrible meh)
end

-- on SlashCommand "/rip"
function RIPgold:OnRIPgoldOn()
	--self.wndMain:Invoke() -- show the window

	self:Debug(self.player[1].name .. ": " .. self.player[1].fails)
	self:Debug(self.player[2].name .. ": " .. self.player[2].fails)
	self:Debug(self.player[3].name .. ": " .. self.player[3].fails)
	self:Debug(self.player[4].name .. ": " .. self.player[4].fails)
	self:Debug(self.player[5].name .. ": " .. self.player[5].fails)

end

function RIPgold:HowManyFails()

	self:InformOthers("So, how many fails did you do this dungeon?", false)

	self:InformOthers(self.player[1].name .. ": " .. self.player[1].fails, false)
	self:InformOthers(self.player[2].name .. ": " .. self.player[2].fails, false)
	self:InformOthers(self.player[3].name .. ": " .. self.player[3].fails, false)
	self:InformOthers(self.player[4].name .. ": " .. self.player[4].fails, false)
	self:InformOthers(self.player[5].name .. ": " .. self.player[5].fails, false)

end

function RIPgold:InitializeVars()

	self.alreadyFailedChallenge = false
	self.alreadyFailedDeathless = false

	self.boss = {
		["Grond the Corpsemaker"] = false,
		["Slavemaster Drokk"] = false,
		["Forgemaster Trogun"] = false,
		["Stew-Shaman Tugga"] = false,
		["Thunderfoot"] = false,
		["Laveka the Dark-Hearted"] = false,
		["Bosun Octog"] = false,
		["Mordechai Redmoon"] = false,
		["Blade-Wind the Invoker"] = false,	
		["Aethros"] = false,		
		["Stormtalon"] = false,	
		["Deadringer Shallaos"] = false,
		["Rayna Darkspeaker"] = false,
		["Moldwood Overlord Skash"] = false,
		["Ondu Lifeweaver"] = false,
		["Spiritmother Selene the Corrupted"] = false,
		["Invulnotron"] = false,
		["Gromka the Flamewitch"] = false,
		["Iruki Boldbeard"] = false,
	}

	self.nPoints = 0
	self.nBronze = 0
	self.nSilver = 0
	self.nGold = 0

	self.helpers.SelenePercentage = 0
	self.helpers.TrogunStacks = 0
	self.helpers.OctogStacks = 0
	self.helpers.ShallaosStacks = { 
		[1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, 
	}
	self.helpers.WindInvokerTargetPlayer = {
		["name"] = "", ["x"] = 0, ["y"] = 0, ["z"] = 0,
	}

	self.helpers.WindInvokerDiffs = { 
		[1] = 0, [2] = 0, [3] = 0, [4] = 0 
	}

	self.helpers.WindInvokerInvisibleUnitID = 0

	self.helpers.WindInvokerLastGametime = GameLib.GetGameTime() 

end

function RIPgold:PreparePlayers()

	self.player = {
		[1] = {["name"] = "", ["fails"] = 0, ["dead"] = false},
		[2] = {["name"] = "", ["fails"] = 0, ["dead"] = false},
		[3] = {["name"] = "", ["fails"] = 0, ["dead"] = false},
		[4] = {["name"] = "", ["fails"] = 0, ["dead"] = false},
		[5] = {["name"] = "", ["fails"] = 0, ["dead"] = false},
	}

	local getGroupMaxSize = GroupLib.GetGroupMaxSize() -- its 5 when in group, 0 when alone

	if getGroupMaxSize == 0 then

		function GetPlayerName()
		   local getBossBuffs = GameLib.GetPlayerUnit(1):GetName() ~= nil
		end

		if pcall(GetPlayerName) then
			local getCurrentPlayerName = GameLib.GetPlayerUnit(1):GetName()
			self.player[1].name = getCurrentPlayerName
		end

	else

		for nGroupIndex=1,getGroupMaxSize do 

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then

				local getGroupMemberName = getGroupMember.strCharacterName
				self.player[nGroupIndex].name = getGroupMemberName
			end
		end
	end
end

function RIPgold:OnPublicEventStart()

	if self.peMatch then
		return true
	end

	for key, peCurrent in pairs(PublicEvent.GetActiveEvents()) do

		function IsPeUpdated()
		   local getPeUpdated = peCurrent:GetEventType() ~= nil
		end

		if pcall(IsPeUpdated) then

			local getEventType = peCurrent:GetEventType()
			if getEventType ~= PublicEvent.PublicEventType_Dungeon then
				return
			end

			--SendVarToRover("Dungeon event", peCurrent)

			if peCurrent:ShouldShowMedalsUI() then
				-- processed after and only entering new dungeon -> reseting points etc
				self:Debug("Everything reseted.")

				self.isInDungeon = true

				self:InitializeVars()
				self:PreparePlayers()

				self.checkDeadState:Start()

				self.nPoints = peCurrent:GetRewardThreshold(PublicEvent.PublicEventRewardTier_None)
				self.nBronze = peCurrent:GetRewardThreshold(PublicEvent.PublicEventRewardTier_Bronze)
				self.nSilver = peCurrent:GetRewardThreshold(PublicEvent.PublicEventRewardTier_Silver)
				self.nGold = peCurrent:GetRewardThreshold(PublicEvent.PublicEventRewardTier_Gold)
					
				self.peMatch = peCurrent

				--SendVarToRover("self", self)
				
				return true
			end
		end
	end

	return false

end

function RIPgold:CheckForPlayerDeaths()

	if self.isInDungeon == true then 

		for nGroupIndex=1,GroupLib.GetGroupMaxSize() do
			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)

			if getGroupMember ~= nil then

				local getGroupMemberUnit = GroupLib.GetUnitForGroupMember(nGroupIndex)

				if getGroupMemberUnit ~= nil then
					local getDeathState = getGroupMemberUnit:IsDead()
					local getGroupMemberName = getGroupMember.strCharacterName

					if getDeathState == true then
						if self.player[nGroupIndex].dead == false then

							if self.alreadyFailedDeathless == false then
								local getDeadPlayerName = getGroupMemberUnit:GetName()
								local sToChat = string.format("%s just fucked up deathless challenge. RIPgold. :(.", getDeadPlayerName)
								self:InformOthers(sToChat, false)
								--self:Debug(getGroupMemberUnit:GetName() .. " just fucked deathless.")
								self.alreadyFailedDeathless = true
							end

							self:Debug(getGroupMemberUnit:GetName() .. " is dead.")
							self.player[nGroupIndex].dead = true
							self:CountFails(getGroupMemberName)

						end
					else
						if self.player[nGroupIndex].dead == true then

							self:Debug(getGroupMemberUnit:GetName() .. " is alive.")
							self.player[nGroupIndex].dead = false
						end
					end
				end
			end
		end
	end
end

function RIPgold:OnPublicEventStatsUpdate(peUpdated)

	if not GroupLib.InRaid() then --if not in raid

		--local timeinfo = string.format("OnPublicEventStatsUpdate base - %s", GameLib.GetGameTime())
		--SendVarToRover(timeinfo, peUpdated)

		function IsPeUpdated()
		   local getPeUpdated = peUpdated:GetEventType() ~= nil
		end

		if pcall(IsPeUpdated) then

			if peUpdated:GetEventType() ~= PublicEvent.PublicEventType_Dungeon then
				return
			end

			self.isInDungeon = true
			self.checkDeadState:Start()

			local nCurrentPoints = peUpdated:GetStat(PublicEvent.PublicEventStatType.MedalPoints)
			if self.nPoints == nCurrentPoints then
				return
			end

			--SendVarToRover("self", self)

			-- code connected with event points

				--local timeinfo = string.format("OnPublicEventStatsUpdate - %s", GameLib.GetGameTime())
				--SendVarToRover(timeinfo, peUpdated)

		end

		-- function IsPeObjectives()
		--    local getPeObjectives = peUpdated:GetObjectives() ~= nil
		-- end

		-- if pcall(IsPeObjectives) then

		-- 	-- technically all event points
		-- 	local objectives = peUpdated:GetObjectives()

		-- 	for i,obj in pairs(objectives) do
		-- 		if obj:GetShortDescription() == "Deathless in the Dungeon" then
		-- 			SendVarToRover("deathless", obj)
		-- 		end
		-- 	end

		-- 	-- test purpose

		-- 	--local getObjectives = peUpdated:GetObjectives()
		-- 	--local timeinfo = string.format("getObjectives - %s", GameLib.GetGameTime())
		-- 	--SendVarToRover(timeinfo, getObjectives)

		-- end

	end -- if not in raid

end




function RIPgold:OnCombat(unitInCombat, bInCombat)

	if self.isInDungeon == true then 

		local unitInCombatName = unitInCombat:GetName()
		local unitInCombatDead = unitInCombat:IsDead()

		if bInCombat == true then
			for bossName,bossState in pairs(self.boss) do
				if bossName == unitInCombatName then
					self.boss[bossName] = true
					self:Debug(bossName .. " alive.")
				end
			end
		end

		-- proceeds on leaving combat
		if bInCombat == false then 

			-- boss leaving combat
			for bossName,bossState in pairs(self.boss) do
				if bossName == unitInCombatName then
					self.boss[bossName] = false
					self.alreadyFailedChallenge = false
					self:Debug(bossName .. " dead + reset.")
				end
			end

			-- info about fails at the end of the dungeon
			if unitInCombatDead == true then
				if unitInCombatName == "Stormtalon" then
					self:HowManyFails()
				end
				if unitInCombatName == "Spiritmother Selene the Corrupted" then
					self:HowManyFails()
				end
				if unitInCombatName == "Mordechai Redmoon" then
					self:HowManyFails()
				end
				if unitInCombatName == "Forgemaster Trogun" then
					self:HowManyFails()
				end
			end

			-- specific bosses

			if unitInCombatName == "Blade-Wind the Invoker" then
				if unitInCombatDead == true then
					self.helpers.doesChannelerExists:Stop()
				end
			end

			if unitInCombatName == "Stew-Shaman Tugga" then

				function IsTuggaStuffed()
				   local getBossBuffs = unitInCombat:GetBuffs().arBeneficial[1].splEffect:GetName() ~= nil
				end

				if pcall(IsTuggaStuffed) then

					local getBossBuffs = unitInCombat:GetBuffs().arBeneficial[1].splEffect:GetName()

					if getBossBuffs == "Devour Flesh" then

						local sToChat = "Stew-Shaman Tugga ate Devour Flesh during combat. The challenge is lost. Someone from this team can't interrupt at right time. Is that you, slacker?"
						self:AddFails()
						self:InformOthers(sToChat, true)
					end
				end
			end

			if unitInCombatName == "Forgemaster Trogun" then 
				if self.helpers.TrogunStacks > 0 then

					local sToChat = string.format("Forgemaster got %s stacks of Primal Rage. The challenge is lost.", self.helpers.TrogunStacks)
					self:AddFails()
					self:InformOthers(sToChat, true)
				end
			end


			if unitInCombatName == "Bosun Octog" then

				if self.helpers.OctogStacks < 10 then
					local sToChat = string.format("Bosun got %s from 10 stacks of Broken Armor. The challenge is lost.", self.helpers.OctogStacks)
					self:AddFails()
					self:InformOthers(sToChat, true)
				else 
					local sToChat = string.format("Bosun got %s stacks of Broken Armor. Well done!", self.helpers.OctogStacks)
					self:InformOthers(sToChat, true)
				end

				
				--self:Debug(sToChat)
			end

			if unitInCombatName == "Deadringer Shallaos" then

				local failsInfo = ""
				for i=1,5 do

					if self.player[i].name ~= "" then

						local additionalComma = ""
						if i > 1 then
							additionalComma = ","
						end

						local failWord = "stacks"
						if self.helpers.ShallaosStacks[i] == 1 then
							failWord = "stack"
						end

						if self.helpers.ShallaosStacks[i] > 5 then -- counts as fails when you reach more than 5 stacks, because 25 stacks is limit per a group
							local countedFails = self.helpers.ShallaosStacks[i]
							countedFails = countedFails - 5
							local oldFails = self.player[i].fails
							self.player[i].fails = oldFails + countedFails
						end

						failsInfo = string.format("%s%s %s (%s %s)", failsInfo, additionalComma, self.player[i].name, self.helpers.ShallaosStacks[i], failWord)
					end
				end

				local sToChat = string.format("Who is the best player here? %s", failsInfo)
				--self:Debug(sToChat)
				self:InformOthers(sToChat, true)

				--SendVarToRover("self", self)
			end
		end
	end
end

function RIPgold:OnWorldChange()

	-- updated function: resets only info about match, not resetting everything every world change
	self.peMatch = nil
	self.isInDungeon = false
end


function RIPgold:OnCombatLogVitalModifier(tEventArgs)

	if self.isInDungeon == true then 

		local getCaster = tEventArgs.unitCaster:GetName()

		if getCaster == "Spiritmother Selene's Echo" then

			local SeleneHealth = tEventArgs.unitCaster:GetHealth()
			local SeleneMaxHealth = tEventArgs.unitCaster:GetMaxHealth()
			local SelenePercentage = SeleneHealth / SeleneMaxHealth
			self.helpers.SelenePercentage = SelenePercentage
		end

		if self.boss["Deadringer Shallaos"] == true then

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
								self.helpers.ShallaosStacks[1] = buff.nCount
							else
								for nGroupIndex=1,getGroupMaxSize do

									local getGroupMember = GroupLib.GetGroupMember(nGroupIndex); 
									if getGroupMember ~= nil then

										local getGroupMemberName = getGroupMember.strCharacterName
										if getGroupMemberName == getTarget then

											self.helpers.ShallaosStacks[nGroupIndex] = buff.nCount
										end
									end
								end
							end
						end
					end
				end
			end
		end


		if self.boss["Mordechai Redmoon"] == true then

			function IsTerablinded()
			   local getBossBuffs = tEventArgs.unitTarget:GetBuffs().arHarmful[1].strTooltip ~= nil
			end

			if pcall(IsTerablinded) then

				if tEventArgs.unitTarget:GetBuffs().arHarmful[1].strTooltip == "Blinded!" then

					local getTarget = tEventArgs.unitTarget:GetName()
					local sToChat = string.format("%s was blinded. Mordechai Redmoon's challenge is lost. Remember to always look out to prevent this!", getTarget)

					self:CountFails(getTarget)
					self:InformOthers(sToChat, true)

				end
			end
		end

		if self.boss["Bosun Octog"] == true then

			function IsBosunBroken()
			   local getBossBuffs = tEventArgs.unitCaster:GetBuffs().arHarmful[1].strTooltip ~= nil
			end

			if pcall(IsBosunBroken) then

				local getBossBuffs = tEventArgs.unitCaster:GetBuffs()
				if getBossBuffs.arHarmful[1].strTooltip == "Broken Armor" then
					self.helpers.OctogStacks = getBossBuffs.arHarmful[1].nCount
				end
			end
		end

		if self.boss["Forgemaster Trogun"] == true then  

			function IsForgemasterBuffed()
			   local BossBuffs = tEventArgs.unitCaster:GetBuffs().arBeneficial[1].strTooltip ~= nil
			end

			if pcall(IsForgemasterBuffed) then

				local getBossBuffs = tEventArgs.unitCaster:GetBuffs()

				if getBossBuffs.arBeneficial[1].strTooltip == "Primal Rage" then
					self.helpers.TrogunStacks = getBossBuffs.arBeneficial[1].nCount
				end
			end
		end
	end --in dungeon
end

function RIPgold:OnUnitCreated(unit)

	local getUnitName = unit:GetName()

	-- Warning! Checking for "Thundercall Channeler unit has to be before checking for dungeons because it happens before entring the dungeon in function OnPublicEventStatsUpdate() 
	if getUnitName == "Thundercall Channeler" then 
		self:STL_getChannelerID(unit)
	end

	if self.isInDungeon == true then 

		if getUnitName == "Spiritmother Selene" then

			local SelenePercentage = self.helpers.SelenePercentage * 100

			if (100 > SelenePercentage and SelenePercentage > 0) then
					
				local SelenePercentageString = string.format("%.f %%", SelenePercentage);
				local sToChat = string.format("Spiritmother was at %s health. Challenge is lost. She has to be full at the end of battle.", SelenePercentageString)
				self:AddFails()
				self:InformOthers(sToChat, true)
			end
		end

		if self.boss["Blade-Wind the Invoker"] == true then
			if getUnitName == "Hostile Invisible Unit for Fields (0 hit radius)" then
				--SendVarToRover("unit created ".. GameLib.GetGameTime(), unit)
				self.helpers.WindInvokerInvisibleUnitID = unit:GetId()
				self:STL_getPlayerWithCircle(unit)
				self.helpers.doesChannelerExists:Start()
			end
		end
	end --in dungeon
end

function RIPgold:STL_checkForChannelerDeaths()

	if self.isInDungeon == true then 

		for chanellerIndex=1,4 do

			function doesThundercallExist()
			   local getThundercallPosition = GameLib.GetUnitById(self.helpers.WindInvokerChanellerID[chanellerIndex]):IsDead() ~= nil
			end

			if pcall(doesThundercallExist) then
				local getThundercallPosition = GameLib.GetUnitById(self.helpers.WindInvokerChanellerID[chanellerIndex]):IsDead()
				if getThundercallPosition == true then
					self.helpers.WindInvokerChanellerID[chanellerIndex] = 0
					--self:Debug(chanellerIndex .. " invoker annulled")
				end
			end

		end
	end
end

function RIPgold:STL_getPlayerWithCircle(unit)
	
	local circlePosition = unit:GetPosition()

	local getGroupMaxSize = GroupLib.GetGroupMaxSize() -- its 5 when in group, 0 when alone
	if getGroupMaxSize == 0 then
		function GetPlayerName()
		   local getBossBuffs = GameLib.GetPlayerUnit(1):GetName() ~= nil
		end

		if pcall(GetPlayerName) then
			local getCurrentPlayerName = GameLib.GetPlayerUnit(1):GetName()
			local playerPosition = GameLib.GetPlayerUnit(1):GetPosition()

			self.helpers.WindInvokerTargetPlayer["name"] = getCurrentPlayerName
			self.helpers.WindInvokerTargetPlayer["x"] = playerPosition["x"]
			self.helpers.WindInvokerTargetPlayer["z"] = playerPosition["z"]
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

					self.helpers.WindInvokerDiffs[nGroupIndex] = diffs
				end
			end
		end
	
		local isNearest = self.helpers.WindInvokerDiffs[1]
		local isNearestPlayer = 1

		for nGroupIndex=1,getGroupMaxSize do
			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)

			if getGroupMember ~= nil then
				local getGroupMemberUnit = GroupLib.GetUnitForGroupMember(nGroupIndex)

				if getGroupMemberUnit ~= nil then
					local getGroupMemberName = getGroupMember.strCharacterName

					if self.helpers.WindInvokerDiffs[nGroupIndex] < isNearest then
						isNearest = self.helpers.WindInvokerDiffs[nGroupIndex]
						isNearestPlayer = nGroupIndex
					end
				end
			end
		end

		self.helpers.WindInvokerTargetPlayer["name"] = GroupLib.GetGroupMember(isNearestPlayer).strCharacterName
		local targetedPlayerPosition = GroupLib.GetUnitForGroupMember(isNearestPlayer):GetPosition()
		self.helpers.WindInvokerTargetPlayer["x"] = targetedPlayerPosition["x"]
		self.helpers.WindInvokerTargetPlayer["z"] = targetedPlayerPosition["z"]
	end
end

function RIPgold:STL_getChannelerID(unit)

	--SendVarToRover("STL_getChannelerID " .. GameLib.GetGameTime(),unit)

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
				self.helpers.WindInvokerChanellerID[numberID] = testedID
			end
		end
	end
end

function RIPgold:STL_getCircleDistances(unit)

	local shortestDistance = 999
	for n=1,4 do
		local actualDistance = self:STL_getCircleDistance(unit, n)

		--SendVarToRover("actualdistance: " .. GameLib.GetGameTime(),actualDistance)

		if actualDistance ~= nil then
			if actualDistance < shortestDistance then
				shortestDistance = actualDistance
			end
		end
	end

	if shortestDistance ~= 999 then 

		-- workaround with gametime to prevent "feature" when circle occurs two times at the same time
		local actualGametime = GameLib.GetGameTime()
		if self.helpers.WindInvokerLastGametime ~= actualGametime then

			local channelerRadius = 7.89 -- the best constant I've found after numbers of tries, still only guess, not real constant
			if shortestDistance > channelerRadius then

				local missedDistance = shortestDistance - channelerRadius
				missedDistance = Apollo.FormatNumber(missedDistance, 2, true)
				local sToChat = string.format("%s missed placing AOE by %s m.", self.helpers.WindInvokerTargetPlayer["name"], missedDistance)
				--self:Debug(sToChat)
				--self:InformOthers(sToChat, true)
				self:InformOthers(sToChat, false)
			else
				if shortestDistance > 7 then
					SendVarToRover("Channeler test distance "..GameLib.GetGameTime(), shortestDistance)
				end
			end
		end
		self.helpers.WindInvokerLastGametime = actualGametime

	end

end

function RIPgold:STL_getCircleDistance(unit, chanellerID)

	function doesThundercallExist()
	   local getBossBuffs = GameLib.GetUnitById(self.helpers.WindInvokerChanellerID[chanellerID]):GetPosition() ~= nil
	end

	if pcall(doesThundercallExist) then

		local circlePosition = unit:GetPosition()
		local channelerPosition = GameLib.GetUnitById(self.helpers.WindInvokerChanellerID[chanellerID]):GetPosition()

		local diff_x = math.abs(circlePosition["x"] - channelerPosition["x"])
		local diff_z = math.abs(circlePosition["z"] - channelerPosition["z"])
		local diffs = math.sqrt(math.pow(diff_x, 2) + math.pow(diff_z, 2))

		return diffs
	end
end

function RIPgold:OnUnitDestroyed(unit)

	if self.isInDungeon == true then

		local getUnitName = unit:GetName()

		if self.boss["Blade-Wind the Invoker"] == true then
			if getUnitName == "Hostile Invisible Unit for Fields (0 hit radius)" then
				local unitID = unit:GetId()
				--SendVarToRover("invisible unit".. GameLib.GetGameTime(), self.helpers.WindInvokerInvisibleUnitID)
				--SendVarToRover("unit destroyed ".. GameLib.GetGameTime(), unit)
				--SendVarToRover("Channelers exist.", self.helpers.WindInvokerChanellerID[1] .. " " .. self.helpers.WindInvokerChanellerID[2] .. " " .. self.helpers.WindInvokerChanellerID[3] .. " " .. self.helpers.WindInvokerChanellerID[4])

				if unitID == self.helpers.WindInvokerInvisibleUnitID then
					self:STL_getCircleDistances(unit)
				end
			end
		end
	end
end

function RIPgold:OnCombatLogDamage(tEventArgs)

	if self.isInDungeon == true then 

		local validTarget = tEventArgs.unitTarget ~= nil
		local validCaster = tEventArgs.unitCaster ~= nil
		local validSpell = tEventArgs.splCallingSpell:GetName() ~= nil
		if validTarget and validCaster and validSpell then

			local getCaster = tEventArgs.unitCaster:GetName()
			local getTarget = tEventArgs.unitTarget:GetName()
			local getSpell = tEventArgs.splCallingSpell:GetName()

			if tEventArgs.unitTarget:IsInYourGroup() or tEventArgs.unitTarget:IsThePlayer() then -- if target is in your party

				local getSpell = tEventArgs.splCallingSpell:GetName()
				local getCaster = tEventArgs.unitCaster:GetName()
				local getTarget = tEventArgs.unitTarget:GetName()

				--- Skullcano

				if getSpell == "Seismic Tremor" and getCaster == "Thunderfoot" then

					local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Is really that hard to jump?", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true)

				end

				if getSpell == "Dark Fireball" and getCaster == "Laveka the Dark-Hearted" then

					local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Come on, just evade small circular AOE, you are not that bad, are you?", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true)

				end

				--- Stormtalon's Lair

				if getCaster == "Blade-Wind the Invoker" then

					-- workaround, no clue why Invoker is exception from global boss incombat function, but it shouldnt fuck up with other things as well as it will be set false after he dies (which works)
					self.boss["Blade-Wind the Invoker"] = true

				end

				if getSpell == "Twister" and getCaster == "Aethros Twister" then

					local sToChat = string.format("%s was hit by %s. Aethros's challenge is lost. What's so problematic at dancing between tornados?", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true)
				end

				if getSpell == "Lightning Strike" and getCaster == "Stormtalon" then

					local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Remember! Run around after moo and don't stay in the middle of moving telegraph.", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true)

				end

				--- Sanctuary of the Swordmaiden

				if getCaster == "Deadringer Shallaos" then

					-- workaround, no clue why Shallaos is exception from global boss incombat function, but it shouldnt fuck up with other things as well as it will be set false after she dies (which works)
					self.boss["Deadringer Shallaos"] = true

				end

				if getSpell == "Molten Wave" and getCaster == "Rayna Darkspeaker" then

					local sToChat = string.format("%s was hit by %s. %s's challenge is lost. You are bad at dancing between fire walls.", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true)

				end

				if getSpell == "Plague Splatter" and getCaster == "Ondu Lifeweaver" then

					local sToChat = string.format("%s was hit by %s. %s's challenge is lost. You have to be blind to miss telegraph that big.", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true)

				end

				if getSpell == "Corruption Pustule" and getCaster == "Moldwood Swarmling" then

					local sToChat = string.format("%s was hit by %s. Vitara's heart challenge is lost. If you can't run, kill him in less than 60s.", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true)

				end

				if getTarget == "Spiritmother Selene's Echo" then

					local SeleneHealth = tEventArgs.unitTarget:GetHealth()
					local SeleneMaxHealth = tEventArgs.unitTarget:GetMaxHealth()
					local SelenePercentage = SeleneHealth / SeleneMaxHealth

					self.helpers.SelenePercentage = SelenePercentage
					self:Debug(string.format("%3.0f", SelenePercentage))

				end

				--- Ruins of the Kel Voreth


				if self.boss["Grond the Corpsemaker"] == true then

					if getSpell == "Bone Clamp" and getCaster == "Bone Cage" then

						local sToChat = string.format("%s felt into %s. Grond the Corpsemaker's challenge is lost. Can't you just look under your feet?", getTarget, getSpell, getCaster)
						self:CountFails(getTarget)
						self:InformOthers(sToChat, true)

					end

				end

				if getSpell == "Homing Barrage" and getCaster == "Slavemaster Drokk" then

					local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Come on, that AOE is smaller than Korean dick... How did you caught it?", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true)

				end

				if getSpell == "Phase Blast" and getCaster == "Eldan Phase Blaster" then

					local sToChat = string.format("%s was hit by %s. And obviously challenge is lost. Yeah, so you wanna get vaporized... And wanna fuck the most easiest challenge. Well done. Well done.", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true)

				end
			end
		end
	end -- in dungeon
end

function RIPgold:InformOthers(sToChat, setFailedChallenge)

	if self.alreadyFailedChallenge == false then

		self:SendToChat(sToChat)

		if setFailedChallenge == true then
			self.alreadyFailedChallenge = true
		else
			self.alreadyFailedChallenge = false
		end
	end
end

function RIPgold:SendToChat(fnString)
	if GroupLib.InInstance() then
		ChatSystemLib.Command("/i "..fnString)
	elseif GroupLib.InGroup() then
		ChatSystemLib.Command("/p "..fnString)
		--self:Debug(fnString)
	else
		self:Debug(fnString)
	end
end

function RIPgold:Debug(fnString)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, fnString, "RIPgold")
end

function RIPgold:CountFails(getTarget)
	local getGroupMaxSize = GroupLib.GetGroupMaxSize() -- its 5 when in group, 0 when alone

	if getGroupMaxSize == 0 then

		local getFailsOld = self.player[1].fails
		self.player[1].fails = getFailsOld + 1
	else
		for nGroupIndex=1,getGroupMaxSize do 

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then

				local getGroupMemberName = getGroupMember.strCharacterName
				if getGroupMemberName == getTarget then

					local getFailsOld = self.player[nGroupIndex].fails
					self.player[nGroupIndex].fails = getFailsOld + 1
				end
			end
		end
	end
end

function RIPgold:AddFails()
	local getGroupMaxSize = GroupLib.GetGroupMaxSize() -- its 5 when in group, 0 when alone

	if getGroupMaxSize == 0 then

		local getFailsOld = self.player[1].fails
		self.player[1].fails = getFailsOld + 1
	else
		for nGroupIndex=1,getGroupMaxSize do

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then

				local getFailsOld = self.player[nGroupIndex].fails
				self.player[nGroupIndex].fails = getFailsOld + 1
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- RIPgoldForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function RIPgold:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function RIPgold:OnCancel()
	self.wndMain:Close() -- hide the window
end


-----------------------------------------------------------------------------------------------
-- RIPgold Instance
-----------------------------------------------------------------------------------------------
local RIPgoldInst = RIPgold:new()
RIPgoldInst:Init()
