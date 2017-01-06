local MAJOR, MINOR = "Module:UIn-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local UIn = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
UIn.null = setmetatable ({}, {
  __toinn = function () return "null" end
})

-----------------------------------------------------------------------------------------------
-- Card buttons (top menu)
-----------------------------------------------------------------------------------------------

function UIn:OnBTN_statsClick(self)
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

	UIn:UpdateAnnounce(self)

	-- workaround for a wildstar bug with not opening combat boxes
	UIn:onCOMB_roleOutsideClick(self)

	-- workaround for making arrow near COMB_role less visible (not possible via Houston)
	self.wndMain:FindChild("COMB_role"):GetChildren()[2]:SetBGColor("99ffffff")

	--self:Debug("GetMemberCount ".. GroupLib.GetMemberCount())

end


-----------------------------------------------------------------------------------------------
-- Group Statistics
-----------------------------------------------------------------------------------------------

function UIn:UpdateRIPgoldStats(self)
	self.wndMain:FindChild("TABLE_stats"):DeleteAll()

	if self.hlp.isInDungeon then
		UIn:findPlayers_Show(self, false)
	else
		local memberCount = GroupLib.GetMemberCount()
		if memberCount == 0 then
			self.hlp.lastMemberCount = 0
		elseif memberCount < 5 then
			--if self.hlp.lastMemberCount < memberCount then
				ALL:PreparePlayers(self)
				UIn:UpdateAnnounce(self)
				UIn:findPlayers_Show(self, true)
				--self.hlp.lastMemberCount = memberCount
			--end
			self.hlp.lastMemberCount = memberCount
		elseif memberCount == 5 then
			if self.hlp.lastMemberCount ~= memberCount then
				ALL:PreparePlayers(self)
				UIn:UpdateAnnounce(self)
				UIn:findPlayers_Show(self, true)
				--self.hlp.lastMemberCount = memberCount
			else
				UIn:UpdateAnnounce(self)
				UIn:findPlayers_Show(self, false)
			end
			self.hlp.lastMemberCount = memberCount
		else
			UIn:findPlayers_Show(self, false)
			self.hlp.lastMemberCount = 5
		end
	end

	local rowsNumber = 0
	for i=1,5 do
		if self.hlp.player == nil then
			ALL:PreparePlayers(self)
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

-----------------------------------------------------------------------------------------------
-- Announcing
-----------------------------------------------------------------------------------------------


function UIn:UpdateAnnounce(self)
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
		announcingText = UIn:UpdateAnnounceTextBase(self, announcingText,missingMembers)

	elseif memberCount < 5 then
		missingMembers = 5 - memberCount
		announcingText = UIn:UpdateAnnounceTextBase(self, announcingText,missingMembers)

	else
		announcingText = announcingText .. "full"
	end

	self.wndMain:FindChild("BOX_announce"):SetText(announcingText)
end

function UIn:UpdateAnnounceTextBase(self, announcingText, missingMembers)

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

function UIn:findPlayers_Show(self, showOrNot)
	self.wndMain:FindChild("INFO_findPlayers"):Show(showOrNot)
	self.wndMain:FindChild("WRAP_findPlayers_announce"):Show(showOrNot)
	self.wndMain:FindChild("WRAP_findPlayers_settings"):Show(showOrNot)
end

function UIn:onBOX_announceChange(self, wndControl)
	self.set.BOX_announce[self.set.COMB_roleIndex] = wndControl:GetText()
	UIn:UpdateAnnounce(self)
end

function UIn:onCOMB_roleOutsideClick(self)
	self.wndMain:FindChild("COMB_role"):GetChildren()[1]:Show(false)
end

function UIn:onCOMB_roleClick(self)
	local getIndex = self.wndMain:FindChild("COMB_role"):GetSelectedIndex()
	self.set.COMB_roleIndex = getIndex

	if self.set.COMB_roleIndex == 0 then
		self.wndMain:FindChild("BOX_BG_targetPerformance"):Show(false)
	else

		local BOX_announce_value = self.set.BOX_announce[self.set.COMB_roleIndex]
		self.wndMain:FindChild("BOX_BG_targetPerformance"):FindChild("BOX_announce"):SetText(BOX_announce_value)

		self.wndMain:FindChild("BOX_BG_targetPerformance"):Show(true)
	end

	UIn:UpdateAnnounce(self)
end

function UIn:onBTN_announceClick(self)
	local announce = self.wndMain:FindChild("BOX_announce"):GetText()
	ChatSystemLib.Command(announce)

	-- set open group
	GroupLib.SetJoinRequestMethod(GroupLib.InvitationMethod.Open)

	-- set open referrals
	GroupLib.SetReferralMethod(GroupLib.InvitationMethod.Open)
end

function UIn:CHCK_PLZ_dpsClick(self)
	self.set.CHCK_PLZ_dps = self.wndMain:FindChild("CHCK_PLZ_dps"):IsChecked()
	UIn:UpdateAnnounce(self)
end

function UIn:CHCK_PLZ_healClick(self)
	self.set.CHCK_PLZ_heal = self.wndMain:FindChild("CHCK_PLZ_heal"):IsChecked()
	UIn:UpdateAnnounce(self)
end

function UIn:CHCK_PLZ_tankClick(self)
	self.set.CHCK_PLZ_tank = self.wndMain:FindChild("CHCK_PLZ_tank"):IsChecked()
	UIn:UpdateAnnounce(self)
end





function UIn:OnLoad() end

Apollo.RegisterPackage(UIn, MAJOR, MINOR, {})