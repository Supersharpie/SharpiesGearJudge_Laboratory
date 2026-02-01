-- [[ 1. NAMESPACE & DATA ]]
local addonName, SGF = ... 
SGF.LabItems = { [1]={}, [2]={} } -- NOW SUPPORTS TWO SETS
SGF.ActiveSet = 1 -- Which set is currently receiving inputs?
SGF.StatRows = {} 
SGF.SelectedProfile = nil

-- [[ TEXTURE MAP ]]
SGF.SlotTextures = {
    HeadSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Head",
    NeckSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Neck",
    ShoulderSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Shoulder",
    BackSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Chest", 
    ChestSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Chest",
    WristSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Wrists",
    HandsSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Hands",
    WaistSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Waist",
    LegsSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Legs",
    FeetSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Feet",
    Finger0Slot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Finger",
    Finger1Slot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Finger",
    Trinket0Slot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Trinket",
    Trinket1Slot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Trinket",
    MainHandSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-MainHand",
    SecondaryHandSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-SecondaryHand",
    RangedSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Ranged",
}

-- Ordered list for the UI columns
SGF.OrderedSlots = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "WristSlot",
    "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
    "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot", "RangedSlot"
}

-- [[ 2. SMART ITEM HANDLERS ]]
function SGF.GetSlotFromLoc(equipLoc, currentItems)
    if not equipLoc then return nil end
    
    if equipLoc == "INVTYPE_HEAD" then return "HeadSlot" end
    if equipLoc == "INVTYPE_NECK" then return "NeckSlot" end
    if equipLoc == "INVTYPE_SHOULDER" then return "ShoulderSlot" end
    if equipLoc == "INVTYPE_CLOAK" then return "BackSlot" end
    if equipLoc == "INVTYPE_CHEST" or equipLoc == "INVTYPE_ROBE" then return "ChestSlot" end
    if equipLoc == "INVTYPE_WRIST" then return "WristSlot" end
    if equipLoc == "INVTYPE_HAND" then return "HandsSlot" end
    if equipLoc == "INVTYPE_WAIST" then return "WaistSlot" end
    if equipLoc == "INVTYPE_LEGS" then return "LegsSlot" end
    if equipLoc == "INVTYPE_FEET" then return "FeetSlot" end
    
    if equipLoc == "INVTYPE_FINGER" then 
        if not currentItems["Finger0Slot"] then return "Finger0Slot" else return "Finger1Slot" end
    end
    if equipLoc == "INVTYPE_TRINKET" then 
        if not currentItems["Trinket0Slot"] then return "Trinket0Slot" else return "Trinket1Slot" end
    end
    
    if equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND" then return "MainHandSlot" end
    if equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_WEAPONOFFHAND" or equipLoc == "INVTYPE_HOLDABLE" then return "SecondaryHandSlot" end
    
    if equipLoc == "INVTYPE_WEAPON" then
        if not currentItems["MainHandSlot"] then return "MainHandSlot" end
        local mhLink = currentItems["MainHandSlot"]
        local _, _, _, _, _, _, _, _, mhLoc = GetItemInfo(mhLink)
        if mhLoc == "INVTYPE_2HWEAPON" then return "MainHandSlot" end
        if not currentItems["SecondaryHandSlot"] then return "SecondaryHandSlot" end
        return "MainHandSlot"
    end
    
    if equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_THROWN" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_RELIC" then return "RangedSlot" end
    return nil
end

function SGF.ReceiveLink(link)
    if not link then return end
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
    if not equipLoc then 
        local itemID = link:match("item:(%d+)")
        if itemID then _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemID) end
    end

    if not equipLoc then return end

    -- USE ACTIVE SET
    local setIdx = SGF.ActiveSet
    local currentItems = SGF.LabItems[setIdx]
    
    local targetSlot = SGF.GetSlotFromLoc(equipLoc, currentItems)
    
    if targetSlot then
        SGF.LabItems[setIdx][targetSlot] = link
        SGF.UpdateLabSlot(targetSlot, setIdx)
        
        -- Traffic Cop (2H vs Offhand)
        if targetSlot == "MainHandSlot" and equipLoc == "INVTYPE_2HWEAPON" then
            if SGF.LabItems[setIdx]["SecondaryHandSlot"] then
                SGF.LabItems[setIdx]["SecondaryHandSlot"] = nil
                SGF.UpdateLabSlot("SecondaryHandSlot", setIdx)
                print("|cffff0000SGJ (Set "..setIdx.."):|r Removed Off-Hand (2H Weapon equipped).")
            end
        elseif targetSlot == "SecondaryHandSlot" then
            local mhLink = SGF.LabItems[setIdx]["MainHandSlot"]
            if mhLink then
                local _, _, _, _, _, _, _, _, mhLoc = GetItemInfo(mhLink)
                if mhLoc == "INVTYPE_2HWEAPON" then
                    SGF.LabItems[setIdx]["MainHandSlot"] = nil
                    SGF.UpdateLabSlot("MainHandSlot", setIdx)
                    print("|cffff0000SGJ (Set "..setIdx.."):|r Removed Main-Hand (Cannot hold 2H with Shield).")
                end
            end
        end

        SGF.CalculateLabScore()
        PlaySound(1115) 
    else
        print("|cffff0000SGJ:|r Cannot slot item type: " .. (equipLoc or "Unknown"))
    end
end

-- [[ 3. DISPLAY LOGIC ]] 
function SGF.UpdateLabSlot(slotName, setIdx)
    local MSC = _G.MSC 
    if not MSC or not MSC.ViewLaboratory then return end
    
    -- Buttons are stored as Slots[setIdx][slotName]
    local btn = MSC.ViewLaboratory.Slots[setIdx][slotName]
    local link = SGF.LabItems[setIdx][slotName]
    
    if link then
        btn.Icon:SetTexture(GetItemIcon(link))
        btn.link = link
    else
        local bgTexture = SGF.SlotTextures[slotName] or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest"
        btn.Icon:SetTexture(bgTexture)
        btn.link = nil
    end
end

function SGF.ImportEquipped()
    local MSC = _G.MSC
    if not MSC or not MSC.ViewLaboratory then return end
    
    local setIdx = SGF.ActiveSet -- Import into active set

    for _, slotName in ipairs(SGF.OrderedSlots) do
        local slotID = GetInventorySlotInfo(slotName)
        local link = GetInventoryItemLink("player", slotID)
        SGF.LabItems[setIdx][slotName] = link
        SGF.UpdateLabSlot(slotName, setIdx)
    end
    SGF.CalculateLabScore()
    print("|cff00ff00SGJ:|r Equipped gear imported into Set " .. setIdx)
end

function SGF.CopySet1To2()
    -- Deep copy table
    SGF.LabItems[2] = {}
    for k, v in pairs(SGF.LabItems[1]) do
        SGF.LabItems[2][k] = v
    end
    -- Update UI
    for _, slotName in ipairs(SGF.OrderedSlots) do
        SGF.UpdateLabSlot(slotName, 2)
    end
    SGF.CalculateLabScore()
    print("|cff00ff00SGJ:|r Copied Set 1 to Set 2.")
end

function SGF.ClearLab(setIdx)
    -- If setIdx is nil, clear BOTH. Otherwise clear specific.
    if not setIdx then
        SGF.LabItems = { [1]={}, [2]={} }
        for _, s in ipairs(SGF.OrderedSlots) do 
            SGF.UpdateLabSlot(s, 1)
            SGF.UpdateLabSlot(s, 2)
        end
    else
        SGF.LabItems[setIdx] = {}
        for _, s in ipairs(SGF.OrderedSlots) do SGF.UpdateLabSlot(s, setIdx) end
    end
    
    SGF.CalculateLabScore()
    local MSC = _G.MSC
    if MSC and MSC.ViewLaboratory then
        MSC.ViewLaboratory.NameInput:SetText("")
        UIDropDownMenu_SetText(MSC.ViewLaboratory.LoadDD, "Load Set...")
    end
end

function SGF.CalculateLabScore()
    local MSC = _G.MSC 
    if not MSC or not MSC.ViewLaboratory or not MSC.ViewLaboratory.ScoreVal1 then return end

    local weights, profileName
    if SGF.SelectedProfile and SGF.SelectedProfile ~= "Global" then
        profileName = SGF.SelectedProfile
        if MSC.CurrentClass and MSC.CurrentClass.Weights and MSC.CurrentClass.Weights[profileName] then
            weights = MSC.CurrentClass.Weights[profileName]
        else
            weights, profileName = MSC.GetCurrentWeights()
        end
    else
        weights, profileName = MSC.GetCurrentWeights()
    end
    
    local dispName = (MSC.CurrentClass and MSC.CurrentClass.PrettyNames and MSC.CurrentClass.PrettyNames[profileName]) or profileName
    UIDropDownMenu_SetText(MSC.ViewLaboratory.SpecDD, dispName)

    -- Define Slot Map
    local slotMap = { 
        HeadSlot=1, NeckSlot=2, ShoulderSlot=3, BackSlot=15, ChestSlot=5, 
        WristSlot=9, HandsSlot=10, WaistSlot=6, LegsSlot=7, FeetSlot=8, 
        Finger0Slot=11, Finger1Slot=12, Trinket0Slot=13, Trinket1Slot=14, 
        MainHandSlot=16, SecondaryHandSlot=17, RangedSlot=18 
    }

    -- Helper to calc score for a set index
    local function GetSetScore(idx)
        local gear = {}
        for sName, link in pairs(SGF.LabItems[idx]) do
            if link and slotMap[sName] then gear[slotMap[sName]] = link end
        end
        return MSC:GetTotalCharacterScore(gear, weights, profileName)
    end

    local s1, stats1 = GetSetScore(1)
    local s2, stats2 = GetSetScore(2)

    -- Update UI Scores
    MSC.ViewLaboratory.ScoreVal1:SetText(string.format("%.1f", s1))
    MSC.ViewLaboratory.ScoreVal2:SetText(string.format("%.1f", s2))
    
    local diff = s2 - s1
    if diff > 0.1 then
        MSC.ViewLaboratory.DiffVal:SetText(string.format("Set 2 is |cff00ff00+%.1f|r better", diff))
    elseif diff < -0.1 then
        MSC.ViewLaboratory.DiffVal:SetText(string.format("Set 1 is |cff00ff00+%.1f|r better", math.abs(diff)))
    else
        MSC.ViewLaboratory.DiffVal:SetText("|cff888888Sets are Equal|r")
    end

    SGF.UpdateStatList(stats1, stats2, weights)
end

function SGF.UpdateStatList(stats1, stats2, weights)
    local MSC = _G.MSC
    local scrollFrame = MSC.ViewLaboratory.StatScroll
    local content = scrollFrame.Content
    
    -- FIX 1: Increase buffer from 25 to 45 to strictly clear the scrollbar
    local availableWidth = scrollFrame:GetWidth() - 5
    
    -- Safety check to prevent errors if UI hasn't fully rendered width yet
    if availableWidth < 100 then availableWidth = 200 end 

    content:SetWidth(availableWidth)
    
    for _, row in ipairs(SGF.StatRows) do row:Hide() end
    
    local allKeys = {}
    for k, _ in pairs(stats1) do allKeys[k] = true end
    for k, _ in pairs(stats2) do allKeys[k] = true end
    
    local data = {}
    for statKey, _ in pairs(allKeys) do
        local w = weights[statKey] or 0
        local v1 = stats1[statKey] or 0
        local v2 = stats2[statKey] or 0
        if w > 0 or v1 > 0 or v2 > 0 then
            table.insert(data, { key=statKey, weight=w, v1=v1, v2=v2, isWeighted=(w>0) })
        end
    end
    
    table.sort(data, function(a,b) 
        if a.isWeighted ~= b.isWeighted then return a.isWeighted end
        if a.isWeighted then return a.weight > b.weight else return a.key < b.key end
    end)
    
    local yOff = 0
    for i, d in ipairs(data) do
        local row = SGF.StatRows[i]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetHeight(16) 
            row:SetPoint("LEFT", 0, 0)
            row:SetPoint("RIGHT", 0, 0)
            
            row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.Name:SetPoint("LEFT", 2, 0)
            -- FIX 2: Reduce Name width to 35% to give numbers more room
            row.Name:SetWidth(availableWidth * 0.35) 
            row.Name:SetJustifyH("LEFT")
            row.Name:SetWordWrap(false)
            
            row.Val = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            -- FIX 3: Anchor -5 pixels from the NEW (narrower) right edge
            row.Val:SetPoint("RIGHT", -5, 0)
            -- FIX 4: Give Value 65% of the width
            row.Val:SetWidth(availableWidth * 0.65)
            row.Val:SetJustifyH("RIGHT")
            
            SGF.StatRows[i] = row
        end
        
        row:SetPoint("TOPLEFT", 0, yOff)
        row:Show()
        
        -- Clean up names
        local cleanName = MSC.GetCleanStatName(d.key)
        cleanName = cleanName:gsub(" Rating", ""):gsub(" Spell", ""):gsub("Defense", "Def"):gsub("Attack Power", "AP")
        row.Name:SetText(cleanName)
        
        -- Color weighted stats
        if d.isWeighted then row.Name:SetTextColor(1, 0.82, 0) else row.Name:SetTextColor(0.6, 0.6, 0.6) end
        
        -- Calculate Diff
        local diff = d.v2 - d.v1
        local diffText = ""
        if diff > 0.01 then diffText = "|cff00ff00+"..string.format("%.0f", diff).."|r"
        elseif diff < -0.01 then diffText = "|cffff0000"..string.format("%.0f", diff).."|r"
        else diffText = "-"
        end
        
        -- Format: "10 / 12 (+2)"
        row.Val:SetText(string.format("%.0f / %.0f (%s)", d.v1, d.v2, diffText))
        
        -- Striping
        if not row.bg then row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(); row.bg:SetColorTexture(1, 1, 1, 0.03) end
        if i % 2 == 0 then row.bg:Show() else row.bg:Hide() end
        
        yOff = yOff - 18
    end
    
    -- FIX 5: Ensure scrolling works by setting content height
    content:SetHeight(math.abs(yOff))
end

-- [[ 4. SAVE / LOAD / DELETE / EXPORT ]]
function SGF.GetCharDB()
    if not SGJ_LaboratoryDB then SGJ_LaboratoryDB = {} end
    local key = UnitName("player") .. " - " .. GetRealmName()
    if not SGJ_LaboratoryDB[key] then SGJ_LaboratoryDB[key] = {} end
    return SGJ_LaboratoryDB[key]
end

function SGF.SaveCurrentSet()
    local MSC = _G.MSC
    local name = MSC.ViewLaboratory.NameInput:GetText()
    local setIdx = SGF.ActiveSet -- Save ONLY the active set
    
    if not name or name == "" then 
        print("|cffff0000SGJ:|r Please enter a name for Set "..setIdx)
        return 
    end
    
    local charDB = SGF.GetCharDB()
    charDB[name] = {}
    for k, v in pairs(SGF.LabItems[setIdx]) do charDB[name][k] = v end
    
    print("|cff00ff00SGJ:|r Saved Active Set ("..setIdx..") as '"..name.."'")
    MSC.ViewLaboratory.NameInput:ClearFocus()
    UIDropDownMenu_SetText(MSC.ViewLaboratory.LoadDD, name)
end

function SGF.LoadSet(name)
    local charDB = SGF.GetCharDB()
    if not charDB or not charDB[name] then return end
    
    local setIdx = SGF.ActiveSet -- Load INTO active set
    SGF.LabItems[setIdx] = {}
    for k, v in pairs(charDB[name]) do SGF.LabItems[setIdx][k] = v end
    
    local MSC = _G.MSC
    for _, s in ipairs(SGF.OrderedSlots) do SGF.UpdateLabSlot(s, setIdx) end
    SGF.CalculateLabScore()
    MSC.ViewLaboratory.NameInput:SetText(name)
    print("|cff00ccffSGJ:|r Loaded '"..name.."' into Set "..setIdx)
end

function SGF.DeleteSelectedSet()
    local MSC = _G.MSC
    local name = UIDropDownMenu_GetText(MSC.ViewLaboratory.LoadDD)
    local charDB = SGF.GetCharDB()
    if name and charDB and charDB[name] then
        charDB[name] = nil
        print("|cffff0000SGJ:|r Deleted set '"..name.."'.")
        SGF.ClearLab(nil) -- Clear both for safety or just keep? Let's just reset UI
    else
        print("|cffff0000SGJ:|r Select a set to delete first.")
    end
end

function SGF.SerializeSet()
    local parts = {}
    table.insert(parts, "SGJ:1") 
    local setIdx = SGF.ActiveSet -- Export Active
    for slotName, link in pairs(SGF.LabItems[setIdx]) do
        local rawString = link:match("(item:[%d:-]+)")
        if rawString then table.insert(parts, slotName .. "=" .. rawString) end
    end
    return table.concat(parts, "&")
end

function SGF.DeserializeSet(importStr)
    if type(importStr) ~= "string" or importStr == "" then return end
    
    local setIdx = SGF.ActiveSet
    SGF.LabItems[setIdx] = {} 

    -- [[ MODE 1: NATIVE SGJ ]]
    if importStr:find("^SGJ:1") then
        for chunk in importStr:gmatch("[^&]+") do
            if chunk ~= "SGJ:1" then
                local slotName, itemString = chunk:match("^([^=]+)=(.+)$")
                if slotName and itemString and SGF.SlotTextures[slotName] then
                    SGF.LabItems[setIdx][slotName] = itemString
                    SGF.UpdateLabSlot(slotName, setIdx)
                    GetItemInfo(itemString)
                end
            end
        end
        SGF.CalculateLabScore()
        print("|cff00ff00SGJ:|r Native Set Imported into Set "..setIdx)
        return
    end

    -- [[ MODE 2: JSON (SeventyUpgrades) ]]
    if importStr:find("\"items\":") or importStr:find("\"gameClass\":") then
        print("|cff00ccffSGJ:|r JSON detected. Parsing structure...")
        local jsonMap = {
            ["HEAD"] = "HeadSlot", ["NECK"] = "NeckSlot", ["SHOULDERS"] = "ShoulderSlot", 
            ["BACK"] = "BackSlot", ["CHEST"] = "ChestSlot", ["WRISTS"] = "WristSlot", 
            ["HANDS"] = "HandsSlot", ["WAIST"] = "WaistSlot", ["LEGS"] = "LegsSlot", 
            ["FEET"] = "FeetSlot", ["FINGER_1"] = "Finger0Slot", ["FINGER_2"] = "Finger1Slot", 
            ["TRINKET_1"] = "Trinket0Slot", ["TRINKET_2"] = "Trinket1Slot", 
            ["MAIN_HAND"] = "MainHandSlot", ["OFF_HAND"] = "SecondaryHandSlot", ["RANGED"] = "RangedSlot"
        }
        
        local itemsBlock = importStr:match('"items":%s*(%b[])')
        if itemsBlock then
            for itemObj in itemsBlock:gmatch("(%b{})") do
                local slotKey = itemObj:match('"slot":%s*"([^"]+)"')
                local targetSlot = jsonMap[slotKey]
                if targetSlot then
                    local itemID = itemObj:match('"id":%s*(%d+)')
                    if itemID then
                        local enchantID = 0
                        local enchantBlock = itemObj:match('"enchant":%s*(%b{})')
                        if enchantBlock then enchantID = enchantBlock:match('"id":%s*(%d+)') or 0 end
                        SGF.LabItems[setIdx][targetSlot] = "item:"..itemID..":"..enchantID..":0:0:0:0:0:0"
                        SGF.UpdateLabSlot(targetSlot, setIdx)
                        C_Item.RequestLoadItemDataByID(tonumber(itemID))
                    end
                end
            end
        end
        SGF.CalculateLabScore()
        print("|cff00ff00SGJ:|r JSON Import Complete.")
        return
    end

    -- [[ MODE 3: SIMC / RAIDBOTS ]]
    -- Format: "head=item_name,id=1234,enchant_id=56"
    if importStr:find("id=") then
        print("|cff00ccffSGJ:|r SimC format detected...")
        -- Map SimC slot names to ours
        local simcMap = {
            ["head"] = "HeadSlot", ["neck"] = "NeckSlot", ["shoulders"] = "ShoulderSlot", 
            ["back"] = "BackSlot", ["chest"] = "ChestSlot", ["wrists"] = "WristSlot", 
            ["hands"] = "HandsSlot", ["waist"] = "WaistSlot", ["legs"] = "LegsSlot", 
            ["feet"] = "FeetSlot", ["finger1"] = "Finger0Slot", ["finger2"] = "Finger1Slot", 
            ["trinket1"] = "Trinket0Slot", ["trinket2"] = "Trinket1Slot", 
            ["main_hand"] = "MainHandSlot", ["off_hand"] = "SecondaryHandSlot", ["ranged"] = "RangedSlot"
        }

        for line in importStr:gmatch("[^\r\n]+") do
            -- Look for lines starting with "slotname="
            local slotKey, params = line:match("^([%w_]+)=(.+)$")
            if slotKey and simcMap[slotKey] then
                local targetSlot = simcMap[slotKey]
                local itemID = params:match("id=(%d+)")
                local enchantID = params:match("enchant_id=(%d+)") or 0
                
                if itemID then
                    SGF.LabItems[setIdx][targetSlot] = "item:"..itemID..":"..enchantID..":0:0:0:0:0:0"
                    SGF.UpdateLabSlot(targetSlot, setIdx)
                    C_Item.RequestLoadItemDataByID(tonumber(itemID))
                end
            end
        end
        SGF.CalculateLabScore()
        print("|cff00ff00SGJ:|r SimC Import Complete.")
        return
    end

    -- [[ MODE 4: GENERIC SCRAPER (Wowhead "Links" / Text Lists) ]]
    print("|cff00ccffSGJ:|r Parsing generic item list...")
    for id in importStr:gmatch("%d+") do
        local itemID = tonumber(id)
        if itemID and itemID > 2000 then 
            local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemID)
            if equipLoc and equipLoc ~= "" then
                local slotName = SGF.GetSlotFromLoc(equipLoc, SGF.LabItems[setIdx])
                if slotName then
                    SGF.LabItems[setIdx][slotName] = "item:"..itemID..":0:0:0:0:0:0:0"
                    SGF.UpdateLabSlot(slotName, setIdx)
                end
            else
                C_Item.RequestLoadItemDataByID(itemID) 
            end
        end
    end
    SGF.CalculateLabScore()
    print("|cff00ff00SGJ:|r List Parsed.")
end

function SGF.CreateCopyPastePopup()
    if SGF.Popup then return SGF.Popup end
    local f = CreateFrame("Frame", "SGJ_CopyPastePopup", UIParent); f:SetSize(400, 300); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
    f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(f); f.bg:SetColorTexture(0, 0, 0, 0.9)
    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.Title:SetPoint("TOP", 0, -10); f.Title:SetText("Export / Import")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -5, -5)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT", 20, -40); scroll:SetPoint("BOTTOMRIGHT", -40, 50)
    local eb = CreateFrame("EditBox", nil, scroll); eb:SetSize(340, 400); eb:SetMultiLine(true); eb:SetFontObject("GameFontHighlight"); eb:SetAutoFocus(false); scroll:SetScrollChild(eb); f.EditBox = eb
    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); btn:SetSize(100, 25); btn:SetPoint("BOTTOM", 0, 15); btn:SetText("Import This")
    btn:SetScript("OnClick", function() local text = eb:GetText(); SGF.DeserializeSet(text); f:Hide() end); f.ImportBtn = btn
    f.Hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.Hint:SetPoint("BOTTOM", 0, 45); f.Hint:SetText("Press Ctrl+C to Copy or Ctrl+V to Paste"); f.Hint:SetTextColor(0.6, 0.6, 0.6)
    f:Hide(); SGF.Popup = f; return f
end

-- [[ 5. UI CONSTRUCTION ]]
function SGF.InitLaboratoryView(parent)
    local MSC = _G.MSC
    local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()
    
    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.Title:SetPoint("TOPLEFT", 20, -12); f.Title:SetText("The Laboratory (Comparator)")

    -- [[ LAYOUT ADJUSTMENT: BALANCED ]]
    -- Set 1 stays at 30
    local set1Origin = { x = 30, y = -65 }
    -- Set 2 moved to 220 (Previous: 250 [Too Wide], Recent: 190 [Too Tight])
    local set2Origin = { x = 220, y = -65 } 
    
    -- Keep the tighter column gap (85) as that looked good
    local col2X = 85 
    local dollCoords = {
        HeadSlot = {x=0, y=0}, NeckSlot = {x=0, y=-38}, ShoulderSlot = {x=0, y=-76}, BackSlot = {x=0, y=-114}, ChestSlot = {x=0, y=-152}, WristSlot = {x=0, y=-190},
        MainHandSlot = {x=0, y=-228}, SecondaryHandSlot = {x=0, y=-266}, RangedSlot = {x=0, y=-304}, 
        HandsSlot = {x=col2X, y=0}, WaistSlot = {x=col2X, y=-38}, LegsSlot = {x=col2X, y=-76}, FeetSlot = {x=col2X, y=-114}, Finger0Slot = {x=col2X, y=-152}, Finger1Slot = {x=col2X, y=-190}, Trinket0Slot = {x=col2X, y=-228}, Trinket1Slot = {x=col2X, y=-266},
    }

    f.Set1Btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); f.Set1Btn:SetSize(70, 22); f.Set1Btn:SetPoint("TOPLEFT", set1Origin.x + 10, -35); f.Set1Btn:SetText("Set 1")
    f.Set2Btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); f.Set2Btn:SetSize(70, 22); f.Set2Btn:SetPoint("TOPLEFT", set2Origin.x + 10, -35); f.Set2Btn:SetText("Set 2")

    local function UpdateActiveSetUI()
        if SGF.ActiveSet == 1 then f.Set1Btn:LockHighlight(); f.Set2Btn:UnlockHighlight(); f.Set1Btn.Text:SetTextColor(1,1,0); f.Set2Btn.Text:SetTextColor(1,1,1)
        else f.Set1Btn:UnlockHighlight(); f.Set2Btn:LockHighlight(); f.Set1Btn.Text:SetTextColor(1,1,1); f.Set2Btn.Text:SetTextColor(1,1,0) end
    end
    f.Set1Btn:SetScript("OnClick", function() SGF.ActiveSet = 1; UpdateActiveSetUI() end)
    f.Set2Btn:SetScript("OnClick", function() SGF.ActiveSet = 2; UpdateActiveSetUI() end)
    UpdateActiveSetUI()

    f.ActiveLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.ActiveLbl:SetPoint("LEFT", f.Title, "RIGHT", 15, 0); f.ActiveLbl:SetText("(Select Set to Edit)"); f.ActiveLbl:SetTextColor(0.5, 0.5, 0.5)

    f.Slots = { [1]={}, [2]={} }
    for setIdx = 1, 2 do
        local origin = (setIdx == 1) and set1Origin or set2Origin
        for slotName, coords in pairs(dollCoords) do
            local btn = CreateFrame("Button", nil, f)
            btn:SetSize(34, 34); btn:SetPoint("TOPLEFT", origin.x + coords.x, origin.y + coords.y)
            btn.Icon = btn:CreateTexture(nil, "ARTWORK"); btn.Icon:SetAllPoints(); btn.Icon:SetTexture(SGF.SlotTextures[slotName])
            btn.Border = btn:CreateTexture(nil, "OVERLAY"); btn.Border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); btn.Border:SetBlendMode("ADD"); btn.Border:SetAlpha(0.4); btn.Border:SetAllPoints(); btn.Border:Hide()
            btn:SetScript("OnClick", function(self, button)
                local t,_,l = GetCursorInfo()
                if t=="item" then SGF.ActiveSet = setIdx; UpdateActiveSetUI(); SGF.ReceiveLink(l); ClearCursor()
                elseif button == "RightButton" or IsShiftKeyDown() then SGF.LabItems[setIdx][slotName] = nil; SGF.UpdateLabSlot(slotName, setIdx); SGF.CalculateLabScore() end
            end)
            btn:SetScript("OnEnter", function(s) if s.link then GameTooltip:SetOwner(s,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink(s.link); GameTooltip:Show() end; btn.Border:Show() end)
            btn:SetScript("OnLeave", function() GameTooltip_Hide(); btn.Border:Hide() end)
            f.Slots[setIdx][slotName] = btn
        end
    end

    f.SpecDD = CreateFrame("Frame", "SGJ_LaboratorySpecDD", f, "UIDropDownMenuTemplate"); f.SpecDD:SetPoint("TOPRIGHT", -10, -5); UIDropDownMenu_SetWidth(f.SpecDD, 120); UIDropDownMenu_SetText(f.SpecDD, "Follow Main Addon")
    UIDropDownMenu_Initialize(f.SpecDD, function(self, level)
        local info = UIDropDownMenu_CreateInfo(); info.text = "Follow Main Addon"; info.func = function() SGF.SelectedProfile = "Global"; SGF.CalculateLabScore() end; info.checked = (SGF.SelectedProfile == "Global" or SGF.SelectedProfile == nil); UIDropDownMenu_AddButton(info, level)
        if MSC.CurrentClass and MSC.CurrentClass.Weights then for k, v in pairs(MSC.CurrentClass.Weights) do local info = UIDropDownMenu_CreateInfo(); local pretty = (MSC.CurrentClass.PrettyNames and MSC.CurrentClass.PrettyNames[k]) or k; info.text = pretty; info.func = function() SGF.SelectedProfile = k; SGF.CalculateLabScore() end; info.checked = (SGF.SelectedProfile == k); UIDropDownMenu_AddButton(info, level) end end
    end)

    f.ScoreVal1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); f.ScoreVal1:SetPoint("TOPLEFT", set1Origin.x + 20, -405); f.ScoreVal1:SetText("0"); f.ScoreVal1:SetTextColor(1,1,0)
    f.ScoreVal2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); f.ScoreVal2:SetPoint("TOPLEFT", set2Origin.x + 20, -405); f.ScoreVal2:SetText("0"); f.ScoreVal2:SetTextColor(1,1,0)
    
    -- Center diff text between 140 (approx middle)
    f.DiffVal = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.DiffVal:SetPoint("TOPLEFT", 140, -430); f.DiffVal:SetText("Ready")

    -- [[ SCROLL FRAME BALANCED ]]
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    -- Moved X to 350 (Previous: 380 [Text Cut], Recent: 320 [Too Wide])
    -- This gives the dolls more room but keeps text readable.
    scroll:SetPoint("TOPLEFT", 375, -45); scroll:SetPoint("BOTTOMRIGHT", -30, 90) 
    f.StatScroll = scroll
    f.StatScroll.Content = CreateFrame("Frame", nil, scroll)
    f.StatScroll.Content:SetSize(230, 600) 
    scroll:SetScrollChild(f.StatScroll.Content)

    local yR1 = 50
    f.ImportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); f.ImportBtn:SetSize(80, 22); f.ImportBtn:SetPoint("BOTTOMLEFT", 20, yR1); f.ImportBtn:SetText("Equipped"); f.ImportBtn:SetScript("OnClick", function() SGF.ImportEquipped() end)
    f.CopyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); f.CopyBtn:SetSize(80, 22); f.CopyBtn:SetPoint("LEFT", f.ImportBtn, "RIGHT", 5, 0); f.CopyBtn:SetText("Copy 1->2"); f.CopyBtn:SetScript("OnClick", function() SGF.CopySet1To2() end)
    f.ClearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); f.ClearBtn:SetSize(80, 22); f.ClearBtn:SetPoint("LEFT", f.CopyBtn, "RIGHT", 5, 0); f.ClearBtn:SetText("Clear All"); f.ClearBtn:SetScript("OnClick", function() SGF.ClearLab(nil) end)
    f.NameInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate"); f.NameInput:SetSize(130, 25); f.NameInput:SetPoint("LEFT", f.ClearBtn, "RIGHT", 15, 0); f.NameInput:SetAutoFocus(false); f.NameInput:SetText("My Set")
    f.SaveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); f.SaveBtn:SetSize(50, 22); f.SaveBtn:SetPoint("LEFT", f.NameInput, "RIGHT", 5, 0); f.SaveBtn:SetText("Save"); f.SaveBtn:SetScript("OnClick", function() SGF.SaveCurrentSet() end)

    local yR2 = 25
    f.ShareBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); f.ShareBtn:SetSize(80, 22); f.ShareBtn:SetPoint("BOTTOMLEFT", 20, yR2); f.ShareBtn:SetText("Export Set"); f.ShareBtn:SetScript("OnClick", function() local p = SGF.CreateCopyPastePopup(); local s = SGF.SerializeSet(); p.EditBox:SetText(s); p.EditBox:HighlightText(); p.ImportBtn:Hide(); p.Title:SetText("Export Set "..SGF.ActiveSet); p:Show() end)
    f.ImpStrBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); f.ImpStrBtn:SetSize(80, 22); f.ImpStrBtn:SetPoint("LEFT", f.ShareBtn, "RIGHT", 5, 0); f.ImpStrBtn:SetText("Import Str"); f.ImpStrBtn:SetScript("OnClick", function() local p = SGF.CreateCopyPastePopup(); p.EditBox:SetText(""); p.ImportBtn:Show(); p.Title:SetText("Paste to Set "..SGF.ActiveSet); p.EditBox:SetFocus(); p:Show() end)
    f.LoadDD = CreateFrame("Frame", "SGJ_LaboratoryLoadDD", f, "UIDropDownMenuTemplate"); f.LoadDD:SetPoint("LEFT", f.ImpStrBtn, "RIGHT", -5, -2); UIDropDownMenu_SetWidth(f.LoadDD, 130); UIDropDownMenu_SetText(f.LoadDD, "Load Set...")
    UIDropDownMenu_Initialize(f.LoadDD, function(self, level) local charDB = SGF.GetCharDB(); if not charDB then return end for name, _ in pairs(charDB) do local info = UIDropDownMenu_CreateInfo(); info.text = name; info.func = function() SGF.LoadSet(name); UIDropDownMenu_SetText(f.LoadDD, name) end; UIDropDownMenu_AddButton(info, level) end end)
    f.DelBtn = CreateFrame("Button", nil, f); f.DelBtn:SetSize(20, 20); f.DelBtn:SetPoint("LEFT", f.LoadDD, "RIGHT", 5, 3); f.DelBtn.Icon = f.DelBtn:CreateTexture(nil, "ARTWORK"); f.DelBtn.Icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up"); f.DelBtn.Icon:SetAllPoints(); f.DelBtn:SetScript("OnClick", function() SGF.DeleteSelectedSet() end)

    MSC.ViewLaboratory = f
end

function SGF.UpdateLaboratory() end

-- [[ 6. HOOKS (SAME AS BEFORE) ]]
local regFrame = CreateFrame("Frame")
regFrame:RegisterEvent("PLAYER_LOGIN")
regFrame:SetScript("OnEvent", function()
    local MSC = _G.MSC 
    if not SGJ_LaboratoryDB then SGJ_LaboratoryDB = {} end
    if MSC and MSC.RegisterPluginTab then 
        MSC.RegisterPluginTab("The Lab", "Interface\\Icons\\INV_Chest_Plate04", SGF.InitLaboratoryView, "ViewLaboratory", "UpdateLaboratory")
        if MSC.RenderSidebarButtons then MSC.RenderSidebarButtons() end
        
        hooksecurefunc("SetItemRef", function(link) if MSC.ViewLaboratory and MSC.ViewLaboratory:IsShown() and IsModifiedClick("CHATLINK") then SGF.ReceiveLink(link) end end)
        hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self) 
            if MSC.ViewLaboratory and MSC.ViewLaboratory:IsShown() and IsModifiedClick("CHATLINK") then 
                local b,s = self:GetParent():GetID(), self:GetID()
                local l = (C_Container and C_Container.GetContainerItemLink) and C_Container.GetContainerItemLink(b,s) or GetContainerItemLink(b,s)
                if l then SGF.ReceiveLink(l) end 
            end 
        end)
        hooksecurefunc("PaperDollItemSlotButton_OnModifiedClick", function(self) if MSC.ViewLaboratory and MSC.ViewLaboratory:IsShown() and IsModifiedClick("CHATLINK") then local link = GetInventoryItemLink("player", self:GetID()); if link then SGF.ReceiveLink(link) end end end)
    end
end)