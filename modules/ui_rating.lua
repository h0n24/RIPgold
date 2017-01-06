local MAJOR, MINOR = "Module:UIr-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local UIr = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
UIr.null = setmetatable ({}, {
  __toinn = function () return "null" end
})

-----------------------------------------------------------------------------------------------
-- Initialize variables
-----------------------------------------------------------------------------------------------

function UIr:OnBTN_ratingsClick(self)
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

	UIr:setTableHeight(self)

	self.wndMain:FindChild("WIN_ratings"):ArrangeChildrenVert(0)
end

function UIr:setTableHeight(self)
	local rowsNumber = self.wndMain:FindChild("TABLE_rating"):GetRowCount()
	local tableWidth = self.wndMain:GetWidth() - 50
	local tableHeight = rowsNumber*25 + 30

    self.wndMain:FindChild("TABLE_rating"):SetAnchorOffsets(10,0,tableWidth,tableHeight)
end

function UIr:OnLoad() end

Apollo.RegisterPackage(UIr, MAJOR, MINOR, {})