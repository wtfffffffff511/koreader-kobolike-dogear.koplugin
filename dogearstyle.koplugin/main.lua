--[[--
书签折角（Dogear Style）插件

自定义书签折角的图标与大小：
* 图标：使用插件自带的 icons/dogear.svg（透明背景 SVG），文件缺失时回退到原生图标
* 自动大小：沿用 KOReader 原生逻辑，折角不超过页边距、不压住正文
* 自定义大小：按屏幕宽度（横边）的百分比（2% – 40%），可折出盖住文字的大折角

设置入口：打开书本 → 顶部菜单 → 主菜单列表最底部（"新：书签折角"）。
--]]

local BD = require("ui/bidi")
local Device = require("device")
local Geom = require("ui/geometry")
local IconWidget = require("ui/widget/iconwidget")
local RightContainer = require("ui/widget/container/rightcontainer")
local SpinWidget = require("ui/widget/spinwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local Screen = Device.screen
local _ = require("gettext")

-- 自定义大小的上下限（屏幕宽度的百分比）
local MIN_PCT = 2
local MAX_PCT = 40
local DEFAULT_PCT = 12

-- 预设档位
local PRESET_PCTS = { 3, 6, 12, 20, 30 }

local DogearStyle = WidgetContainer:extend{
    name = "dogearstyle",
    is_doc_only = true,
}

function DogearStyle:init()
    -- 先注册菜单：无论下面的折角补丁是否兼容当前 KOReader 版本，
    -- 设置入口都一定会出现。
    self.ui.menu:registerToMainMenu(self)

    self.last_margins = nil
    self.icon_is_custom = false
    local ok, err = pcall(function()
        self:patchDogear()
        self:applySize()
    end)
    if not ok then
        logger.warn("dogearstyle: patch failed:", err)
    end
end

function DogearStyle:addToMainMenu(menu_items)
    local ok, err = pcall(function()
        menu_items.dogear_style = {
            text = _("书签折角"),
            sub_item_table = self:buildConfigMenu(),
        }
    end)
    if not ok then
        logger.err("dogearstyle: addToMainMenu failed:", err)
    end
end

-- ---------------------------------------------------------------------------
-- 设置界面（二级菜单）
-- ---------------------------------------------------------------------------

function DogearStyle:buildConfigMenu()
    local items = {
        {
            text = _("自动大小（不压住文字）"),
            radio = true,
            checked_func = function()
                return G_reader_settings:readSetting("dogear_size_mode", "auto") == "auto"
            end,
            callback = function(touchmenu_instance)
                G_reader_settings:saveSetting("dogear_size_mode", "auto")
                self:applySize()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
        },
    }
    for i, pct in ipairs(PRESET_PCTS) do
        table.insert(items, {
            text = string.format(_("大小：%d%%"), pct),
            radio = true,
            checked_func = function()
                return G_reader_settings:readSetting("dogear_size_mode", "auto") == "custom"
                    and G_reader_settings:readSetting("dogear_custom_size_pct", DEFAULT_PCT) == pct
            end,
            callback = function(touchmenu_instance)
                G_reader_settings:saveSetting("dogear_size_mode", "custom")
                G_reader_settings:saveSetting("dogear_custom_size_pct", pct)
                self:applySize()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
        })
    end
    table.insert(items, {
        text_func = function()
            local mode = G_reader_settings:readSetting("dogear_size_mode", "auto")
            local pct = G_reader_settings:readSetting("dogear_custom_size_pct", DEFAULT_PCT)
            if mode == "custom" and not self:isPresetPct(pct) then
                return string.format(_("自定义大小…（当前 %d%%）"), pct)
            end
            return _("自定义大小…")
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            UIManager:show(SpinWidget:new{
                title_text = _("折角大小（屏幕宽度百分比）"),
                info_text = _("图标大小按屏幕宽度（横边）的百分比计算。"),
                value = G_reader_settings:readSetting("dogear_custom_size_pct", DEFAULT_PCT),
                value_min = MIN_PCT,
                value_max = MAX_PCT,
                value_step = 1,
                default_value = DEFAULT_PCT,
                ok_always_enabled = true,
                wrap = false,
                callback = function(spin)
                    G_reader_settings:saveSetting("dogear_size_mode", "custom")
                    G_reader_settings:saveSetting("dogear_custom_size_pct", spin.value)
                    self:applySize()
                    if touchmenu_instance then touchmenu_instance:updateItems() end
                end,
            })
        end,
    })
    return items
end

function DogearStyle:isPresetPct(pct)
    for i, preset in ipairs(PRESET_PCTS) do
        if preset == pct then
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- 大小计算
-- ---------------------------------------------------------------------------

function DogearStyle:isCustomMode()
    return G_reader_settings:readSetting("dogear_size_mode", "auto") == "custom"
end

-- 图标大小 = 屏幕宽度（横边）的百分比
function DogearStyle:getCustomSizePx()
    local pct = G_reader_settings:readSetting("dogear_custom_size_pct", DEFAULT_PCT)
    pct = math.max(MIN_PCT, math.min(MAX_PCT, pct))
    return math.ceil(Screen:getWidth() * pct / 100)
end

function DogearStyle:getCurrentMargins()
    local configurable = self.ui.document.configurable
    return {
        configurable.h_page_margins[1],
        configurable.t_page_margin,
        configurable.h_page_margins[2],
        configurable.b_page_margin,
    }
end

function DogearStyle:applySize()
    local dogear = self.view and self.view.dogear
    if not dogear then
        return
    end
    if self:isCustomMode() then
        dogear:setupDogear(self:getCustomSizePx())
    elseif self.ui.rolling then
        dogear:onSetPageMargins(self.last_margins or self:getCurrentMargins())
    else
        -- PDF/DjVu 的原生默认即最大尺寸
        dogear:setupDogear(dogear.dogear_max_size)
    end
    -- 尺寸变化可能较大，用整页刷新避免墨水屏残影
    UIManager:setDirty(self.view.dialog, "ui")
end

-- ---------------------------------------------------------------------------
-- 给 ReaderDogear 打补丁：替换图标 / 让自定义大小生效
-- ---------------------------------------------------------------------------

function DogearStyle:patchDogear()
    local dogear = self.view and self.view.dogear
    if not dogear or not dogear.setupDogear or not dogear.onSetPageMargins then
        return
    end

    local plugin = self
    local orig_on_set_page_margins = dogear.onSetPageMargins

    local icon_file = self.path .. "/icons/dogear.svg"
    local icon_args
    if lfs.attributes(icon_file, "mode") == "file" then
        icon_args = { file = icon_file }
    else
        icon_args = { icon = "dogear.alpha" }
    end

    function dogear:setupDogear(new_dogear_size)
        if not new_dogear_size then
            new_dogear_size = self.dogear_max_size
        end
        -- 尺寸变化，或自定义图标尚未应用过时，重建控件
        if new_dogear_size ~= self.dogear_size or not plugin.icon_is_custom then
            self.dogear_size = new_dogear_size
            if self[1] then
                self[1]:free()
            end
            self.icon = IconWidget:new{
                file = icon_args.file,
                icon = icon_args.icon,
                rotation_angle = BD.mirroredUILayout() and 90 or 0,
                width = self.dogear_size,
                height = self.dogear_size,
                alpha = true, -- 保留透明通道，折角区域外不遮挡页面
            }
            self.top_pad = VerticalSpan:new{width = self.dogear_y_offset}
            self.vgroup = VerticalGroup:new{
                self.top_pad,
                self.icon,
            }
            self[1] = RightContainer:new{
                dimen = Geom:new{w = Screen:getWidth(), h = self.dogear_y_offset + self.dogear_size},
                self.vgroup,
            }
            plugin.icon_is_custom = true
        end
    end

    function dogear:onSetPageMargins(margins)
        if not self.ui.rolling then
            return
        end
        if plugin:isCustomMode() then
            self:setupDogear(plugin:getCustomSizePx())
        else
            -- 自动模式：走原生逻辑计算尺寸
            -- （内部会调用上面的 setupDogear，因此仍使用自定义图标）
            orig_on_set_page_margins(self, margins)
        end
        plugin.last_margins = margins
    end
end

return DogearStyle
