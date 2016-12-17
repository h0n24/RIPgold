-----------------------------------------------------------------------------------------------
-- Client Lua Script for RIPgold
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------


-- todo: first boss in ssm get to 
-- todo: first boss stl -> GameLib.GetUnitScreenPosition()

-- Forgemaster Trogun 
 
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

local alreadyFailedChallenge = false
local alreadyFailedDeathless = false

local inRaid = false
 
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
		Apollo.RegisterSlashCommand("rip", "OnRIPgoldOn", self)


		-- Do additional Addon initialization here
		Apollo.RegisterEventHandler("UnitEnteredCombat", "OnCombat", self)
		Apollo.RegisterEventHandler("CombatLogDamage", "OnCombatLogDamage", self)
		Apollo.RegisterEventHandler("CombatLogVitalModifier", "OnCombatLogVitalModifier", self)
		Apollo.RegisterEventHandler("CombatLogDeath", "OnCombatLogDeath", self)
		Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)



		Apollo.RegisterEventHandler("ChangeWorld", "OnWorldChange", self)

		-- Apollo.RegisterEventHandler("ShowResurrectDialog", "OnRessurect", self) -- future reference

		self.bossAlive = {
			["Grond the Corpsemaker"] = false,
			["Stew-Shaman Tugga"] = false,
			["Bosun Octog"] = false,
			["Terraformer"] = false,
			["Forgemaster Trogun"] = false,
			["Deadringer Shallaos"] = false,
		}

		self:PreparePlayers()

		self.SelenePercentage = 0

		self.ShallaosStacks = {
			[1] = 0,
			[2] = 0,
			[3] = 0,
			[4] = 0,
			[5] = 0,
		}

	end
end

-----------------------------------------------------------------------------------------------
-- RIPgold Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/rip"
function RIPgold:OnRIPgoldOn()
	--self.wndMain:Invoke() -- show the window

	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, self.player[1].name .. ": " .. self.player[1].fails, "RIPgold")
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, self.player[2].name .. ": " .. self.player[2].fails, "RIPgold")
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, self.player[3].name .. ": " .. self.player[3].fails, "RIPgold")
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, self.player[4].name .. ": " .. self.player[4].fails, "RIPgold")
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, self.player[5].name .. ": " .. self.player[5].fails, "RIPgold")

end

function RIPgold:PreparePlayers()

	self.player = {
		[1] = {["name"] = "", ["fails"] = 0},
		[2] = {["name"] = "", ["fails"] = 0},
		[3] = {["name"] = "", ["fails"] = 0},
		[4] = {["name"] = "", ["fails"] = 0},
		[5] = {["name"] = "", ["fails"] = 0},
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

		if GroupLib.InRaid() then
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "In a raid", "RIPgold")
			inRaid = true
		else

			for nGroupIndex=1,getGroupMaxSize do 

				local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
				if getGroupMember ~= nil then

					local getGroupMemberName = getGroupMember.strCharacterName
					self.player[nGroupIndex].name = getGroupMemberName
					self.player[nGroupIndex].fails = 0

				end
			end
		end

	end

	SendVarToRover("players", self.player)

end


function RIPgold:OnCombat(unitInCombat, bInCombat)

	if inRaid == false then 

		-- todo try: possibly needs same wrap if same as in OnCombatDamage -> test if needed

		local unitInCombatName = unitInCombat:GetName()
		local unitInCombatDead = unitInCombat:IsDead()


		-- proceeds on leaving combat
		if bInCombat == false then 

			-- specific bosses

			if self.bossAlive["Stew-Shaman Tugga"] == true then

				function IsTuggaStuffed()
				   local getBossBuffs = unitInCombat:GetBuffs().arBeneficial[1].splEffect:GetName() ~= nil
				end

				if pcall(IsTuggaStuffed) then

					local getBossBuffs = unitInCombat:GetBuffs().arBeneficial[1].splEffect:GetName()

					if getBossBuffs == "Devour Flesh" then

						local sToChat = "Stew-Shaman Tugga ate Devour Flesh during combat. Challenge is lost. Someone from this team can't interrupt at right time. Is that you, slacker?"

						self:InformOthers(sToChat, true)

					end
				end
			end

			if self.bossAlive["Bosun Octog"] == true then

				function IsBosunBroken()
				   local getBossBuffs = unitInCombat:GetBuffs().arBeneficial[1].splEffect:GetName() ~= nil
				end

				if pcall(IsBosunBroken) then

					local getBossBuffs = unitInCombat:GetBuffs().arBeneficial[1].splEffect:GetName()

					if getBossBuffs == "Ink Shield" then

						local sToChat = "Octog got ink shield"

						ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, sToChat, "RIPgold")

						--self:InformOthers(sToChat, true)

					end
				end
			end


			-- resets challenge every boss death so the party gets warned every wipe (challenge resets too)

			if unitInCombat:IsInYourGroup() == false then

				if unitInCombat:IsElite() then

					local creatureRisk = unitInCombat:GetCreatureRisk()
					if creatureRisk == 3 then -- creature risk is the boss
						alreadyFailedChallenge = false
						ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Challenges reseted - boss died", "RIPgold")

					end
		
				end
			end

			-- bosses variable reset

			if unitInCombatName == "Terraformer" then
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Terraformer dead.", "RIPgold")
				self.bossAlive["Terraformer"] = false
			end

			if unitInCombatName == "Grond the Corpsemaker" then
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Grond the Corpsemaker dead.", "RIPgold")
				self.bossAlive["Grond the Corpsemaker"] = false
			end

			if unitInCombatName == "Stew-Shaman Tugga" then
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Stew-Shaman Tugga dead.", "RIPgold")
				self.bossAlive["Stew-Shaman Tugga"] = false
			end

			if unitInCombatName == "Forgemaster Trogun" then
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Forgemaster Trogun dead.", "RIPgold")
				self.bossAlive["Forgemaster Trogun"] = false
			end

			if unitInCombatName == "Bosun Octog" then
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Bosun Octog dead.", "RIPgold")
				self.bossAlive["Forgemaster Trogun"] = false
			end

			if unitInCombatName == "Deadringer Shallaos" then
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Deadringer Shallaos dead.", "RIPgold")

				local failsInfo = ""

				for i=1,5 do

					--local didContributed = self.player[i].fails

					--if didContributed > 0 then
						local additionalComma = ""
						if i > 1 then
							-- local j = i - 1
							-- local prePlayer = self.player[j].fails
							-- if prePlayer == 0 then
							--else 
								additionalComma = ","
							--end
						end
						failsInfo = string.format("%s%s %s (%s fails)", failsInfo, additionalComma, self.player[i].name, self.player[i].fails)

					--end

					--ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Deadringer Shallaos dead.", "RIPgold")
				end

				if self.player[1].fails == 0 and self.player[2].fails == 0 and self.player[3].fails == 0 and self.player[4].fails == 0 and self.player[5].fails == 0 then

					ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Wow! I am so proud. ♥ It's official. Perfect boss fight. Noone did any mistake.", "RIPgold")

					self:InformOthers(sToChat, true)

				else

					local sToChat = string.format("Who is the best player here? %s", failsInfo)

					ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, sToChat, "RIPgold")

					self:InformOthers(sToChat, true)
				end

				self.bossAlive["Deadringer Shallaos"] = false
			end

		end

	end

end

function RIPgold:OnWorldChange()

	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Challenges reseted (swapping worlds)", "RIPgold")

	if GroupLib.InRaid() then
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "In a raid", "RIPgold")
		inRaid = true
	else
		inRaid = false


		alreadyFailedChallenge = false
		alreadyFailedDeathless = false

		-- possibly not needed, cuz they should reset after their death
		self.bossAlive["Grond the Corpsemaker"] = false
		self.bossAlive["Stew-Shaman Tugga"] = false
		self.bossAlive["Bosun Octog"] = false
		self.bossAlive["Terraformer"] = false
		self.bossAlive["Forgemaster Trogun"] = false
		self.bossAlive["Deadringer Shallaos"] = false


		self:PreparePlayers()

		self.ShallaosStacks = {
			[1] = 0,
			[2] = 0,
			[3] = 0,
			[4] = 0,
			[5] = 0,
		}

	end

end


function RIPgold:OnCombatLogVitalModifier(tEventArgs)

	local getCaster = tEventArgs.unitCaster:GetName()

	if getCaster == "Spiritmother Selene's Echo" then

		local SeleneHealth = tEventArgs.unitCaster:GetHealth()
		local SeleneMaxHealth = tEventArgs.unitCaster:GetMaxHealth()
		local SelenePercentage = SeleneHealth / SeleneMaxHealth

		self.SelenePercentage = SelenePercentage

		-- self.SelenePercentage = string.format("%3.0f", SelenePercentage)

		--ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, SelenePercentage, "RIPgold")
		-- ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, stringInfo2, "RIPgold")

		--SendVarToRover(timeinfo, tEventArgs.unitCaster)

	end

	local unitInCombatDead = tEventArgs.unitTarget:IsDead()

	if unitInCombatDead == true then
		local time = GameLib.GetGameTime()
		local timeinfo = string.format("unitInCombatDead - %s", time)

		SendVarToRover(timeinfo, tEventArgs.unitTarget)

	end

	if self.bossAlive["Terraformer"] == true then

		function IsTerablinded()
		   local getBossBuffs = tEventArgs.unitTarget:GetBuffs().arHarmful[1].strTooltip ~= nil
		end

		if pcall(IsTerablinded) then

			if tEventArgs.unitTarget:GetBuffs().arHarmful[1].strTooltip == "Blinded!" then

				local getTarget = tEventArgs.unitTarget:GetName()
				local sToChat = string.format("%s was blinded. Mortedechai Redmoon's challenge is lost. Remember to always look out to prevent this!", getTarget)

				self:InformOthers(sToChat, true)

			end

		end

	end

	-- if self.bossAlive["Bosun Octog"] == true then

	-- 	function IsBosunBroken()
	-- 	   local getBossBuffs = tEventArgs.unitTarget:GetBuffs().arHarmful[1].splEffect:GetName() ~= nil
	-- 	end

	-- 	if pcall(IsBosunBroken) then

	-- 		local time = GameLib.GetGameTime()
	-- 		local timeinfo = string.format("Bosun - %s", time)

	-- 		SendVarToRover(timeinfo, tEventArgs.unitTarget)

	-- 		local validBossBuffs = getBossBuffs ~= nil

	-- 		if validBossBuffs then

	-- 			local getCountDebuffs = tEventArgs.unitTarget:GetBuffs().arHarmful[1].nCount ~= nil

	-- 			local sToChat = string.format("Bosun Octog got %s stacks of Broken Armor when he died.", getCountDebuffs)

	-- 			--self:SendToChat(sToChat)
	-- 			--self.bossAlive["Bosun Octog"] = false

	-- 			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, sToChat, "RIPgold")

	-- 		end

	-- 	else
	-- 		local sToChat = "Bosun Octog got no stacks of Broken Armor when he died. Challenge is lost."

	-- 		--self:SendToChat(sToChat)

	-- 		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, sToChat, "RIPgold")
	-- 		--self.bossAlive["Bosun Octog"] = false

	-- 	end

	-- end

	if self.bossAlive["Forgemaster Trogun"] == true then  

		function IsForgemasterBuffed()
		   local BossBuffs = tEventArgs.unitCaster:GetBuffs().arBeneficial[1].splEffect:GetName() ~= nil
		end

		if pcall(IsForgemasterBuffed) then

			local getBossBuffs = tEventArgs.unitTarget:GetBuffs()

			local getBossBuffsNcount = getBossBuffs.arBeneficial[1].nCount -- ~= nil --- bugged nil

			local buffinfo = string.format("Forgemaster alive - %s", getBossBuffsNcount)
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, buffinfo, "RIPgold")


			local time = GameLib.GetGameTime()
			local testingtrogun = tEventArgs.unitTarget:GetBuffs().arBeneficial[1]
			local timeinfo = string.format("Forgemaster - %s", time)

			SendVarToRover(timeinfo, testingtrogun)

			local validBossBuffs = getBossBuffs ~= nil

			if validBossBuffs then

				local sToChat = "Forgemaster got stacks of Primal Rage. The challenge is lost"

				self.bossAlive["Forgemaster Trogun"] = false -- possibly not needed -> todo test it

				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, sToChat, "RIPgold")
				--self:InformOthers(sToChat, true)

			end

		end

	end

end


function RIPgold:OnCombatLogDeath(unitDeath)

	-- possibly different types of deaths

	SendVarToRover("OnCombatLogDeath", unitDeath.unitCaster)

	

	-- if alreadyFailedDeathless == false then

	-- 	if inRaid == false then

	-- 		-- if unitInCombat:IsInYourGroup() then -- possibly not needed
	-- 		local sToChat = "Someone was killed. Deathless challenge is lost. Gold medal is lost. Bye 1 platinum for everyone. Bye Ability point drop. Bye AMP point drop."

	-- 		self:SendToChat(sToChat)
	-- 		alreadyFailedDeathless = true
	-- 	end

	-- end

end

function RIPgold:OnUnitCreated(unit)

	local getUnit = unit:GetName()

	if getUnit == "Spiritmother Selene" then

		local SelenePercentage = self.SelenePercentage * 100

		if (100 > SelenePercentage and SelenePercentage > 0) then
				
			local SelenePercentageString = string.format("%.f %%", SelenePercentage);
			local sToChat = string.format("Spiritmother was at %s health. Challenge is lost. She has to be full at the end of battle.", SelenePercentageString)

			self:InformOthers(sToChat, true)

		end

	end

end




function RIPgold:OnCombatLogDamage(tEventArgs)

	local validTarget = tEventArgs.unitTarget ~= nil
	local validCaster = tEventArgs.unitCaster ~= nil
	local validSpell = tEventArgs.splCallingSpell:GetName() ~= nil
	if validTarget and validCaster and validSpell then

		if tEventArgs.unitTarget:IsInYourGroup() or tEventArgs.unitTarget:IsThePlayer() then -- if target is in your party

			local getSpell = tEventArgs.splCallingSpell:GetName()
			local getCaster = tEventArgs.unitCaster:GetName()
			local getTarget = tEventArgs.unitTarget:GetName()

			-- if alreadyFailedDeathless == false then
			-- 	if tEventArgs.bTargetKilled then
			-- 		local sToChat = string.format("%s was killed by %s from %s (%s overkill). Deathless challenge is lost. Gold medal is lost. Bye 1 platinum for everyone. Bye ability point. Bye AMP point.", getTarget, getSpell, getCaster, tEventArgs.nOverkill)

			-- 		self:SendToChat(sToChat)
			-- 		alreadyFailedDeathless = true

			-- 	end
			-- end

			if tEventArgs.unitTarget:IsDead() then -- when player dies
				

				-- local sToChat = string.format("%s was killed by %s from %s (%s overkill). Deathless challenge is lost. Gold medal is lost. Bye 1 platinum for everyone. Bye ability point. Bye AMP point.", getTarget, getSpell, getCaster, tEventArgs.nOverkill)
				local sToChat = string.format("%s was killed by %s from %s (%s overkill)", getTarget, getSpell, getCaster, tEventArgs.nOverkill)

				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, sToChat, "RIPgold")

				--SendVarToRover("unitTarget isdead", tEventArgs.unitTarget)
			end
			

			--- Skullcano

			if getCaster == "Stew-Shaman Tugga" then
				--ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Tugga alive.", "RIPgold")
				self.bossAlive["Stew-Shaman Tugga"] = true
			end


			if getSpell == "Seismic Tremor" and getCaster == "Thunderfoot" then

				local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Is really that hard to jump?", getTarget, getSpell, getCaster)
				self:InformOthers(sToChat, true)

			end

			if getSpell == "Dark Fireball" and getCaster == "Laveka the Dark-Hearted" then

				local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Come on, just evade small circular AOE, you are not that bad, are you?", getTarget, getSpell, getCaster)
				self:InformOthers(sToChat, true)

			end

			if getCaster == "Bosun Octog" then
				--ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Bosun Octog alive.", "RIPgold")
				self.bossAlive["Bosun Octog"] = true
			end

			if getCaster == "Terraformer" then
				--ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Terraformer alive.", "RIPgold")
				self.bossAlive["Terraformer"] = true
			end

			--- Stormtalon's Lair

			if getSpell == "Twister" and getCaster == "Aethros Twister" then

				local sToChat = string.format("%s was hit by %s. Aethros's challenge is lost. What's so problematic at dancing between tornados?", getTarget, getSpell, getCaster)
				self:InformOthers(sToChat, true)

			end

			if getSpell == "Lightning Strike" and getCaster == "Stormtalon" then

				local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Remember! After kick phase just run around like radioactive squirrel and when someone got moving telegraph, don't fucking stand in the middle. Easy, right?", getTarget, getSpell, getCaster)
				self:InformOthers(sToChat, true)

			end

			--- Sanctuary of the Swordmaiden

			if getCaster == "Deadringer Shallaos" then
				--ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Deadringer alive.", "RIPgold")
				self.bossAlive["Deadringer Shallaos"] = true
			end

			---- first boss

			if self.bossAlive["Deadringer Shallaos"] == true then

				function GotResonanceStack()
				   local getBossBuffs = tEventArgs.unitTarget:GetBuffs().arHarmful[1].splEffect:GetName() ~= nil
				end

				if pcall(GotResonanceStack) then

					local getCasterDebuffs = tEventArgs.unitTarget:GetBuffs().arHarmful[1].splEffect:GetName()
					local getResonanceStacks = tEventArgs.unitTarget:GetBuffs().arHarmful[1].nCount

					if getCasterDebuffs == "Resonance" then

						local getGroupMaxSize = GroupLib.GetGroupMaxSize(); -- its 5 when in group, 0 when alone

						if getGroupMaxSize == 0 then

							local getResonanceStacksOld = self.ShallaosStacks[1]

							if getResonanceStacks > getResonanceStacksOld then

								--local getResonanceStacksPlayerOld = self.player[1].fails
								-- self.player[1].fails = getResonanceStacksPlayerOld + 1 -- posibly wont be working
								self.player[1].fails = getResonanceStacks

							end

							self.ShallaosStacks[nGroupIndex] = getResonanceStacks

						else

							for nGroupIndex=1,getGroupMaxSize do 
								local getGroupMember = GroupLib.GetGroupMember(nGroupIndex); 

								if getGroupMember ~= nil then

									local getGroupMemberName = getGroupMember.strCharacterName

									if getGroupMemberName == getTarget then

										local getResonanceStacksOld = self.ShallaosStacks[nGroupIndex]

										if getResonanceStacks > getResonanceStacksOld then

											ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, string.format("%s has %s stacks of Resonance", getTarget, getResonanceStacks), "RIPgold")
											--local getResonanceStacksPlayerOld = self.player[nGroupIndex].fails
											--self.player[nGroupIndex].fails = getResonanceStacksPlayerOld + 1

											self.player[nGroupIndex].fails = getResonanceStacks

										end

										self.ShallaosStacks[nGroupIndex] = getResonanceStacks
										
									end

								end

								-- future refrence purposes: if you wanna use unit for members
								-- local getGroupMemberUnit = GroupLib.GetUnitForGroupMember(nGroupIndex);
							end

						end
					
						SendVarToRover("players", self.player)

					end

				end

			end

			--- end of first boss

			if getCaster == "Rayna Darkspeaker" then
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Rayna alive.", "RIPgold")
			end

			if getSpell == "Molten Wave" and getCaster == "Rayna Darkspeaker" then

				local sToChat = string.format("%s was hit by %s. %s's challenge is lost. What's so problematic at dancing between fire walls?", getTarget, getSpell, getCaster)
				self:InformOthers(sToChat, true)

			end

			if getSpell == "Plague Splatter" and getCaster == "Ondu Lifeweaver" then

				local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Really? Isn't that telegraph bigger than Aki's ass? How did you missed it, slacker?", getTarget, getSpell, getCaster)
				self:InformOthers(sToChat, true)

			end

			if getSpell == "Corruption Pustule" and getCaster == "Moldwood Swarmling" then

				local sToChat = string.format("%s was hit by %s. Vitara's heart challenge is lost. And I dont blame you, this challenge is impossible to complete proper way. Easier is to kill boss before he starts casting (about 1 min since battle starts), but that usually needs kamikaze group (5 dps).", getTarget, getSpell, getCaster)
				self:InformOthers(sToChat, true)

			end

			--- Ruins of the Kel Voreth

			if getCaster == "Grond the Corpsemaker" then
				--ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Grond alive.", "RIPgold")
				self.bossAlive["Grond the Corpsemaker"] = true
			end
		

			if self.bossAlive["Grond the Corpsemaker"] == true then

				if getSpell == "Bone Clamp" and getCaster == "Bone Cage" then

					local sToChat = string.format("%s was hit by %s. Grond the Corpsemaker's challenge is lost. So you love to jump into Bone Traps and possibly fucking gold medal challenges. Do you also love to leave this game? *winky face*", getTarget, getSpell, getCaster)
					self:InformOthers(sToChat, true)

				end

			end

			if getSpell == "Homing Barrage" and getCaster == "Slavemaster Drokk" then

				local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Come on, that small AOE is smaller than Korean dick... How did you caught it?", getTarget, getSpell, getCaster)
				self:InformOthers(sToChat, true)

			end

			if getSpell == "Phase Blast" and getCaster == "Eldan Phase Blaster" then

				local sToChat = string.format("%s was hit by %s. And obviously challenge is lost. Yeah, so you wanna get vaporized... And wanna fuck the most easiest challenge. Well done. Well done.", getTarget, getSpell, getCaster)
				self:InformOthers(sToChat, true)

			end

		end
	end

end

function RIPgold:getShallaosStacks(tEventArgs)

	--ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Deadringer alive.", "RIPgold")

	SendVarToRover("tEventArgs", tEventArgs)

	function GotResonanceStack(tEventArgs)
	   local getBossBuffs = tEventArgs.unitTarget:GetBuffs().arHarmful[1].splEffect:GetName() ~= nil
	end

	if pcall(GotResonanceStack) then

		local getCasterDebuffs = tEventArgs.unitTarget:GetBuffs().arHarmful[1].splEffect:GetName()
		local getResonanceStacks = tEventArgs.unitTarget:GetBuffs().arHarmful[1].nCount

		if getCasterDebuffs == "Resonance" then

			local getGroupMaxSize = GroupLib.GetGroupMaxSize(); -- its 5 when in group, 0 when alone

			if getGroupMaxSize == 0 then

				local getResonanceStacksOld = self.ShallaosStacks[1]

				if getResonanceStacks > getResonanceStacksOld then

					local getResonanceStacksPlayerOld = self.player[1].fails
					self.player[1].fails = getResonanceStacksPlayerOld + 1

				end

				self.ShallaosStacks[nGroupIndex] = getResonanceStacks

			else

				for nGroupIndex=1,getGroupMaxSize do 
					local getGroupMember = GroupLib.GetGroupMember(nGroupIndex); 

					if getGroupMember ~= nil then

						local getGroupMemberName = getGroupMember.strCharacterName

						if getGroupMemberName == getTarget then

							local getResonanceStacksOld = self.ShallaosStacks[nGroupIndex]

							if getResonanceStacks > getResonanceStacksOld then

								ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, string.format("%s has %s stacks of Resonance", getTarget, getResonanceStacks), "RIPgold")
								local getResonanceStacksPlayerOld = self.player[nGroupIndex].fails
								self.player[nGroupIndex].fails = getResonanceStacksPlayerOld + 1

							end

							self.ShallaosStacks[nGroupIndex] = getResonanceStacks
							
						end

					end

					-- future refrence purposes: if you wanna use unit for members
					-- local getGroupMemberUnit = GroupLib.GetUnitForGroupMember(nGroupIndex);
				end

			end
		
			SendVarToRover("players", self.player)

		end

	end

end

function RIPgold:InformOthers(sToChat, setFailedChallenge)

	if alreadyFailedChallenge == false then

		self:SendToChat(sToChat)

		if setFailedChallenge == true then
			alreadyFailedChallenge = true
		else
			alreadyFailedChallenge = false
		end

	end

end

function RIPgold:SendToChat(fnString)
	if GroupLib.InInstance() then
		ChatSystemLib.Command("/i "..fnString)
	--elseif GroupLib.InGroup() or GroupLib.InRaid() then
	elseif GroupLib.InGroup() then
		ChatSystemLib.Command("/p "..fnString)
		--ChatSystemLib.Command("/s "..fnString)
	else
		Print(fnString)
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
