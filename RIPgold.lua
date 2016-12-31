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

		self.hlp = {} -- all helpers
		self.set = {} -- all settings

		self.hlp.isBossDead = {}
		self.hlp.isBossDead.timer = ApolloTimer.Create(1, true, "ALL_checkForBossDeaths", self)
		self.hlp.isBossDead.timer:Stop()
		self.hlp.isBossDead.ID = 0
		self.hlp.isBossDead.name = ""
		self.hlp.isBossDead.dead = false

		self.hlp.doesChannelerExists = ApolloTimer.Create(1, true, "STL:checkForChannelerDeaths(self)", self)
		self.hlp.doesChannelerExists:Stop()

		self.hlp.peMatch = nil
		self.hlp.isInDungeon = false

		self:InitializeVars()

		if not GroupLib.InRaid() then
			self:PreparePlayers()
		end

		-- has to be outside InitializeVars() becouse it would get reseted after game creates Channelers
		self.hlp.WindInvokerChanellerID = { 
			[1] = 0, [2] = 0, [3] = 0, [4] = 0 
		}

		--- testing purposes
		self.set.sound = true
		-- additional sounds: self:PlaySound(Sound.PlayUIQueuePopsAdventure)
		-- additional sounds: self:PlaySound(Sound.PlayUI47CancelVirtual)
		self.set.soundType = Sound.PlayUI11To13GenericPushButtonDigital02

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

-- on SlashCommand "/rip"
function RIPgold:OnRIPgoldOn()

	self.updateStatsUI:Start()

	self:UpdateRIPgoldStatsUI()
	self:OnBTN_statsClick() --instead of self.wndMain:FindChild("WRAP_FAILS"):ArrangeChildrenVert(1)

	self.wndMain:Invoke() -- show the window

	-- self:Debug(self.hlp.player[1].name .. ": " .. self.hlp.player[1].fails)
	-- self:Debug(self.hlp.player[2].name .. ": " .. self.hlp.player[2].fails)
	-- self:Debug(self.hlp.player[3].name .. ": " .. self.hlp.player[3].fails)
	-- self:Debug(self.hlp.player[4].name .. ": " .. self.hlp.player[4].fails)
	-- self:Debug(self.hlp.player[5].name .. ": " .. self.hlp.player[5].fails)

end

function RIPgold:UpdateRIPgoldStatsUI()

	for i=1,5 do
		if self.hlp.player[i].name ~= "" then

			self.wndMain:FindChild("WIN_stats"):FindChild("INFO_fails_name_"..i):SetText(self.hlp.player[i].name)
			self.wndMain:FindChild("WIN_stats"):FindChild("INFO_fails_stat_"..i):SetText(self.hlp.player[i].fails)
		else
			self.wndMain:FindChild("INFO_fails_name_"..i):SetText("")
			self.wndMain:FindChild("INFO_fails_stat_"..i):SetText("")
		end
	end

end

function RIPgold:HowManyFails()

	self:InformOthers("So, how many fails did you do this dungeon?", false)

	for i=1,5 do
		if self.hlp.player[i].name ~= "" then
			self:InformOthers(self.hlp.player[i].name .. ": " .. self.hlp.player[i].fails, false)
		end
	end
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

	self.hlp.nPoints = 0
	self.hlp.nBronze = 0
	self.hlp.nSilver = 0
	self.hlp.nGold = 0

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

				self.hlp.nPoints = peCurrent:GetRewardThreshold(PublicEvent.PublicEventRewardTier_None)
				self.hlp.nBronze = peCurrent:GetRewardThreshold(PublicEvent.PublicEventRewardTier_Bronze)
				self.hlp.nSilver = peCurrent:GetRewardThreshold(PublicEvent.PublicEventRewardTier_Silver)
				self.hlp.nGold = peCurrent:GetRewardThreshold(PublicEvent.PublicEventRewardTier_Gold)
					
				self.hlp.peMatch = peCurrent

				SendVarToRover("self", self)
				
				return true
			end
		end
	end

	return false
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
	--if self.hlp.isInDungeon then 
		self.hlp.isBossDead.dead = false
		self.hlp.isBossDead.name = unitInCombat:GetName()
		self.hlp.isBossDead.ID = unitInCombat:GetId()
		self.hlp.isBossDead.timer:Start()
	--end
end

function RIPgold:ALL_checkForBossDeaths()
	--if self.hlp.isInDungeon then 

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
					self:HowManyFails()
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
	--end
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
		self:Debug(fnString)
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
function RIPgold:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function RIPgold:OnCancel()
	self.wndMain:Close() -- hide the window
	self.updateStatsUI:Stop()
end

-- when top buttons (cards) are clicked
function RIPgold:OnBTN_statsClick()
	self.wndMain:FindChild("WIN_stats"):Show(true)
	self.wndMain:FindChild("WIN_custom"):Show(false)
	self.wndMain:FindChild("WIN_settings"):Show(false)

	self.wndMain:FindChild("TOP_BG_stats"):SetBGColor("ef000000")
	self.wndMain:FindChild("TOP_BG_custom"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_settings"):SetBGColor("99000000")

	self.wndMain:FindChild("WRAP_FAILS"):ArrangeChildrenVert(1)
end

function RIPgold:OnBTN_customClick()
	self.wndMain:FindChild("WIN_stats"):Show(false)
	self.wndMain:FindChild("WIN_custom"):Show(true)
	self.wndMain:FindChild("WIN_settings"):Show(false)

	self.wndMain:FindChild("TOP_BG_stats"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_custom"):SetBGColor("ef000000")
	self.wndMain:FindChild("TOP_BG_settings"):SetBGColor("99000000")

	self.wndMain:FindChild("WIN_custom"):ArrangeChildrenVert(1)
	self.wndMain:FindChild("WRAP_ALL"):ArrangeChildrenVert(1)
	self.wndMain:FindChild("WRAP_STL"):ArrangeChildrenVert(1)
	self.wndMain:FindChild("WRAP_KV"):ArrangeChildrenVert(1)
	self.wndMain:FindChild("WRAP_SC"):ArrangeChildrenVert(1)
	self.wndMain:FindChild("WRAP_SSM"):ArrangeChildrenVert(1)
end

function RIPgold:OnBTN_settingsClick()
	self.wndMain:FindChild("WIN_stats"):Show(false)
	self.wndMain:FindChild("WIN_custom"):Show(false)
	self.wndMain:FindChild("WIN_settings"):Show(true)

	self.wndMain:FindChild("TOP_BG_stats"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_custom"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_settings"):SetBGColor("ef000000")

	self.wndMain:FindChild("SET_sound"):SetCheck(self.set.sound)
end

function RIPgold:OnBTN_SET_SoundClick(wndControl)
	self.set.sound = wndControl:IsChecked()
	self:PlaySound(self.set.soundType)
end

-----------------------------------------------------------------------------------------------
-- RIPgold Instance
-----------------------------------------------------------------------------------------------
local RIPgoldInst = RIPgold:new()
RIPgoldInst:Init()
