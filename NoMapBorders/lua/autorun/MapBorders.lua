AddCSLuaFile()

require("niknaks")
NikNaks()

print("Initialized NoMapBorders!")

local NoMapBordersOn = CreateConVar("NoMapBorders_enabled", "1", { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Включить/выключить NoMapBorders?")
local OnStart = CreateConVar("NoMapBorders_autoload", "0", { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Запускать при старте?")
local isdebug = CreateConVar("noborders_debug", "0", { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Отладка границ карты?")
local EasyMode = CreateConVar("noborders_EasyMode", "0", { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Облегчённый режим?")
local foffset = CreateConVar("nmb_front_offset", "0", { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Отступ границы-ловушки спереди.", -1000, 1000)
local boffset = CreateConVar("nmb_back_offset", "0", { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Отступ границы-ловушки сзади.", -1000, 1000)
local loffset = CreateConVar("nmb_left_offset", "0", { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Отступ границы-ловушки слева.", -1000, 1000)
local roffset = CreateConVar("nmb_right_offset", "0", { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Отступ границы-ловушки справа.", -1000, 1000)
local list_mode = CreateConVar("nmb_list_mode", "0", { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Режим списка (0 - exclude, 1 - include).", 0, 1)
local blacklist = CreateConVar("nmb_blacklist", "", { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Чёрный список (по классам).")

--[[
    Чёрный список объектов.
    Теперь вместо строки используется таблица с ключами-классами.
    Это значительно ускоряет проверку.
--]]
NMB_black_list = {}
if GetConVar("nmb_blacklist"):GetString() ~= "" then
	for k, v in pairs(string.Split(GetConVar("nmb_blacklist"):GetString(), " ")) do
		if v ~= " " and v ~= "" and v ~= nil then
			NMB_black_list[v] = true
		end
	end
end

local function UpdateBlacklistConVar(AppList)
    local blackstr = ""
    NMB_black_list = {}  -- Очищаем таблицу перед обновлением
    for _, v in ipairs(AppList:GetLines()) do
        local class = v:GetValue(1)
        blackstr = blackstr .. " " .. class
        NMB_black_list[class] = true  -- Заполняем таблицу NMB_black_list
    end
    RunConsoleCommand("nmb_blacklist", blackstr)
	RunConsoleCommand("update_nmb_blacklist")
end

concommand.Add("update_nmb_blacklist", function()
	if SERVER then
        NMB_black_list = {} -- Очищаем текущий список
        local blacklist_string = GetConVar("nmb_blacklist"):GetString()
        for k, v in pairs(string.Split(GetConVar("nmb_blacklist"):GetString(), " ")) do
			if v ~= " " and v ~= "" and v ~= nil then
				NMB_black_list[v] = true
			end
		end
        PrintTable(NMB_black_list) -- Для отладки
    end
end)

hook.Add("PopulateToolMenu", "NoMapBorders_settings", function()
    spawnmenu.AddToolMenuOption("Utilities", "Admin", "NoMap_settings_menu", "#NoMapBorders", "", "", function(panel)
        panel:Clear()
		panel:CheckBox("Включить NoMapBorders?", "NoMapBorders_enabled")
        panel:CheckBox("Запускать при старте?", "NoMapBorders_autoload")
        panel:CheckBox("Включить визуальную отладку?", "noborders_debug")
		--panel:CheckBox("Включить облегчённый режим? (более плавные перемещения\nна воздушном транспорте, но возможна поломка\nчастей автомобиля/самолёта и т.п.)", "noborders_EasyMode")
        panel:NumSlider("Отступ спереди: ", "nmb_front_offset", -1000, 1000)
        panel:NumSlider("Отступ сзади: ", "nmb_back_offset", -1000, 1000)
        panel:NumSlider("Отступ слева: ", "nmb_left_offset", -1000, 1000)
        panel:NumSlider("Отступ справа: ", "nmb_right_offset", -1000, 1000)
        panel:ControlHelp("Чёрный список объектов, которые не должны телепортироваться. Щёлкните правой кнопкой мыши по классу, чтобы удалить его из чёрного списка.")

        local AppList = vgui.Create("DListView")
        AppList:Dock(FILL)
        AppList:SetMultiSelect(false)
        AppList:AddColumn("Класс")

        -- Заполняем список текущими значениями из ConVar
        for _, class in ipairs(string.Split(GetConVar("nmb_blacklist"):GetString(), " ")) do
            if class ~= "" then
                AppList:AddLine(class)
            end
        end

        AppList:SetSize(panel:GetWide(), 150)

        -- Обработчик удаления класса из списка
        function AppList:OnRowRightClick(lineID, line)
            AppList:RemoveLine(lineID)
        end

        panel:AddItem(AppList)

        local DPanel = vgui.Create("DPanel")
        DPanel:SetSize(panel:GetWide(), 30)
        panel:AddItem(DPanel)

        local text = vgui.Create("DTextEntry", DPanel)
        text:SetSize(panel:GetWide() * 10, 25)
        text:Dock(FILL)
        text:SetPlaceholderText("Класс сущности (без лишних знаков).")

        local accept = vgui.Create("DButton", DPanel)
        accept:SetSize(panel:GetWide() * 6, 25)
        accept:Dock(RIGHT)
        accept:SetText("Добавить")

        -- Обработчик добавления класса в список
        accept.DoClick = function()
            local class = text:GetValue()
            if class ~= "" then
                AppList:AddLine(class)
                text:SetText("")
            end
        end

        -- Выпадающий список для выбора режима (чёрный/белый список)
        local listModeDropdown = vgui.Create("DComboBox", panel)
        listModeDropdown:SetPos(10, panel:GetTall() - 40)
        listModeDropdown:SetSize(panel:GetWide() - 20, 30)
        listModeDropdown:AddChoice("Exclude (Чёрный список)", "0")
        listModeDropdown:AddChoice("Include (Белый список)", "1")

        -- Устанавливаем текущее значение режима из ConVar
		if list_mode:GetInt() == 0 then
			listModeDropdown:SetValue("Exclude (Чёрный список)")
		else
			listModeDropdown:SetValue("Include (Белый список)")
		end
        --listModeDropdown:SetValue(list_mode:GetInt())

        listModeDropdown.OnChange = function(self, index, value)
            RunConsoleCommand("nmb_list_mode", value)
        end

        panel:AddItem(listModeDropdown)

        -- Кнопка "Применить изменения"
        local apply = panel:Button("Применить изменения")
        apply.DoClick = function()
            UpdateBlacklistConVar(AppList)
            RunConsoleCommand("RemoveMapBorders", "")
            print("Настройки NoMapBorder применены!")
        end
    end)
end)

concommand.Add( "RemoveMapBorders", function( ply, cmd, args, sargs )
    if SERVER and (ply:IsSuperAdmin() or NULL) then
		
		-- Удаляем старые во избежание конфликтов:
		for k, v in ipairs( ents.FindByClass( "mapborder_trigger_base" ) ) do
			v:Remove()
		end
		for k, v in ipairs( ents.FindByClass( "mapborder_trigger_front" ) ) do
			v:Remove()
		end
		for k, v in ipairs( ents.FindByClass( "mapborder_trigger_back" ) ) do
			v:Remove()
		end
		for k, v in ipairs( ents.FindByClass( "mapborder_trigger_left" ) ) do
			v:Remove()
		end
		for k, v in ipairs( ents.FindByClass( "mapborder_trigger_right" ) ) do
			v:Remove()
		end
		
		-- Получаем информацию о карте
		local ang = Angle(0,0,0)
		local zmin, zmax = game.GetWorld():GetModelBounds()
		local map = NikNaks.CurrentMap
		local mins, maxs = map:WorldMin(), map:WorldMax()
		
		-- Создаём ПЕРЕД карты

		local smins = Vector(maxs.x + foffset:GetInt(), maxs.y, zmin.z)
		local smaxs = Vector(maxs.x + foffset:GetInt(), mins.y, zmax.z)
		
		local pos = Vector((smins + smaxs) / 2)
		
		smins.x = smins.x + 400
		smins.z = zmin.z
		smaxs.x = smaxs.x - 400
		smaxs.z = zmax.z
		
		local front_border = ents.Create( "mapborder_trigger_base" )
		front_border:SetNWString("target_side", "back")
		front_border.target_side = "front"
		front_border.target_offset = Vector(750, 0, 0)
		front_border:SetName("mapborder_trigger_front")
		front_border.Mins = smins
		front_border.Maxs = smaxs
		front_border:Spawn()
		
		-- СОЗДАЁМ ЗДАНЮЮ ЧАСТЬ КАРТЫ
		
		smins = Vector(mins.x + boffset:GetInt(), mins.y, mins.z)
		smaxs = Vector(mins.x + boffset:GetInt(), maxs.y, maxs.z)
		
		pos = Vector((smins + smaxs) / 2)
		
		smins.x = smins.x + 400
		smins.z = zmin.z
		smaxs.x = smaxs.x - 400
		smaxs.z = zmax.z
		
		local back_border = ents.Create( "mapborder_trigger_base" )
		back_border:SetNWString("target_side", "front")
		back_border.target_side = "front"
		back_border.target_offset = Vector(-750, 0, 0)
		back_border:SetName("mapborder_trigger_back")
		back_border.Mins = smins
		back_border.Maxs = smaxs
		back_border:Spawn()
		
		-- СОЗДАЁМ ЛЕВО КАРТЫ

		smins = Vector(mins.x, maxs.y + loffset:GetInt(), zmin.z)
		smaxs = Vector(maxs.x, maxs.y + loffset:GetInt(), zmax.z)
		
		pos = Vector((smins + smaxs) / 2)
		
		smins.y = smins.y + 400
		smaxs.y = smaxs.y - 400
		
		local back_border = ents.Create( "mapborder_trigger_base" )
		back_border:SetNWString("target_side", "right")
		back_border.target_side = "right"
		back_border.target_offset = Vector(0, 750, 0)
		back_border:SetName("mapborder_trigger_left")
		back_border.Mins = smins
		back_border.Maxs = smaxs
		back_border:Spawn()
		
		-- СОЗДАЁМ ПРАВО КАРТЫ
		
		smins = Vector(mins.x, mins.y + roffset:GetInt(), zmin.z)
		smaxs = Vector(maxs.x, mins.y + roffset:GetInt(), zmax.z)
		
		pos = Vector((smins + smaxs) / 2)
		
		smins.y = smins.y + 400
		smaxs.y = smaxs.y - 400
		
		local back_border = ents.Create( "mapborder_trigger_base" )
		back_border:SetNWString("target_side", "left")
		back_border.target_side = "left"
		back_border.target_offset = Vector(0, -750, 0)
		back_border:SetName("mapborder_trigger_right")
		back_border.Mins = smins
		back_border.Maxs = smaxs
		back_border:Spawn()
		
	end 
end )

hook.Add( "InitPostEntity", "RemoveMapBorders_Start", function()
	timer.Simple(1, function() 
		if OnStart:GetBool() then
			RunConsoleCommand("RemoveMapBorders", "")
		end
	end)
end )

local map = NikNaks.CurrentMap

hook.Add( "PostDrawTranslucentRenderables", "DrawMapBorders", function( bDepth, bSkybox )
		if !isdebug:GetBool() then return end
		if ( bSkybox ) then return end
		local zmin, zmax = game.GetWorld():GetModelBounds()
		
		-- ЗАД
		
		local mins, maxs = map:WorldMin(), map:WorldMax()
		
		local smins = Vector(mins.x + boffset:GetInt(), mins.y, zmin.z)
		local smaxs = Vector(mins.x + boffset:GetInt(), maxs.y, zmax.z)
		local pos = Vector((smins + smaxs) / 2)
		
		local lmins = WorldToLocal( smins, Angle(0,0,0), pos, Angle(0,0,0) )
		local lmaxs = WorldToLocal( smaxs, Angle(0,0,0), pos, Angle(0,0,0) )
		lmins.x = lmins.x + 400
		lmins.z = zmin.z
		lmaxs.x = lmaxs.x - 400
		lmaxs.z = zmax.z
		
		render.DrawBox( smins, Angle(0,0,0), Vector(-100,-100,-100), Vector(100,100,100), Color(20, 100, 30, 190) )
		render.DrawBox( smaxs, Angle(0,0,0), Vector(-100,-100,-100), Vector(100,100,100), Color(20, 100, 30, 190) )
		
		render.DrawBox( pos, Angle(0,0,0), lmins, lmaxs, Color(120, 0, 130, 190) )
		--render.DrawBox( pos, Angle(0,0,0), smins, smaxs, Color(180, 0, 0, 150) )
		--render.DrawWireframeBox( pos, Angle(0,0,0), smins, smaxs, Color(180, 0, 0, 150) )
		
		-- ПЕРЕД
		
		local smins = Vector(maxs.x + foffset:GetInt(), maxs.y, zmin.z)
		local smaxs = Vector(maxs.x + foffset:GetInt(), mins.y, zmax.z)
		local pos = Vector((smins + smaxs) / 2)
		
		local lmins = WorldToLocal( smins, Angle(0,0,0), pos, Angle(0,0,0) )
		local lmaxs = WorldToLocal( smaxs, Angle(0,0,0), pos, Angle(0,0,0) )
		lmins.x = lmins.x + 400
		lmins.z = zmin.z
		lmaxs.x = lmaxs.x - 400
		lmaxs.z = zmax.z
		
		render.DrawBox( smins, Angle(0,0,0), Vector(-100,-100,-100), Vector(100,100,100), Color(20, 100, 30, 190) )
		render.DrawBox( smaxs, Angle(0,0,0), Vector(-100,-100,-100), Vector(100,100,100), Color(20, 100, 30, 190) )
		
		render.DrawBox( pos, Angle(0,0,0), lmins, lmaxs, Color(51, 18, 121, 190))
		
		-- ЛЕВО
		
		local smins = Vector(mins.x, maxs.y + loffset:GetInt(), zmin.z)
		local smaxs = Vector(maxs.x, maxs.y + loffset:GetInt(), zmax.z)
		local pos = Vector((smins + smaxs) / 2)
		
		local lmins = WorldToLocal( smins, Angle(0,0,0), pos, Angle(0,0,0) )
		local lmaxs = WorldToLocal( smaxs, Angle(0,0,0), pos, Angle(0,0,0) )
		lmins.y = lmins.y + 400
		lmins.z = zmin.z
		lmaxs.y = lmaxs.y - 400
		lmaxs.z = zmax.z
		
		render.DrawBox( pos, Angle(0,0,0), lmins, lmaxs, Color(20, 40, 230, 190) )
		
		-- ПРАВО
		
		local smins = Vector(mins.x, mins.y + roffset:GetInt(), zmin.z)
		local smaxs = Vector(maxs.x, mins.y + roffset:GetInt(), zmax.z)
		local pos = Vector((smins + smaxs) / 2)
		
		local lmins = WorldToLocal( smins, Angle(0,0,0), pos, Angle(0,0,0) )
		local lmaxs = WorldToLocal( smaxs, Angle(0,0,0), pos, Angle(0,0,0) )
		lmins.y = lmins.y + 400
		--lmins.z = zmin.z
		lmaxs.y = lmaxs.y - 400
		--lmaxs.z = zmax.z
		
		render.DrawBox( pos, Angle(0,0,0), lmins, lmaxs, Color(232, 167, 16, 190) )
		
		for k, v in ipairs( ents.FindByClass( "mapborder_showtrigger" ) ) do
			print("sas")
			local bmins, bmaxs = v:GetCollisionBounds()
			local pos = Vector((bmins + bmaxs) / 2)
			--cam.IgnoreZ( true )
			--render.DrawBox( pos, Angle(0,0,0), bmins, bmaxs, Color(180, 0, 0, 150) )
			--cam.IgnoreZ( false )
		end	
end )

