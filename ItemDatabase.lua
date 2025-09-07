-- CopyEnglishName: ItemDatabase.lua

-- 缓存
local nameCache = {}          -- 物品ID => 英文名缓存
local chineseNameCache = {}   -- 中文名 => 物品ID缓存
local isDataLoaded = false    -- 数据子插件是否加载成功

-- 工具函数：安全调用 C_AddOns.GetAddOnInfo
local function safeGetAddOnInfo(addonName)
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local name, title, notes, loadable, reason, security, updateAvailable = C_AddOns.GetAddOnInfo(addonName)
        return name, title, notes, loadable, reason
    else
        print("|cffff0000错误：当前环境没有 C_AddOns.GetAddOnInfo 接口，可能是怀旧服或测试服。|r")
        return nil, nil, nil, false, "NO_API"
    end
end

-- 初始化插件
local function initializeAddon()
    local name, title, notes, loadable, reason = safeGetAddOnInfo("CopyEnglishName_Data")
    if loadable or reason == "DEMAND_LOADED" then
        print("|cff00ff00CopyEnglishName 初始化成功，数据子插件按需加载状态正确。|r")
    else
        print("|cffff0000警告: 子插件 CopyEnglishName_Data 未正确配置为按需加载，原因:|r " .. (reason or "未知"))
    end
end

-- 创建初始化事件监听
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "CopyEnglishName" then
        initializeAddon()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- 加载数据子插件
local function loadDataAddon()
    if isDataLoaded then
        return true
    end

    local name, title, notes, loadable, reason = safeGetAddOnInfo("CopyEnglishName_Data")

    if not loadable and reason ~= "DEMAND_LOADED" then
        print("|cffff0000错误: 子插件 CopyEnglishName_Data 当前不可加载，原因:|r " .. (reason or "未知"))
        return false
    end

    local loaded, loadReason
    if C_AddOns and C_AddOns.LoadAddOn then
        loaded, loadReason = C_AddOns.LoadAddOn("CopyEnglishName_Data")
    else
        print("|cffff0000错误: 当前环境不支持 C_AddOns.LoadAddOn。|r")
        return false
    end

    if not loaded then
        print("|cffff0000错误: 加载数据子插件失败，原因:|r " .. (type(loadReason) == "string" and loadReason or tostring(loadReason)))
        return false
    end

    isDataLoaded = true
    print("|cff00ff00数据子插件 CopyEnglishName_Data 已成功加载。|r")
    return true
end

-- 工具：安全转换成字符串
local function SafeToString(value)
    if type(value) == "string" then
        return value
    elseif type(value) == "number" then
        return tostring(value)
    else
        return "未知"
    end
end

-- 查询物品英文名（通过ID）
local function getItemName(id)
    id = SafeToString(id)
    if nameCache[id] then
        return nameCache[id]
    end
    if not loadDataAddon() then
        nameCache[id] = "未知物品"
        return "未知物品"
    end
    for i = 1, 32 do
        local chunkTable = _G["ItemNames_" .. i]
        if chunkTable and chunkTable[id] then
            local nameData = chunkTable[id]
            local name
            if type(nameData) == "string" then
                name = nameData
            elseif type(nameData) == "table" and nameData.en then
                name = nameData.en
            else
                name = "未知物品"
            end
            nameCache[id] = name
            return name
        end
    end
    print("|cffff0000错误: 查询失败，ID " .. id .. " 不存在于数据库。|r")
    nameCache[id] = "未知物品"
    return "未知物品"
end

-- 查询物品ID和英文名（通过中文名）
local function getItemIdByChineseName(chineseName)
    if chineseNameCache[chineseName] then
        local id = chineseNameCache[chineseName]
        return id, getItemName(id)
    end
    if not loadDataAddon() then
        return nil, "未找到物品"
    end
    for i = 1, 32 do
        local chunkTable = _G["ItemNames_" .. i]
        if chunkTable then
            for id, data in pairs(chunkTable) do
                if type(data) == "table" and data.zh == chineseName then
                    chineseNameCache[chineseName] = id
                    nameCache[id] = data.en or "未知物品"
                    return id, data.en or "未知物品"
                end
            end
        end
    end
    print("|cffff0000错误: 未找到中文名称 '" .. chineseName .. "' 对应的物品。|r")
    return nil, "未找到物品"
end

-- 定义弹窗
StaticPopupDialogs["COPY_ENGLISH_NAME"] = {
    text = "物品英文名称（已选中，可直接复制）：",
    button1 = "确定",
    hasEditBox = true,
    OnShow = function(self, data)
        if not data or not data.name then
            print("|cffff0000错误: 弹窗数据无效|r")
            self:Hide()
            return
        end
        self.editBox:SetText(data.name)
        self.editBox:HighlightText()
        self.editBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    OnAccept = function(self)
        -- 确认按钮，什么都不用做
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Slash 命令注册（统一前缀，防止污染）
SLASH_COPYEN1 = "/en"
SlashCmdList["COPYEN"] = function(msg)
    if not msg or msg == "" then
        print("用法: /en [itemlink] 或 /en <itemId> 或 /en <中文名称>")
        return
    end

    msg = strtrim(msg)
    print("收到命令 /en " .. msg)

    local itemId = msg:match("|Hitem:(%d+):") or msg:match("item:(%d+)") or msg:match("^(%d+)$")
    if itemId then
        print("解析到物品ID: " .. itemId)
        local name = getItemName(itemId)
        if name and name ~= "未知物品" then
            StaticPopup_Show("COPY_ENGLISH_NAME", nil, nil, {name = name})
        else
            print("|cffff0000错误: 无法找到物品ID " .. itemId .. " 的英文名。|r")
        end
        return
    end

    print("尝试按中文名查询: " .. msg)
    local id, name = getItemIdByChineseName(msg)
    if id and name and name ~= "未知物品" then
        StaticPopup_Show("COPY_ENGLISH_NAME", nil, nil, {name = name})
    else
        print("|cffff0000错误: 未找到中文名称 '" .. msg .. "' 对应的物品。|r")
    end
end

-- 调试命令，查看子插件状态
SLASH_COPYDEBUG1 = "/debugtables"
SlashCmdList["COPYDEBUG"] = function()
    local name, title, notes, loadable, reason = safeGetAddOnInfo("CopyEnglishName_Data")
    print("子插件 CopyEnglishName_Data 状态：")
    print("  名称: " .. (name or "未知"))
    print("  启用状态: " .. (loadable and "是" or "否") .. (reason and " (原因:" .. reason .. ")" or ""))
    print("  已加载: " .. (isDataLoaded and "是" or "否"))
    if isDataLoaded then
        for i = 1, 32 do
            local tableName = "ItemNames_" .. i
            print("  表 " .. tableName .. ": " .. (_G[tableName] and "已加载" or "未加载"))
        end
    end
end
