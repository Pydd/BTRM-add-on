---@class addon
local addon = select(2, ...)

local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
local LibDeflate = LibStub:GetLibrary("LibDeflate")
local LibSerialize = LibStub("LibSerialize")
UIParentLoadAddOn("Blizzard_DebugTools")

local ac = LibStub("AceComm-3.0", true)
if ac then ac:Embed(addon) end
local as = LibStub("AceSerializer-3.0", true)
if as then as:Embed(addon) end

local minimapButton = ldb:NewDataObject('BTRM', {
    type = "data source",
    text = "0",
    icon = "Interface\\AddOns\\BTRM\\Media\\icon",
})

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function()
    local icon = LibStub("LibDBIcon-1.0", true)
    if not icon then return end
    if not BTRMLDBIconDB then BTRMLDBIconDB = {} end
    icon:Register('BTRM', minimapButton, BTRMLDBIconDB)
end)

f:RegisterEvent("PLAYER_LOGIN")


local function getNumberOfKeys(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end


local function parseInput(data)
    local result = {}
    local itemNeedLines = { strsplit("\n", data) }
    for _, itemNeedLine in ipairs(itemNeedLines) do
        local id, text = strsplit(";", itemNeedLine)
        local itemID = tonumber(id)
        if not result[itemID] then
            result[itemID] = text
        end
    end

    return result
end



local function createTooltipFrame()
    local customFrame = CreateFrame("Frame", nil, GameTooltip, "BackdropTemplate")
    customFrame:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 0, 0)

    customFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",  -- Texture de fond sombre
        edgeFile = "Interface\\AddOns\\Details\\images\\border_3",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1}
    })

    customFrame:SetBackdropColor(0.11, 0.11, 0.13, 0.9)  -- Fond semi-transparent
    customFrame:SetBackdropBorderColor(0, 0, 0, 1)

     LeftText = customFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
     LeftText:SetPoint("LEFT", customFrame, "LEFT", 10, 0)
     LeftText:SetJustifyH("LEFT")
     LeftText:SetFont("Fonts\\FRIZQT__.TTF", 12)

    return customFrame
end


local tooltipFrame = createTooltipFrame();

local function getTextFromLink(link)
    local itemID = link['id']
    if BTRMDB and BTRMDB[itemID] then
        return BTRMDB[itemID]:gsub("\\n", "\n"):gsub("||", "|")
    end
end

local function addText(tooltip, link)

    if not link or not tooltip then
        tooltipFrame:Hide()
    end


    local text = getTextFromLink(link)

    if text then
        LeftText:SetText(text)
        tooltipFrame:SetSize( tooltipFrame:GetParent():GetWidth(), LeftText:GetStringHeight() + 30)

        if IsShiftKeyDown() then
            tooltipFrame:SetPoint("BOTTOMLEFT", GameTooltip, "TOPLEFT", 0, 0)
        else
            tooltipFrame:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 0, 0)
        end

        tooltipFrame:Show()
    else
        tooltipFrame:Hide()
    end
end

local function OnTooltipHide(self)
    tooltipFrame:Hide()
end

local function OnTooltipUpdate(self, elapsed)
    tooltipFrame:ClearAllPoints()
    if IsShiftKeyDown() then
        tooltipFrame:SetPoint("BOTTOM", self, "TOP")
    else
        tooltipFrame:SetPoint("TOP", self, "BOTTOM")
    end
end


TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, addText)
GameTooltip:HookScript("OnHide", OnTooltipHide)
GameTooltip:HookScript("OnUpdate", OnTooltipUpdate)


-- With compression (recommended):
function addon:Transmit(data)
    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
    addon:SendCommMessage("BTRM", encoded, "GUILD")
end

function addon:OnCommReceived(prefix, payload, distribution, sender)
    if GetUnitName("PLAYER") ~= sender and 'BTRM' == prefix then
        local decoded = LibDeflate:DecodeForWoWAddonChannel(payload)
        if not decoded then return end
        local decompressed = LibDeflate:DecompressDeflate(decoded)
        if not decompressed then return end
        local success, data = LibSerialize:Deserialize(decompressed)
        if not success then return end
        BTRMDB = data
        local count = getNumberOfKeys(BTRMDB)
        if count == 1 then
            print('[BTRM] : ' .. count .. ' item shared by ' .. sender)
        end
        if count > 1 then
            print('[BTRM] : ' .. count .. ' items shared by ' .. sender)
        end
    end
end

local function createInputFrame()
    local f = CreateFrame("Frame", "BTRMFrame", UIParent, "DialogBoxFrame")
    f:SetSize(450, 800)
    f:SetPoint("CENTER")
    f:EnableMouse(true)
    BTRMFrameButton:Hide()

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight",
        edgeSize = 16,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })

    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetFontObject("GameFontHighlight")
    f.title:SetPoint("CENTER", f.TitleBg, "CENTER", 5, 0)

    -- scroll frame
    local sf = CreateFrame("ScrollFrame", "BTRMScrollFrame", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("LEFT", 16, 0)
    sf:SetPoint("RIGHT", -32, 0)
    sf:SetPoint("TOP", 0, -32)

    -- edit box
    local eb = CreateFrame("EditBox", "BTRMEditBox", sf)
    eb:SetSize(sf:GetSize())
    eb:SetMultiLine(true)
    eb:SetAutoFocus(true)
    eb:SetFontObject("ChatFontNormal")
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    eb:HighlightText()
    sf:SetScrollChild(eb)


    eb:SetScript("OnTextChanged", function()
        local status, itemNeedsData = pcall(parseInput, eb:GetText())
        if status then
            if not BTRMDB then BTRMDB = {} end
            BTRMDB = itemNeedsData
            f:Hide()
            addon:Transmit(itemNeedsData)
            print('[BTRM] : ' .. getNumberOfKeys(itemNeedsData) .. ' items imported!')
        end
    end)
    addon:RegisterComm("BTRM")
    return f
end

local input = createInputFrame()


function minimapButton.OnClick(self, button)
    if button == "LeftButton" then
        if (input:IsShown()) then
            input:Hide()
        else
            BTRMEditBox:SetText("")
            input:Show()
        end
    end

    if button == "RightButton" then
        BTRMDB = {}
    end

    if button == "MiddleButton" then
        SendChatMessage("Reloading!", "RAID")
        ReloadUI()
    end
end
