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

-- Customized version of pairs which iterates over the table in a sorted order
function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end


function UIr:OnBTN_ratingsClick(self)
	self.wndMain:FindChild("WIN_stats"):Show(false)
	self.wndMain:FindChild("WIN_ratings"):Show(true)
	self.wndMain:FindChild("WIN_custom"):Show(false)
	self.wndMain:FindChild("WIN_settings"):Show(false)

	self.wndMain:FindChild("TOP_BG_stats"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_ratings"):SetBGColor("ef000000")
	self.wndMain:FindChild("TOP_BG_custom"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_settings"):SetBGColor("99000000")

	local tableRating = {}
	local tableDungs = {}
	
	self.wndMain:FindChild("TABLE_rating"):DeleteAll()
	self.wndMain:FindChild("TABLE_dungs"):DeleteAll()

    for index,data in pairs(self.rat) do
    	tableRating[index] = data["rating"]
    	tableDungs[index] = data["dungs"]
    end

    -- removes current player ("myself") from statistics
    local getCurrentPlayerName = GameLib.GetPlayerUnit():GetName()
    self:removeFromSet(tableRating, getCurrentPlayerName)
    self:removeFromSet(tableDungs, getCurrentPlayerName)

    local i = 0
	for index,rating in spairs(tableRating, function(t,a,b) return t[b] < t[a] end) do
		i = i+1
		if i < 11 then
			local tRow = self.wndMain:FindChild("TABLE_rating"):AddRow("")
		    self.wndMain:FindChild("TABLE_rating"):SetCellText(tRow, 1, index)

		    local readableRating = string.format("%2.0f", rating / 100)
		    self.wndMain:FindChild("TABLE_rating"):SetCellText(tRow, 2, readableRating)
		end
	end

    local i = 0
	for index,dungs in spairs(tableDungs, function(t,a,b) return t[b] < t[a] end) do
		i = i+1
		if i < 11 then
			local tRow = self.wndMain:FindChild("TABLE_dungs"):AddRow("")
		    self.wndMain:FindChild("TABLE_dungs"):SetCellText(tRow, 1, index)
		    self.wndMain:FindChild("TABLE_dungs"):SetCellText(tRow, 2, dungs)
		end
	end	

	self.wndMain:FindChild("WIN_ratings"):ArrangeChildrenVert(0)
end

function UIr:OnLoad() end

Apollo.RegisterPackage(UIr, MAJOR, MINOR, {})