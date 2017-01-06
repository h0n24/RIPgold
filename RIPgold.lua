-----------------------------------------------------------------------------------------------
-- Client Lua Script for RIPgold
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

-- todo (no clue how to): check if mordechai is being blinded
-- todo (no clue how to): last boss in ssm
-- todo: SSM: reminder after 15s that you forgot to pick first relic in SSM, unit name: Spirit Relic of Blood
-- todo: some spells are counting twice or more per second, make a timer for every spell to add one failpoint once per two seconds (bugging bosses -> mordechai)
-- todo: SSM: write whisp message to people who are dead after 2s after spirit relics being placed "you can rezz up"

require "Apollo"
require "Window"
require "GroupLib"
require "GameLib"
 
-----------------------------------------------------------------------------------------------
-- RIPgold Module Definition
-----------------------------------------------------------------------------------------------
local RIPgold = {}

-- modules for specific dungeons
local ALL = Apollo.GetPackage("Module:ALL-1.0").tPackage
local STL = Apollo.GetPackage("Module:STL-1.0").tPackage
local KV = Apollo.GetPackage("Module:KV-1.0").tPackage
local SSM = Apollo.GetPackage("Module:SSM-1.0").tPackage
local SC = Apollo.GetPackage("Module:SC-1.0").tPackage
 
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
    self.tSavedVariables = {}
	self.hlp = {} -- all helpers
	self.set = {} -- all settings
	self.rat = {}

    return o
end

function RIPgold:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- RIPgold OnLoad
-----------------------------------------------------------------------------------------------
function RIPgold:OnLoad()
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

		Apollo.RegisterEventHandler("WindowMove", "OnWindowSizeChanged", self)

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

		-- updating ui every second when opened
		self.updateStatsUI = ApolloTimer.Create(1, true, "UpdateRIPgoldStatsUI", self)
		self.updateStatsUI:Stop()

		self.hlp.isBossDead = {}
		self.hlp.isBossDead.timer = ApolloTimer.Create(1, true, "ALL_checkForBossDeaths", self)
		self.hlp.isBossDead.timer:Stop()
		self.hlp.isBossDead.ID = 0
		self.hlp.isBossDead.name = ""
		self.hlp.isBossDead.dead = false

		self.hlp.doesChannelerExists = ApolloTimer.Create(1, true, "STL:checkForChannelerDeaths(self)", self)
		self.hlp.doesChannelerExists:Stop()

		if self.tSavedVariables == nil then

			self.hlp.peMatch = nil
			self.hlp.isInDungeon = false

			self:InitializeVars()

			if not GroupLib.InRaid() then
				self:PreparePlayers()
			end

			self.set.sound = true
			-- additional sounds: self:PlaySound(Sound.PlayUIQueuePopsAdventure)
			-- additional sounds: self:PlaySound(Sound.PlayUI47CancelVirtual)
			self.set.soundType = Sound.PlayUI11To13GenericPushButtonDigital02
		end

		if self.rat == nil then
			local getCurrentPlayerName = GameLib.GetPlayerUnit(1):GetName()
			self.rat[getCurrentPlayerName] = {}
			self.rat[getCurrentPlayerName]["fails"] = 0
			self.rat[getCurrentPlayerName]["rating"] = 1000
			self.rat[getCurrentPlayerName]["dungs"] = 0
		end

		--- testing purposes
		--self.hlp.isInDungeon = true
		--self.hlp.boss["Blade-Wind the Invoker"] = true


	end
end

-----------------------------------------------------------------------------------------------
-- RIPgold Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- icon for interface menu
function RIPgold:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "RIPgold", {"ToggleRIPgoldUI", "", ""}) --IconSprites:Icon_Windows_UI_CRB_Rival icon before (terrible meh)
end

function RIPgold:addToSet(set, key) -- not using, future reference
    set[key] = true
end

function RIPgold:removeFromSet(set, key) -- not using, future reference
    set[key] = nil
end

function RIPgold:setContains(set, key)
    return set[key] ~= nil
end

-- on SlashCommand "/rip"
function RIPgold:OnRIPgoldOn()

	self.updateStatsUI:Start()

	self:UpdateRIPgoldStatsUI()
	self:OnBTN_statsClick() --instead of self.wndMain:FindChild("WRAP_FAILS"):ArrangeChildrenVert(0)

	self.wndMain:Invoke() -- show the window

	SendVarToRover("self.tSavedVariables",self.tSavedVariables)

	--SendVarToRover("self.rat",self.tSavedVariables)

	--table.insert("test", self.rat)	

	--self:Debug(self.hlp.player[1].name .. ": " .. self.hlp.player[1].fails)
	--self:Debug(self.hlp.player[2].name .. ": " .. self.hlp.player[2].fails)
	--self:Debug(self.hlp.player[3].name .. ": " .. self.hlp.player[3].fails)
	--self:Debug(self.hlp.player[4].name .. ": " .. self.hlp.player[4].fails)
	--self:Debug(self.hlp.player[5].name .. ": " .. self.hlp.player[5].fails)

end

function RIPgold:HowManyFails()

	self:InformOthers("So, how many fails did you do this dungeon?", false)

	for i=1,5 do
		if self.hlp.player[i].name ~= "" then
			self:InformOthers(self.hlp.player[i].name .. ": " .. self.hlp.player[i].fails, false)
		end
	end

	-- new function new rat
	for i=1,5 do
		if self.hlp.player[i].name ~= "" then

			-- human readable fails
			local failWord = "fails"
			if self.hlp.player[i].fails == 1 then
				failWord = "fail"
			end

			-- supernew function
			--if self.rat ~= nil then
			if RIPgold:setContains(self.rat, self.hlp.player[i].name) then
				
				local rating = self.rat[self.hlp.player[i].name]["rating"]
				if self.hlp.player[i].fails > 0 then
					rating = rating - self.hlp.player[i].fails
				else
					rating = rating + 50
				end

				self.rat[self.hlp.player[i].name]["fails"] = self.rat[self.hlp.player[i].name]["fails"] + self.hlp.player[i].fails
				self.rat[self.hlp.player[i].name]["rating"] = rating
				self.rat[self.hlp.player[i].name]["dungs"] = self.rat[self.hlp.player[i].name]["dungs"] + 1
			else

				local rating = 1000
				if self.hlp.player[i].fails > 0 then
					rating = rating - self.hlp.player[i].fails
				else
					rating = rating + 50
				end

				self.rat[self.hlp.player[i].name] = {}
				self.rat[self.hlp.player[i].name]["fails"] = self.hlp.player[i].fails
				self.rat[self.hlp.player[i].name]["rating"] = rating
				self.rat[self.hlp.player[i].name]["dungs"] = 1
			end
			--end

			sToChat = string.format("%s %s, %s rating", self.hlp.player[i].fails, failWord, self.rat[self.hlp.player[i].name]["rating"])
			self:Debug(self.hlp.player[i].name .. ": ".. sToChat)
		end
	end

	SendVarToRover("self.rat",self.rat)


end

function RIPgold:InitializeVars()

	self.hlp.alreadyFailedChallenge = false
	self.hlp.alreadyFailedDeathless = false

	self.hlp.boss = {
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
		["Wrathbone"] = false,
	}

	self.hlp.SelenePercentage = 0
	self.hlp.TrogunStacks = 0
	self.hlp.OctogStacks = 0
	self.hlp.ShallaosStacks = { 
		[1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, 
	}
	self.hlp.WindInvokerTargetPlayer = {
		["name"] = "", ["x"] = 0, ["y"] = 0, ["z"] = 0,
	}

	self.hlp.WindInvokerDiffs = { 
		[1] = 0, [2] = 0, [3] = 0, [4] = 0 
	}

	self.hlp.WindInvokerInvisibleUnitID = 0

	self.hlp.WindInvokerLastGametime = GameLib.GetGameTime() 

end

function RIPgold:PreparePlayers()

	self.hlp.player = {
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
			self.hlp.player[1].name = getCurrentPlayerName
		end

	else

		for nGroupIndex=1,getGroupMaxSize do 

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then

				local getGroupMemberName = getGroupMember.strCharacterName
				self.hlp.player[nGroupIndex].name = getGroupMemberName
			end
		end
	end
end

function RIPgold:CheckForPlayerDeaths()

	if self.hlp.isInDungeon then 

		for nGroupIndex=1,GroupLib.GetGroupMaxSize() do
			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)

			if getGroupMember ~= nil then

				local getGroupMemberUnit = GroupLib.GetUnitForGroupMember(nGroupIndex)

				if getGroupMemberUnit ~= nil then
					local getDeathState = getGroupMemberUnit:IsDead()
					local getGroupMemberName = getGroupMember.strCharacterName

					if getDeathState then
						if self.hlp.player[nGroupIndex].dead == false then

							if self.hlp.alreadyFailedDeathless == false then
								local getDeadPlayerName = getGroupMemberUnit:GetName()
								local sToChat = string.format("%s just fucked up deathless challenge. RIPgold. :(.", getDeadPlayerName)
								self:InformOthers(sToChat, false, true)
								self:Debug(getGroupMemberUnit:GetName() .. " just fucked deathless.")
								self.hlp.alreadyFailedDeathless = true
							end

							self:Debug(getGroupMemberUnit:GetName() .. " is dead.")
							self.hlp.player[nGroupIndex].dead = true
							self:CountFails(getGroupMemberName)

						end
					else
						if self.hlp.player[nGroupIndex].dead then

							self:Debug(getGroupMemberUnit:GetName() .. " is alive.")
							self.hlp.player[nGroupIndex].dead = false
						end
					end
				end
			end
		end
	end
end

function RIPgold:OnPublicEventStart()

	if self.hlp.peMatch then
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

				self.hlp.isInDungeon = true

				self:InitializeVars()
				self:PreparePlayers()

				self.checkDeadState:Start()
					
				self.hlp.peMatch = true

				SendVarToRover("self", self)
				
				return true
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

			self.hlp.isInDungeon = true
			self.checkDeadState:Start()

			local nCurrentPoints = peUpdated:GetStat(PublicEvent.PublicEventStatType.MedalPoints)
			if self.hlp.nPoints == nCurrentPoints then
				return
			end

			--SendVarToRover("self", self)

			-- code connected with event points

				--local timeinfo = string.format("OnPublicEventStatsUpdate - %s", GameLib.GetGameTime())
				--SendVarToRover(timeinfo, peUpdated)

		end

		function IsPeObjectives()
		   local getPeObjectives = peUpdated:GetObjectives() ~= nil
		end

		if pcall(IsPeObjectives) then

			-- technically all event points
			local objectives = peUpdated:GetObjectives()

			for i,obj in pairs(objectives) do
				if obj:GetShortDescription() == "Deathless in the Dungeon" then
					SendVarToRover("deathless", obj)
				end
			end

			-- test purpose

			--local getObjectives = peUpdated:GetObjectives()
			--local timeinfo = string.format("getObjectives - %s", GameLib.GetGameTime())
			--SendVarToRover(timeinfo, getObjectives)

		end

	end -- if not in raid

end

function RIPgold:OnWorldChange()

	-- updated function: resets only info about match, not resetting everything every world change
	self.hlp.peMatch = nil
	self.hlp.isInDungeon = false
end

function RIPgold:OnCombat(unitInCombat, bInCombat)

	if self.hlp.isInDungeon then 
		local unitInCombatName = unitInCombat:GetName()

		if bInCombat then
			for bossName,bossState in pairs(self.hlp.boss) do
				if bossName == unitInCombatName then
					self.hlp.boss[bossName] = true
					-- info about fails at the end of the dungeon -> starts timer when these names occurs
					self:ALL_precheckForBossDeaths(unitInCombat)
					self:Debug(bossName .. " alive.")
				end
			end

			KV:OnCombat_IN(self, unitInCombat)
			SSM:OnCombat_IN(self, unitInCombat)
		end

		-- proceeds on leaving combat
		if not bInCombat then
			KV:OnCombat_OUT(self, unitInCombat)
			SSM:OnCombat_OUT(self, unitInCombat)
			SC:OnCombat_OUT(self, unitInCombat)		

			-- boss leaving combat
			for bossName,bossState in pairs(self.hlp.boss) do
				if bossName == unitInCombatName then
					self.hlp.boss[bossName] = false
					self.hlp.alreadyFailedChallenge = false
					self:Debug(bossName .. " out of combat.")
				end
			end
		end
	end
end

function RIPgold:OnCombatLogVitalModifier(tEventArgs)

	if self.hlp.isInDungeon then 
		SSM:OnCombatLogVitalModifier(self, tEventArgs)
		KV:OnCombatLogVitalModifier(self, tEventArgs)
		SC:OnCombatLogVitalModifier(self, tEventArgs)
	end
end

function RIPgold:OnUnitCreated(unit)

	STL:OnUnitCreatedBeforeEnteringDungeon(self, unit) -- ! has to be outside hlp.isInDungeon
	if self.hlp.isInDungeon then

		STL:OnUnitCreated(self, unit)
		SSM:OnUnitCreated(self, unit)
	end
end

function RIPgold:ALL_precheckForBossDeaths(unitInCombat)
	if self.hlp.isInDungeon then 
		self.hlp.isBossDead.dead = false
		self.hlp.isBossDead.name = unitInCombat:GetName()
		self.hlp.isBossDead.ID = unitInCombat:GetId()
		self.hlp.isBossDead.timer:Start()
	end
end

function RIPgold:ALL_checkForBossDeaths()
	if self.hlp.isInDungeon then 

		function doesBossExist()
		   local isBossDead = GameLib.GetUnitById(self.hlp.isBossDead.ID):IsDead() ~= nil
		end

		if pcall(doesBossExist) then
			local isBossDead = GameLib.GetUnitById(self.hlp.isBossDead.ID):IsDead()
			if isBossDead then
				self.hlp.isBossDead.dead = true
				self.hlp.isBossDead.timer:Stop()

				if self.hlp.isBossDead.name == "Stormtalon" then
					self:HowManyFails()
				end
				if self.hlp.isBossDead.name == "Spiritmother Selene the Corrupted" then
					self:HowManyFails()
				end
				if self.hlp.isBossDead.name == "Mordechai Redmoon" then
					self:HowManyFails()
				end
				if self.hlp.isBossDead.name == "Forgemaster Trogun" then
					self:HowManyFails()
				end
				if self.hlp.isBossDead.name == "Wrathbone" then
					--self:HowManyFails()
				end
				if self.hlp.isBossDead.name == "Blade-Wind the Invoker" then
					self.hlp.doesChannelerExists:Stop() --test if its working
				end
				if self.hlp.isBossDead.name == "Bosun Octog" then
					if self.hlp.OctogStacks < 10 then
						local sToChat = string.format("Bosun got %s from 10 stacks of Broken Armor. The challenge is lost.", self.hlp.OctogStacks)
						self:AddFails()
						self:InformOthers(sToChat, false, false)
					end
				end

				self:Debug(self.hlp.isBossDead.name .. " is dead.")
				--SendVarToRover("boss", self.hlp.isBossDead)
			end
		end
	end
end

function RIPgold:OnUnitDestroyed(unit)

	if self.hlp.isInDungeon then
		STL:OnUnitDestroyed(self, unit)
	end
end

function RIPgold:OnCombatLogDamage(tEventArgs)

	if self.hlp.isInDungeon then 

		local validTarget = tEventArgs.unitTarget ~= nil
		local validCaster = tEventArgs.unitCaster ~= nil
		local validSpell = tEventArgs.splCallingSpell:GetName() ~= nil
		if validTarget and validCaster and validSpell then

			if tEventArgs.unitTarget:IsInYourGroup() or tEventArgs.unitTarget:IsThePlayer() then -- if target is in your party

				SC:OnCombatLogDamage(self, tEventArgs)
				STL:OnCombatLogDamage(self, tEventArgs)
				SSM:OnCombatLogDamage(self, tEventArgs)
				KV:OnCombatLogDamage(self, tEventArgs)
			end
		end
	end
end

function RIPgold:InformOthers(sToChat, setFailedChallenge, overrideGlobalVar)

	if not overrideGlobalVar then
		if not self.hlp.alreadyFailedChallenge then

			self:SendToChat(sToChat)

			if setFailedChallenge then
				self.hlp.alreadyFailedChallenge = true
			else
				self.hlp.alreadyFailedChallenge = false
			end
		end
	else
		self:SendToChat(sToChat)

		if setFailedChallenge then
			self.hlp.alreadyFailedChallenge = true
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
		ChatSystemLib.Command("/s "..fnString)
		--self:Debug(fnString)
	end
end

function RIPgold:PlaySound(sound)
	if self.set.sound then
		Sound.Play(sound)
	end
end

function RIPgold:Debug(fnString)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, fnString, "RIPgold")
end

function RIPgold:CountFails(getTarget)

	-- sounds when player fails
	local getCurrentPlayerName = GameLib.GetPlayerUnit(1):GetName()
	if getTarget == getCurrentPlayerName then
		self:PlaySound(self.set.soundType)
	end

	-- counting fails
	local getGroupMaxSize = GroupLib.GetGroupMaxSize() -- its 5 when in group, 0 when alone

	if getGroupMaxSize == 0 then

		local getFailsOld = self.hlp.player[1].fails
		self.hlp.player[1].fails = getFailsOld + 1
	else
		for nGroupIndex=1,getGroupMaxSize do 

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then

				local getGroupMemberName = getGroupMember.strCharacterName
				if getGroupMemberName == getTarget then

					local getFailsOld = self.hlp.player[nGroupIndex].fails
					self.hlp.player[nGroupIndex].fails = getFailsOld + 1
				end
			end
		end
	end
end

function RIPgold:AddFails()
	local getGroupMaxSize = GroupLib.GetGroupMaxSize() -- its 5 when in group, 0 when alone

	if getGroupMaxSize == 0 then

		local getFailsOld = self.hlp.player[1].fails
		self.hlp.player[1].fails = getFailsOld + 1
	else
		for nGroupIndex=1,getGroupMaxSize do

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then

				local getFailsOld = self.hlp.player[nGroupIndex].fails
				self.hlp.player[nGroupIndex].fails = getFailsOld + 1
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- RIPgoldForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function RIPgold:OnOK() -- not being used, all things save real time
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function RIPgold:OnCancel()
	self.wndMain:Close() -- hide the window
	self.updateStatsUI:Stop()
end

function RIPgold:UI_show_findPlayers(showOrNot)
	self.wndMain:FindChild("INFO_findPlayers"):Show(showOrNot)
	self.wndMain:FindChild("WRAP_findPlayers_announce"):Show(showOrNot)
	self.wndMain:FindChild("WRAP_findPlayers_settings"):Show(showOrNot)
end

function RIPgold:UpdateRIPgoldStatsUI()
	self.wndMain:FindChild("TABLE_stats"):DeleteAll()

	if self.hlp.isInDungeon then
		self:UI_show_findPlayers(false)
	else
		local memberCount = GroupLib.GetMemberCount()
		if memberCount == 0 then
			self.hlp.lastMemberCount = 0
		elseif memberCount < 5 then
			--if self.hlp.lastMemberCount < memberCount then
				self:PreparePlayers()
				self:UpdateAnnounceUI()
				self:UI_show_findPlayers(true)
				--self.hlp.lastMemberCount = memberCount
			--end
			self.hlp.lastMemberCount = memberCount
		elseif memberCount == 5 then
			if self.hlp.lastMemberCount ~= memberCount then
				self:PreparePlayers()
				self:UpdateAnnounceUI()
				self:UI_show_findPlayers(true)
				--self.hlp.lastMemberCount = memberCount
			else
				self:UpdateAnnounceUI()
				self:UI_show_findPlayers(false)
			end
			self.hlp.lastMemberCount = memberCount
		else
			self:UI_show_findPlayers(false)
			self.hlp.lastMemberCount = 5
		end
	end

	local rowsNumber = 0
	for i=1,5 do
		if self.hlp.player == nil then
			self:PreparePlayers()
		else
			if self.hlp.player[i].name ~= "" then

				rowsNumber = rowsNumber + 1
				local tRow = self.wndMain:FindChild("TABLE_stats"):AddRow("")
		    	self.wndMain:FindChild("TABLE_stats"):SetCellText(tRow, 1, self.hlp.player[i].name)

		    	function GetRating()
			   		local testVar = self.rat[self.hlp.player[i].name]["rating"] ~= nil
				end

				if pcall(GetRating) then
					local rating = self.rat[self.hlp.player[i].name]["rating"] / 100
					local rating = string.format("%2.0f", self.rat[self.hlp.player[i].name]["rating"] / 100)

					self.wndMain:FindChild("TABLE_stats"):SetCellText(tRow, 2,  rating)
				else
					self.wndMain:FindChild("TABLE_stats"):SetCellText(tRow, 2, "0")
				end

		    	self.wndMain:FindChild("TABLE_stats"):SetCellText(tRow, 3, self.hlp.player[i].fails)
			end
		end
	end

	local tableWidth = self.wndMain:GetWidth() - 70
	local tableHeight = rowsNumber*25 + 30
    self.wndMain:FindChild("TABLE_stats"):SetAnchorOffsets(10,0,tableWidth,tableHeight)

	self.wndMain:FindChild("WIN_stats"):ArrangeChildrenVert(0)

end

function RIPgold:UpdateAnnounceUI()
	if self.set.CHCK_PLZ_dps == true then
		self.wndMain:FindChild("CHCK_PLZ_dps"):SetCheck(self.set.CHCK_PLZ_dps)
	else
		--self.wndMain:FindChild("CHCK_PLZ_dps"):SetCheck(false)
	end

	if self.set.CHCK_PLZ_heal == true then
		self.wndMain:FindChild("CHCK_PLZ_heal"):SetCheck(self.set.CHCK_PLZ_heal)
	else
		--self.wndMain:FindChild("CHCK_PLZ_heal"):SetCheck(false)
	end

	if self.set.CHCK_PLZ_tank == true then
		self.wndMain:FindChild("CHCK_PLZ_tank"):SetCheck(self.set.CHCK_PLZ_tank)
	else
		--self.wndMain:FindChild("CHCK_PLZ_tank"):SetCheck(false)
	end

	self.set.CHCK_PLZ_dps = self.wndMain:FindChild("CHCK_PLZ_dps"):IsChecked()
	self.set.CHCK_PLZ_heal = self.wndMain:FindChild("CHCK_PLZ_heal"):IsChecked()
	self.set.CHCK_PLZ_tank = self.wndMain:FindChild("CHCK_PLZ_tank"):IsChecked()



	local announcingText = "/n " --longest: /n LFxM for vets, 10k+ dps or 6k+ heal or tanking class

	local memberCount = GroupLib.GetMemberCount()
	local missingMembers = 0

	if memberCount == 0 then
		missingMembers = ""
		announcingText = self:UpdateAnnounceTextBase(announcingText,missingMembers)

	elseif memberCount < 5 then
		missingMembers = 5 - memberCount
		announcingText = self:UpdateAnnounceTextBase(announcingText,missingMembers)

	else
		announcingText = announcingText .. "full"
	end

	self.wndMain:FindChild("BOX_announce"):SetText(announcingText)
end

function RIPgold:UpdateAnnounceTextBase(announcingText, missingMembers)

	announcingText = announcingText .. "LF"..missingMembers.."M for vets"

	if self.set.COMB_roleIndex == 1 then
		announcingText = announcingText .. ", " .. self.set.BOX_announce[self.set.COMB_roleIndex] .. "RR"  -- example: 10RR
	elseif self.set.COMB_roleIndex == 3 then
		announcingText = announcingText .. ", " .. self.set.BOX_announce[self.set.COMB_roleIndex] .. "+ ilvl" -- example: 100+ ilvl
	end

	if self.set.CHCK_PLZ_dps == true or self.set.CHCK_PLZ_heal == true or self.set.CHCK_PLZ_tank == true then
		announcingText = announcingText .. ", "
	end

	if self.set.CHCK_PLZ_dps == true then
		if self.set.COMB_roleIndex == 2 then
			announcingText = announcingText .. self.set.BOX_announce[self.set.COMB_roleIndex] .. "k+ " -- example: 10k+ 
		end
		announcingText = announcingText .. "dps"
	end

	if self.set.CHCK_PLZ_dps == true and self.set.CHCK_PLZ_heal == true then
		announcingText = announcingText .. " or "
	end

	if self.set.CHCK_PLZ_dps == true and self.set.CHCK_PLZ_tank == true then
		if self.set.CHCK_PLZ_heal == false then
			announcingText = announcingText .. " or "
		end
	end

	if self.set.CHCK_PLZ_heal == true then
		if self.set.COMB_roleIndex == 2 then
			announcingText = announcingText .. "6k+ "
		end
		announcingText = announcingText .. "heal"
	end

	if self.set.CHCK_PLZ_heal == true and self.set.CHCK_PLZ_tank == true then
		announcingText = announcingText .. " or "
	end

	if self.set.CHCK_PLZ_tank == true then
		announcingText = announcingText .. "tanking class"
	end

	return announcingText
end

-- when top buttons (cards) are clicked
function RIPgold:OnBTN_statsClick()
	self.wndMain:FindChild("WIN_stats"):Show(true)
	self.wndMain:FindChild("WIN_ratings"):Show(false)
	self.wndMain:FindChild("WIN_custom"):Show(false)
	self.wndMain:FindChild("WIN_settings"):Show(false)

	self.wndMain:FindChild("TOP_BG_stats"):SetBGColor("ef000000")
	self.wndMain:FindChild("TOP_BG_ratings"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_custom"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_settings"):SetBGColor("99000000")

	if self.hlp.isInDungeon then
		self.wndMain:FindChild("INFO_stats"):SetText("Current dungeon")
	else
		self.wndMain:FindChild("INFO_stats"):SetText("Last dungeon")
	end

	self.wndMain:FindChild("TABLE_stats"):DeleteAll()
	local rowsNumber = 0
	for i=1,5 do
		if self.hlp.player[i].name ~= "" then
			rowsNumber = rowsNumber + 1
			local tRow = self.wndMain:FindChild("TABLE_stats"):AddRow("")
	    	self.wndMain:FindChild("TABLE_stats"):SetCellText(tRow, 1, self.hlp.player[i].name)

	    	function GetRating()
		   		local testVar = self.rat[self.hlp.player[i].name]["rating"] ~= nil
			end

			if pcall(GetRating) then
				local rating = self.rat[self.hlp.player[i].name]["rating"] / 100
				local rating = string.format("%2.0f", self.rat[self.hlp.player[i].name]["rating"] / 100)

				self.wndMain:FindChild("TABLE_stats"):SetCellText(tRow, 2,  rating)
			else
				self.wndMain:FindChild("TABLE_stats"):SetCellText(tRow, 2, "0")
			end
	    	self.wndMain:FindChild("TABLE_stats"):SetCellText(tRow, 3, self.hlp.player[i].fails)
		end
	end

	local tableWidth = self.wndMain:GetWidth() - 50
	local tableHeight = rowsNumber*25 + 30
    self.wndMain:FindChild("TABLE_stats"):SetAnchorOffsets(10,0,tableWidth,tableHeight)

	self.wndMain:FindChild("WIN_stats"):ArrangeChildrenVert(0)

	--- announcing to nexus
	self.wndMain:FindChild("COMB_role"):DeleteAll()
	self.wndMain:FindChild("COMB_role"):AddItem("anyone", "test", nil)
	self.wndMain:FindChild("COMB_role"):AddItem("rating", "test", nil)
	self.wndMain:FindChild("COMB_role"):AddItem("k+ dps", "test", nil)
	self.wndMain:FindChild("COMB_role"):AddItem("ilvl", "test", nil)

	if not self.set.COMB_roleIndex then
		-- set original values
		self.wndMain:FindChild("COMB_role"):SelectItemByIndex(0) -- original pick: anyone
		self.wndMain:FindChild("BOX_BG_targetPerformance"):Show(false)
		self.set.BOX_announce = { 
			[1] = "10", [2] = "10", [3] = "100",
		}

	else
		self.wndMain:FindChild("COMB_role"):SelectItemByIndex(self.set.COMB_roleIndex)

		if self.set.COMB_roleIndex == 0 then
			self.wndMain:FindChild("BOX_BG_targetPerformance"):Show(false)
		else
			local BOX_announce_value = self.set.BOX_announce[self.set.COMB_roleIndex]
			self.wndMain:FindChild("BOX_BG_targetPerformance"):FindChild("BOX_announce"):SetText(BOX_announce_value)

			self.wndMain:FindChild("BOX_BG_targetPerformance"):Show(true)
		end
	end

	self.wndMain:FindChild("WRAP_findPlayers_checkboxes"):ArrangeChildrenHorz(0)

	self:UpdateAnnounceUI()

	-- workaround for a wildstar bug with not opening combat boxes, continues with :onCOMB_roleOutsideClick()
	self.wndMain:FindChild("COMB_role"):GetChildren()[1]:Show(false)

	-- workaround for making arrow near COMB_role less visible (not possible via Houston)
	self.wndMain:FindChild("COMB_role"):GetChildren()[2]:SetBGColor("99ffffff")

	--self:Debug("GetMemberCount ".. GroupLib.GetMemberCount())

end

function RIPgold:onBOX_announceChange(e)
	self.set.BOX_announce[self.set.COMB_roleIndex] = e:GetText()
	self:UpdateAnnounceUI()
end

function RIPgold:onCOMB_roleOutsideClick()
	self.wndMain:FindChild("COMB_role"):GetChildren()[1]:Show(false)
end

function RIPgold:onCOMB_roleClick()
	local getIndex = self.wndMain:FindChild("COMB_role"):GetSelectedIndex()
	self.set.COMB_roleIndex = getIndex

	if self.set.COMB_roleIndex == 0 then
		self.wndMain:FindChild("BOX_BG_targetPerformance"):Show(false)
	else

		local BOX_announce_value = self.set.BOX_announce[self.set.COMB_roleIndex]
		self.wndMain:FindChild("BOX_BG_targetPerformance"):FindChild("BOX_announce"):SetText(BOX_announce_value)

		self.wndMain:FindChild("BOX_BG_targetPerformance"):Show(true)
	end

	self:UpdateAnnounceUI()
end

function RIPgold:onBTN_announceClick()
	local announce = self.wndMain:FindChild("BOX_announce"):GetText()
	ChatSystemLib.Command(announce)

	-- set open group
	GroupLib.SetJoinRequestMethod(GroupLib.InvitationMethod.Open)

	-- set open referrals
	GroupLib.SetReferralMethod(GroupLib.InvitationMethod.Open)
end

function RIPgold:CHCK_PLZ_dpsClick()
	self.set.CHCK_PLZ_dps = self.wndMain:FindChild("CHCK_PLZ_dps"):IsChecked()
	self:UpdateAnnounceUI()
end

function RIPgold:CHCK_PLZ_healClick()
	self.set.CHCK_PLZ_heal = self.wndMain:FindChild("CHCK_PLZ_heal"):IsChecked()
	self:UpdateAnnounceUI()
end

function RIPgold:CHCK_PLZ_tankClick()
	self.set.CHCK_PLZ_tank = self.wndMain:FindChild("CHCK_PLZ_tank"):IsChecked()
	self:UpdateAnnounceUI()
end

function RIPgold:OnWindowSizeChanged()
	self:Debug("window changed")
	RIPgold:OnSizeChange_rating(self)
end

function RIPgold:OnSizeChange_rating(self)
	local rowsNumber = self.wndMain:FindChild("TABLE_rating"):GetRowCount()
	local tableWidth = self.wndMain:GetWidth() - 50
	local tableHeight = rowsNumber*25 + 30

	--self.wndMain:FindChild("TABLE_rating"):SetColumnWidth(1, tableWidth*0.6)
	--self.wndMain:FindChild("TABLE_rating"):SetColumnWidth(2, tableWidth*0.2)
	--self.wndMain:FindChild("TABLE_rating"):SetColumnWidth(3, tableWidth*0.2)
    self.wndMain:FindChild("TABLE_rating"):SetAnchorOffsets(10,0,tableWidth,tableHeight)
end

function RIPgold:OnBTN_ratingsClick()
	self.wndMain:FindChild("WIN_stats"):Show(false)
	self.wndMain:FindChild("WIN_ratings"):Show(true)
	self.wndMain:FindChild("WIN_custom"):Show(false)
	self.wndMain:FindChild("WIN_settings"):Show(false)

	self.wndMain:FindChild("TOP_BG_stats"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_ratings"):SetBGColor("ef000000")
	self.wndMain:FindChild("TOP_BG_custom"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_settings"):SetBGColor("99000000")

	
	self.wndMain:FindChild("TABLE_rating"):DeleteAll()
    for index,data in pairs(self.rat) do
    	--rowsNumber = rowsNumber + 1
		local tRow = self.wndMain:FindChild("TABLE_rating"):AddRow("")
	    self.wndMain:FindChild("TABLE_rating"):SetCellText(tRow, 1, index)

	    local rating = string.format("%2.0f", data["rating"] / 100)
	    self.wndMain:FindChild("TABLE_rating"):SetCellText(tRow, 2, rating)
	    self.wndMain:FindChild("TABLE_rating"):SetCellText(tRow, 3, data["dungs"])
	    
    end

	SendVarToRover("table_rating",self.wndMain:FindChild("TABLE_rating"))

	SendVarToRover("self",self)

	RIPgold:OnSizeChange_rating(self)

	self.wndMain:FindChild("WIN_ratings"):ArrangeChildrenVert(0)

end

function RIPgold:OnBTN_customClick()
	self.wndMain:FindChild("WIN_stats"):Show(false)
	self.wndMain:FindChild("WIN_ratings"):Show(false)
	self.wndMain:FindChild("WIN_custom"):Show(true)
	self.wndMain:FindChild("WIN_settings"):Show(false)

	self.wndMain:FindChild("TOP_BG_stats"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_ratings"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_custom"):SetBGColor("ef000000")
	self.wndMain:FindChild("TOP_BG_settings"):SetBGColor("99000000")

	self.wndMain:FindChild("WIN_custom"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("WRAP_ALL"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("WRAP_STL"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("WRAP_KV"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("WRAP_SC"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("WRAP_SSM"):ArrangeChildrenVert(0)
end

function RIPgold:OnBTN_settingsClick()
	self.wndMain:FindChild("WIN_stats"):Show(false)
	self.wndMain:FindChild("WIN_ratings"):Show(false)
	self.wndMain:FindChild("WIN_custom"):Show(false)
	self.wndMain:FindChild("WIN_settings"):Show(true)

	self.wndMain:FindChild("TOP_BG_stats"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_ratings"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_custom"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_settings"):SetBGColor("ef000000")

	self.wndMain:FindChild("SET_sound"):SetCheck(self.set.sound)
end

function RIPgold:OnBTN_SET_SoundClick(wndControl)
	self.set.sound = wndControl:IsChecked()
	self:PlaySound(self.set.soundType)
end

-----------------------------------------------------------------------------------------------
-- Save and Restore Data
-----------------------------------------------------------------------------------------------
function RIPgold:OnSave(eLevel)
	local tData = {}
	-- This example uses account level saves.
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
	-- Set your variables into tData
		tData.hlp = {}
		for name,data in pairs(self.hlp) do
			tData.hlp[name] = data
		end
		tData.set = {}
		for name,data in pairs(self.set) do
			tData.set[name] = data
		end
		tData.rat = {}
		for name,data in pairs(self.rat) do
			tData.rat[name] = data
		end
		--Sound.Play(Sound.PlayUIQueuePopsAdventure) testing purposes
	end
	
	return tData
end

function RIPgold:OnRestore(eLevel, tData)
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
		-- Set your reference for the saved variables
		-- This example simply sets a table to mimic the loaded data. You can change this to split data up as you like.
		
		for name,data in pairs(tData.hlp) do
			self.hlp[name] = data
		end
		for name,data in pairs(tData.set) do
			self.set[name] = data
		end
		for name,data in pairs(tData.rat) do
			self.rat[name] = data
		end

		self.tSavedVariables = tData
	end
end

-----------------------------------------------------------------------------------------------
-- RIPgold Instance
-----------------------------------------------------------------------------------------------
local RIPgoldInst = RIPgold:new()
RIPgoldInst:Init()
