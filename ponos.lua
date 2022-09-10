local buffer = require("doubleBuffering")
local GUI = require("GUI")
local image = require("image")
local component = require("component")
local wrapper = require("ponos_wrapper")
local fs = require("filesystem")

--------------------------------------------------------------------------------
-- Constants and settings

local application = GUI.application()

local colors = {
    elevation1 = 0x0d0d0d,
    elevation2 = 0x1a1a1a,
    elevation3 = 0x292929,
    elevation4 = 0x4d4d4d,

    focusColor = 0x737373,
    focusTextColor = 0x000000,
    placeholderTextColor = 0x999999,

    contentColor = 0xFFFFFF,
    contentColor2 = 0xadadad,

    accentColor = 0xdd9afc,
    accentTextColor = 0x000000,
    accentPressedColor = 0x704e80,

    dangerColor = 0xff9f63,
    dangerTextColor = 0x000000,
    dangerPressedColor = 0x805032,

    successColor = 0x7eff73,
    successTextColor = 0x000000,
    successPressedColor = 0x3f8039
}

local settings = {
    proxyEnabled = false,
    proxyAddress = "",
    accentColor = nil,
    multiCoreEnabled = false,
    firstStart = true
}

local function saveSettings()
    table.toFile("/PonOS/settings", settings)
end

local function loadSettings()
    if not fs.exists("/PonOS/") then
        fs.makeDirectory("/PonOS/")
    end

    if not fs.exists("/PonOS/settings") then
        saveSettings()

        return
    end

    settings = table.fromFile("/PonOS/settings")

    if settings.accentColor ~= nil then
        colors.accentColor = settings.accentColor
    end
end

--------------------------------------------------------------------------------
-- Utility functions

local function calculateMultiCoreDimensions(anchor)
    local aX, aY, aZ = wrapper.ship.getPosition(anchor)

    local back, left, down = wrapper.ship.getDimNegative(anchor)
    local front, right, up = wrapper.ship.getDimPositive(anchor)

    for _, ship in ipairs(wrapper.ship.getAllControllersAddresses()) do
        if ship ~= anchor then
            local x, y, z = wrapper.ship.getPosition(ship)
            local dX, dY, dZ = aX - x, aY - y, aZ - z

            wrapper.ship.setDimNegative(back - dX, left - dZ, down - dY, ship)
            wrapper.ship.setDimPositive(front + dX, right + dZ, up + dY, ship)
        end
    end
end

--------------------------------------------------------------------------------
-- Window manager

local windowManager = {
    activeWindows = {}
}

windowManager.openWindow = function(window)
    if window == nil then
        return
    end

    for _, active_window in ipairs(windowManager.activeWindows) do
        if active_window.id == window.id then
            active_window.moveToFront(active_window)

            application:draw()

            return
        end
    end

    window.x = math.ceil(application.width / 2) - math.ceil(window.width / 2)
    window.y = math.ceil(application.height / 2) - math.ceil(window.height / 2)

    window.reload()

    table.insert(windowManager.activeWindows, window)
    application:addChild(window)
    application:draw()
end

windowManager.closeWindow = function(id)
    for i = 1, #windowManager.activeWindows do
        local activeWindow = windowManager.activeWindows[i]

        if activeWindow.id == id then
            activeWindow.close(activeWindow)
            table.remove(windowManager.activeWindows, i)

            return
        end
    end
end

windowManager.reloadWindows = function()
    for _, active_window in ipairs(windowManager.activeWindows) do
        active_window.reload()
    end

    application:draw()
end

--------------------------------------------------------------------------------
-- Custom UI objects and functions

local function getWindowLayout(window, columns, rows)
    return window:addChild(GUI.layout(4, 2, window.width - 6, window.height - 2, columns, rows))
end

GUI.drawShadow = function(x, y, width, height, transparency, thin)
    -- we really need to get rid of window shadows, so far this is the only way i figured
end

local function p_window(x, y, width, height, title, id)
    local window = GUI.window(x, y, width, height)

    window.id = id

    window.reload = function()

    end

    local prevDraw = window.draw

    window.draw = function(_w)
        prevDraw(_w)

        -- vertical frame lines
        buffer.drawLine(_w.x, _w.y + 1, _w.x, _w.y + height - 3, colors.elevation4, colors.elevation4, " ")
        buffer.drawLine(_w.x + width - 1, _w.y + 1, _w.x + width - 1, _w.y + height - 3, colors.elevation4, colors.elevation4, " ")

        -- horizontal bottom frame line
        buffer.drawText(_w.x + 2, _w.y + height - 1, colors.elevation4, string.rep("▀", width - 4), 0)

        -- bottom left corner pixel 1
        buffer.drawText(_w.x + 1, _w.y + height - 2, colors.elevation4, "▄", 0)

        -- bottom left corner pixel 2
        buffer.drawText(_w.x, _w.y + height - 2, colors.elevation4, "▀", 0)

        -- bottom right corner pixel 1
        buffer.drawText(_w.x + width - 2, _w.y + height - 2, colors.elevation4, "▄", 0)

        -- bottom right corner pixel 2
        buffer.drawText(_w.x + width - 1, _w.y + height - 2, colors.elevation4, "▀", 0)

        -- upper left corner pixel 1
        buffer.drawText(_w.x + 1, _w.y + 1, colors.elevation4, "▀", 0)

        -- upper left corner pixel 2
        buffer.drawText(_w.x, _w.y, colors.elevation4, "▄", 0)

        -- upper right corner pixel 1
        buffer.drawText(_w.x + width - 2, _w.y + 1, colors.elevation4, "▀", 0)

        -- upper right corner pixel 2
        buffer.drawText(_w.x + width - 1, _w.y, colors.elevation4, "▄", 0)
    end

    window.backgroundPanel = window:addChild(GUI.panel(2, 2, width - 2, height - 2, colors.elevation3))
    window.titlePanel = window:addChild(GUI.panel(2, 1, width - 2, 1, colors.elevation4))

    window.titleLabel = window:addChild(GUI.label(1, 1, width, height, colors.contentColor, title)):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)

    local closeButton = window:addChild(GUI.button(width - 3, 1, 1, 1, nil, colors.dangerColor, nil, colors.dangerPressedColor, "⬤"))

    closeButton.onTouch = function(_, object)
        windowManager.closeWindow(object.parent.id)
    end

    return window
end

local function p_accentButton(x, y, width, height, text)
    return GUI.roundedButton(x, y, width, height, colors.accentColor, colors.accentTextColor, colors.accentPressedColor, colors.accentTextColor, text)
end

local function p_dangerButton(x, y, width, height, text)
    return GUI.roundedButton(x, y, width, height, colors.dangerColor, colors.dangerTextColor, colors.dangerPressedColor, colors.dangerTextColor, text)
end

local function p_successButton(x, y, width, height, text)
    return GUI.roundedButton(x, y, width, height, colors.successColor, colors.successTextColor, colors.successPressedColor, colors.successTextColor, text)
end

local function p_input(x, y, width, height, text, placeholderText, eraseTextOnFocus, textMask)
    if type(text) ~= "string" then
        text = tostring(text)
    end

    local input = GUI.input(x, y, width, height, colors.elevation4, colors.contentColor2, colors.placeholderTextColor, colors.focusColor, colors.contentColor, text, placeholderText, eraseTextOnFocus, textMask)

    input.colors.cursor = colors.accentColor

    return input
end

local function p_intInput(x, y, width, height, text, placeholderText, eraseTextOnFocus, textMask)
    local input = p_input(x, y, width, height, text, placeholderText, eraseTextOnFocus, textMask)

    input.validator = function(objText)
        return objText:match("%d+")
    end

    return input
end

local function p_rangedIntInput(x, y, width, height, text, min, max, placeholderText, eraseTextOnFocus, textMask)
    local input = p_intInput(x, y, width, height, text, placeholderText, eraseTextOnFocus, textMask)

    input.min = min
    input.max = max

    input.onRangedInputFinished = function(number)

    end

    input.onInputFinished = function()
        num = tonumber(input.text)

        if not num then
            return
        end

        if num < input.min then
            num = input.min
        elseif num > input.max then
            num = input.max
        end

        input.text = tostring(num)

        input.onRangedInputFinished(num)
    end

    return input
end

local function p_switchAndLabel(x, y, width, text, state)
    local switch = GUI.switchAndLabel(x, y, width, 7, colors.accentColor, colors.focusColor, colors.contentColor2, colors.contentColor2, text, state)

    return switch
end

local function p_multiCoreView(x, y)
    local layout = GUI.layout(x, y, 16, 14, 1, 1)

    layout:setDirection(1, 1, GUI.DIRECTION_VERTICAL)
    layout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_RIGHT, GUI.ALIGNMENT_VERTICAL_TOP)
    layout:setSpacing(1, 1, 0, 0)

    local canvas = layout:setPosition(1, 1, layout:addChild(GUI.brailleCanvas(x, y, 16, 8)))

    layout:setPosition(1, 1, layout:addChild(GUI.text(1, 1, 0x0, "")))
    local active = layout:setPosition(1, 1, layout:addChild(GUI.label(1, 1, 16, 1, colors.accentColor, "N/A")))
    local ready = layout:setPosition(1, 1, layout:addChild(GUI.label(1, 1, 16, 1, colors.successColor, "N/A")))
    local cooldown = layout:setPosition(1, 1, layout:addChild(GUI.label(1, 1, 16, 1, colors.dangerColor, "N/A")))

    layout.updateShips = function()
        local ship_amounts = { 0, 0, 0 }

        local stats = wrapper.ship.getCoreStats()

        local itemSize = 5
        local itemSpacing = 4
        local itemCount = #stats

        local rows = math.ceil(itemCount / 4)

        canvas:clear()

        for r = 0, rows - 1 do
            local cols

            if r == rows - 1 then
                cols = itemCount - (r * 4)
            else
                cols = 4
            end

            for c = 0, cols - 1 do
                local status = stats[((r * 4) + c) + 1]
                local color

                if status == "cooldown" then
                    color = colors.dangerColor

                    ship_amounts[1] = ship_amounts[1] + 1
                elseif status == "active" then
                    color = colors.accentColor

                    ship_amounts[2] = ship_amounts[2] + 1
                elseif status == "ready" then
                    color = colors.successColor

                    ship_amounts[3] = ship_amounts[3] + 1
                else
                    color = 0x0000FF
                end

                canvas:fill(1 + (c * itemSize) + (c * itemSpacing), 1 + (r * itemSize) + (r * itemSpacing), itemSize, itemSize, true, color)
            end
        end

        cooldown.text = string.format("%s on cooldown", ship_amounts[1])
        active.text = string.format("%s active", ship_amounts[2])
        ready.text = string.format("%s ready", ship_amounts[3])
    end

    return layout
end

local function p_appButton(x, y, name, id)
    local appButt = GUI.object(x, y, 8, 5)

    appButt.name = name
    appButt.id = id

    appButt.image = image.load("/PonOS/pics/icon_" .. appButt.id .. ".pic")

    appButt.onTouch = function()

    end

    appButt.eventHandler = function(_, object, e1)
        if e1 == "touch" then
            object.onTouch()
        end
    end

    appButt.draw = function(object)
        buffer.drawImage(object.x, object.y, object.image)

        local xCentered = object.x + math.ceil(object.width / 2) - math.ceil(string.len(name) / 2)

        buffer.drawText(xCentered, object.y + object.height - 1, colors.contentColor, name, 0)
    end

    return appButt
end

local function p_appBar(x, y, width, apps)
    local container = GUI.container(x, y, width, 7)

    container.onAppSelected = function(id)

    end

    container:addChild(GUI.panel(1, 1, container.width, container.height, colors.elevation2))
    container:addChild(GUI.label(1, container.height, container.width, 1, colors.elevation3, string.rep("▄", container.width)))

    local layout = container:addChild(GUI.layout(1, 1, container.width, container.height, 1, 1))
    layout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
    layout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_CENTER)
    layout:setSpacing(1, 1, 4)
    layout:setMargin(1, 1, 2, 0)

    for _, app in ipairs(apps) do
        local button = layout:setPosition(1, 1, layout:addChild(p_appButton(1, 1, app[1], app[2])))

        button.onTouch = function()
            container.onAppSelected(button.id)
        end
    end

    return container
end

local function p_titleDelimiterBar(x, y, width, text)
    local object = GUI.object(x, y, width, 2)

    object.text = text

    object.draw = function(_w)
        buffer.drawText(_w.x + 2, _w.y, colors.contentColor, _w.text)
        buffer.drawText(_w.x + 1, _w.y + 1, colors.contentColor2, string.rep("▔", _w.width - 2))
    end

    return object
end

--------------------------------------------------------------------------------
-- Windows (apps)

local windows = {
    debug = function()
        local window = p_window(1, 1, 30, 30, "Debug", "debug")

        window:addChild(GUI.image(4, 3, image.load("/PonOS/pics/debug.pic")))

        return window
    end,

    jump = function()
        if not wrapper.shipApiAvailable() then
            GUI.alert("Ship is not available.")

            return nil
        end

        local window = p_window(40, 20, 50, 21, "Jump controls", "jump")
        local currentController

        local function setNextController(jump)
            if settings.multiCoreEnabled then
                currentController = wrapper.ship.getNextMultiCoreController()

                if jump then
                    wrapper.ship.setExclusivelyOnline(currentController)

                    window.reload()
                else
                    wrapper.ship.setCommand("MANUAL", currentController)
                end
            else
                currentController = wrapper.ship.getComponent().address
            end
        end

        window.reload = function()
            setNextController(false)

            local max = wrapper.ship.getMaxJumpDistance(currentController)
            local pX, pY, pZ = wrapper.ship.getDimPositive(currentController)
            local nX, nY, nZ = wrapper.ship.getDimNegative(currentController)

            local maxX = max + pX + nX
            local maxY = max + pY + nY
            local maxZ = max + pZ + nZ

            window.xLabel.text = string.format("X (%s - %s)", pX + nX, maxX)
            window.yLabel.text = string.format("Y (%s - %s)", pY + nY, maxY)
            window.zLabel.text = string.format("Z (%s - %s)", pZ + nZ, maxZ)

            window.xInp.min = -maxX
            window.xInp.max = maxX

            window.yInp.min = -maxY
            window.yInp.max = maxY

            window.zInp.min = -maxZ
            window.zInp.max = maxZ

            window.multiCoreView.hidden = not settings.multiCoreEnabled

            if not window.multiCoreView.hidden then
                window.multiCoreView.updateShips()
            end
        end

        local layout = getWindowLayout(window, 1, 2)

        -- Control buttons --

        layout:setDirection(1, 2, GUI.DIRECTION_HORIZONTAL)
        layout:setAlignment(1, 2, GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_BOTTOM)

        local jumpButton = layout:setPosition(1, 2, layout:addChild(p_accentButton(1, 1, 6, 3, "Jump")))

        local hyperButton = layout:setPosition(1, 2, layout:addChild(p_dangerButton(1, 1, 12, 3, "Hyper jump")))

        local rotateButton = layout:setPosition(1, 2, layout:addChild(p_accentButton(1, 1, 8, 3, "Rotate")))

        local cancelButton = layout:setPosition(1, 2, layout:addChild(p_dangerButton(1, 1, 11, 3, "Stop Jump")))

        -- Second layout --

        layout:setFitting(1, 1, true, true, 0, 0)
        layout:setRowHeight(1, GUI.SIZE_POLICY_RELATIVE, 0.8)

        local layout2 = layout:setPosition(1, 1, layout:addChild(GUI.layout(1, 1, 1, 1, 2, 1)))

        -- Co-ordinates input

        layout2:setFitting(1, 1, true, false, 0, 0)

        window.xLabel = layout2:setPosition(1, 1, layout2:addChild(GUI.label(1, 1, 1, 1, colors.contentColor, "X (?-?)")))
        window.xInp = layout2:setPosition(1, 1, layout2:addChild(p_rangedIntInput(1, 1, 1, 1, "0", 0, 0)))

        window.yLabel = layout2:setPosition(1, 1, layout2:addChild(GUI.label(1, 1, 1, 1, colors.contentColor, "Y (?-?)")))
        window.yInp = layout2:setPosition(1, 1, layout2:addChild(p_rangedIntInput(1, 1, 1, 1, "0", 0, 0)))

        window.zLabel = layout2:setPosition(1, 1, layout2:addChild(GUI.label(1, 1, 1, 1, colors.contentColor, "Z (?-?)")))
        window.zInp = layout2:setPosition(1, 1, layout2:addChild(p_rangedIntInput(1, 1, 1, 1, "0", 0, 0)))

        -- Multicore view

        layout2:setSpacing(2, 1, 0)
        layout2:setAlignment(2, 1, GUI.ALIGNMENT_HORIZONTAL_RIGHT, GUI.ALIGNMENT_VERTICAL_TOP)
        layout2:setMargin(2, 1, 1, 2)

        window.multiCoreView = layout2:setPosition(2, 1, layout2:addChild(p_multiCoreView(1, 1)))

        ------------------------------------------------

        jumpButton.onTouch = function()
            setNextController(true)

            wrapper.ship.jump(0, tonumber(window.xInp.text), tonumber(window.yInp.text), tonumber(window.zInp.text), false, currentController)
        end

        hyperButton.onTouch = function()
            setNextController(true)

            wrapper.ship.jump(nil, nil, nil, nil, true, currentController)
        end

        cancelButton.onTouch = function()
            if currentController then
                wrapper.ship.cancelJump(currentController)
            end
        end

        rotateButton.onTouch = function()
            GUI.alert("Not implemented yet, sorry")
        end

        return window
    end,

    s_info = function()
        -- Ported from IS2. TODO: rewrite

        local window = p_window(40, 20, 57, 13, "Ship information", "s_info")

        window.reload = function()
            local x, y, z = wrapper.ship.getPosition()
            local dim = wrapper.ship.getDimensionType()
            if dim == 0 then
                dim = "Space"
            elseif dim == 1 then
                dim = "Hyperspace"
            else
                dim = "Unknown"
            end
            local oX, oZ = wrapper.ship.getOrientation()
            local assembly
            if wrapper.ship.isAssemblyValid() then
                assembly = "Valid"
            else
                assembly = "Invalid"
            end
            local shipEnergy = wrapper.ship.getShipEnergy()
            local maxEnergy = wrapper.ship.getMaxShipEnergy()
            local energyPercents = math.floor((shipEnergy / maxEnergy) * 100)

            window.xLabel.text = x
            window.yLabel.text = y
            window.zLabel.text = z
            window.dimLabel.text = dim
            window.oLabel.text = string.format("X: %s, Z: %s", oX, oZ)
            window.nameLabel.text = string.format("Name: %s", wrapper.ship.getShipName())
            window.massLabel.text = string.format("Mass: %s", wrapper.ship.getShipMass())
            window.assLabel.text = string.format("Assembly: %s", assembly)
            window.energyBar.value = energyPercents
        end

        window:addChild(GUI.label(2, 3, 8, 1, colors.contentColor, "Coordinates:"))
        window.xLabel = window:addChild(GUI.label(2, 4, 8, 1, colors.contentColor, ""))
        window.yLabel = window:addChild(GUI.label(2, 5, 8, 1, colors.contentColor, ""))
        window.zLabel = window:addChild(GUI.label(2, 6, 8, 1, colors.contentColor, ""))

        window:addChild(GUI.label(2, 8, 8, 1, colors.contentColor, "Dimension:"))
        window.dimLabel = window:addChild(GUI.label(2, 9, 8, 1, colors.contentColor, ""))

        window:addChild(GUI.label(2, 11, 8, 1, colors.contentColor, "Orientation:"))
        window.oLabel = window:addChild(GUI.label(2, 12, 8, 1, colors.contentColor, ""))

        window.nameLabel = window:addChild(GUI.label(17, 3, 8, 1, colors.contentColor, ""))
        window.massLabel = window:addChild(GUI.label(17, 5, 8, 1, colors.contentColor, ""))

        window.assLabel = window:addChild(GUI.label(17, 7, 8, 1, colors.contentColor, ""))

        window.energyBar = window:addChild(GUI.progressBar(17, 9, 40, colors.accentColor, colors.dangerColor, colors.contentColor, 0, true, true, "Ship energy: ", "%"))

        return window
    end
}

--------------------------------------------------------------------------------
-- Fullscreen containers

local fullScreenContainers = {}

fullScreenContainers.base = function(name, columns, rows)
    local container = GUI.addBackgroundContainer(application, true, true, name)

    container.panel.colors.transparency = 0.2
    container.panel.eventHandler = function()

    end

    container.layout2 = container.layout:setPosition(1, 1, container.layout:addChild(GUI.layout(1, 1, math.ceil(container.width / 2), math.ceil(container.height / 2), columns, rows)))

    return container
end

fullScreenContainers.baseSettings = function(name, columns, rows)
    local container = fullScreenContainers.base(name, columns, rows)

    container.actionLayout = container.layout:setPosition(1, 1, container.layout:addChild(GUI.layout(1, 1, container.layout2.width, 5, 1, 1)))

    container.actionLayout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)

    return container
end

fullScreenContainers.about = function()
    local container = fullScreenContainers.base("About", 1, 1)

    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.image(1, 1, image.load("/PonOS/pics/about_logo.pic"))))

    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.label(1, 1, 10, 1, colors.contentColor, "Shitcoded by:"))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.label(1, 1, 10, 1, colors.contentColor2, "Iterator"))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.label(1, 1, 10, 1, colors.contentColor, "Special thanks:"))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.label(1, 1, 10, 1, colors.contentColor2, "ECS - amazing graphics libraries"))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)

    container.layout:setPosition(1, 1, container.layout:addChild(p_accentButton(1, 1, 11, 3, "Close"))).onTouch = function()
        container:remove()
    end
end

fullScreenContainers.settingsShip = function(shipAddr, fromMulticore)
    local container = fullScreenContainers.baseSettings("Edit ship", 1, 1)

    local back, left, down = wrapper.ship.getDimNegative(shipAddr)
    local front, right, up = wrapper.ship.getDimPositive(shipAddr)
    local name = wrapper.ship.getShipName(shipAddr)

    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.label(1, 1, 9, 1, colors.contentColor2, "Ship Name")))
    container.layout2:setPosition(1, 1, container.layout2:addChild(p_input(1, 1, 20, 1, name))).onInputFinished = function(_, object)
        name = object.text
    end

    local layout3 = container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.layout(1, 1, container.layout2.width, container.layout2.height - 5, 2, 1)))

    layout3:setDirection(1, 1, GUI.DIRECTION_VERTICAL)
    layout3:setDirection(2, 1, GUI.DIRECTION_VERTICAL)
    layout3:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_RIGHT, GUI.ALIGNMENT_VERTICAL_TOP)
    layout3:setAlignment(2, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
    layout3:setMargin(1, 1, 3, 0)
    layout3:setMargin(2, 1, 3, 0)

    layout3:setPosition(1, 1, layout3:addChild(GUI.label(1, 1, 5, 1, colors.contentColor2, "Front")))
    layout3:setPosition(1, 1, layout3:addChild(p_intInput(1, 1, 6, 1, front))).onInputFinished = function(_, object)
        front = tonumber(object.text)
    end

    layout3:setPosition(2, 1, layout3:addChild(GUI.label(1, 1, 4, 1, colors.contentColor2, "Back")))
    layout3:setPosition(2, 1, layout3:addChild(p_intInput(1, 1, 6, 1, back))).onInputFinished = function(_, object)
        back = tonumber(object.text)
    end

    layout3:setPosition(1, 1, layout3:addChild(GUI.label(1, 1, 2, 1, colors.contentColor2, "Up")))
    layout3:setPosition(1, 1, layout3:addChild(p_intInput(1, 1, 6, 1, up))).onInputFinished = function(_, object)
        up = tonumber(object.text)
    end

    layout3:setPosition(2, 1, layout3:addChild(GUI.label(1, 1, 4, 1, colors.contentColor2, "Down")))
    layout3:setPosition(2, 1, layout3:addChild(p_intInput(1, 1, 6, 1, down))).onInputFinished = function(_, object)
        down = tonumber(object.text)
    end

    layout3:setPosition(1, 1, layout3:addChild(GUI.label(1, 1, 4, 1, colors.contentColor2, "Left")))
    layout3:setPosition(1, 1, layout3:addChild(p_intInput(1, 1, 6, 1, left))).onInputFinished = function(_, object)
        left = tonumber(object.text)
    end

    layout3:setPosition(2, 1, layout3:addChild(GUI.label(1, 1, 5, 1, colors.contentColor2, "Right")))
    layout3:setPosition(2, 1, layout3:addChild(p_intInput(1, 1, 6, 1, right))).onInputFinished = function(_, object)
        right = tonumber(object.text)
    end

    container.actionLayout:setPosition(1, 1, container.actionLayout:addChild(p_accentButton(1, 1, 10, 3, "Apply"))).onTouch = function()
        wrapper.ship.setShipName(name, shipAddr)
        wrapper.ship.setDimNegative(back, left, down, shipAddr)
        wrapper.ship.setDimPositive(front, right, up, shipAddr)
    end

    container.actionLayout:setPosition(1, 1, container.actionLayout:addChild(p_successButton(1, 1, 10, 3, "Done"))).onTouch = function()
        container:remove()

        if fromMulticore then
            fullScreenContainers.multiCoreSetup(shipAddr)
        else
            fullScreenContainers.settingsMain()
        end
    end
end

fullScreenContainers.multiCoreSetup = function(shipAddr)
    local container = fullScreenContainers.baseSettings("MultiCore Setup", 1, 1)

    container.layout2:setDirection(1, 1, GUI.DIRECTION_VERTICAL)
    container.layout2:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    container.layout2:setSpacing(1, 1, 0)

    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.label(1, 1, 10, 1, colors.contentColor2, "In order to setup MultiCore, you are required to"))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.label(1, 1, 10, 1, colors.contentColor2, "select an \"anchor\" core and configure its sizes."))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.label(1, 1, 10, 1, colors.contentColor2, "After that - just press the Begin button, and the"))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.label(1, 1, 10, 1, colors.contentColor2, "program will calculate every other core dimensions"))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.label(1, 1, 10, 1, colors.contentColor2, "automatically."))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)

    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.label(1, 1, 10, 1, colors.contentColor2, "Please, select an anchor core to configure:"))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.label(1, 1, 10, 1, colors.contentColor2, ""))):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)

    local comboBox = container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.comboBox(1, 1, 50, 1, colors.elevation4, colors.contentColor2, colors.elevation2, colors.contentColor2)))

    for _, addr in ipairs(wrapper.ship.getAllControllersAddresses()) do
        comboBox:addItem(addr)
    end

    comboBox.onItemSelected = function(index)
        container:remove()
        fullScreenContainers.settingsShip(comboBox:getItem(index).text, true)
    end

    ---------------------------

    container.actionLayout:setPosition(1, 1, container.actionLayout:addChild(p_dangerButton(1, 1, 10, 3, "Cancel"))).onTouch = function()
        container:remove()
        fullScreenContainers.settingsMain()
    end

    local beginButt = container.actionLayout:setPosition(1, 1, container.actionLayout:addChild(p_successButton(1, 1, 10, 3, "Begin")))

    beginButt.onTouch = function()
        local anchor = comboBox:getItem(comboBox.selectedItem).text

        calculateMultiCoreDimensions(anchor)

        settings.multiCoreEnabled = true
        saveSettings()
        GUI.alert("Dim calculation completed.")

        container:remove()
        fullScreenContainers.settingsMain()
    end

    if shipAddr ~= nil then
        beginButt.disabled = false

        for i = 1, comboBox:count() do
            local item = comboBox:getItem(i)

            if item.text == shipAddr then
                comboBox.selectedItem = i

                break
            end
        end
    else
        beginButt.disabled = true
        comboBox.selectedItem = nil
    end
end

fullScreenContainers.settingsMain = function()
    local container = fullScreenContainers.baseSettings("Settings", 2, 1)

    -- First column
    container.layout2:setDirection(1, 1, GUI.DIRECTION_VERTICAL)
    container.layout2:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
    container.layout2:setMargin(1, 1, 3, 1)
    container.layout2:setFitting(1, 1, true, false, 5)

    container.layout2:setPosition(1, 1, container.layout2:addChild(p_titleDelimiterBar(1, 1, 1, "PonOS Proxy")))

    local proxySwitch = container.layout2:setPosition(1, 1, container.layout2:addChild(p_switchAndLabel(1, 1, 1, "Enable proxy", settings.proxyEnabled)))

    container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.label(1, 1, 10, 1, colors.contentColor2, "Address:")))
    local proxyInput = container.layout2:setPosition(1, 1, container.layout2:addChild(p_input(1, 1, 1, 1, settings.proxyAddress)))

    container.layout2:setPosition(1, 1, container.layout2:addChild(p_titleDelimiterBar(1, 1, 1, "Appearance")))

    local selector = container.layout2:setPosition(1, 1, container.layout2:addChild(GUI.colorSelector(1, 1, 1, 3, colors.accentColor, "Accent Color")))

    -- second column

    container.layout2:setDirection(2, 1, GUI.DIRECTION_VERTICAL)
    container.layout2:setAlignment(2, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
    container.layout2:setMargin(2, 1, 3, 1)
    container.layout2:setFitting(2, 1, true, false, 5)

    container.layout2:setPosition(2, 1, container.layout2:addChild(p_titleDelimiterBar(1, 1, 1, "Ship Settings")))

    container.layout2:setPosition(2, 1, container.layout2:addChild(p_accentButton(1, 1, 1, 3, "Edit ship name and dimensions"))).onTouch = function()
        if not wrapper.shipApiAvailable() then
            GUI.alert("Ship is not available.")

            return
        end

        container:remove()
        fullScreenContainers.settingsShip()
    end

    container.layout2:setPosition(2, 1, container.layout2:addChild(p_switchAndLabel(1, 1, 1, "Enable MultiCore", settings.multiCoreEnabled))).switch.onStateChanged = function(state)
        if state.state then
            if not wrapper.ship.hasMultipleControllers() then
                state:setState(false)

                GUI.alert("You need to have at least 2 cores connected in order to use MultiCore.")

                return
            end

            container:remove()
            fullScreenContainers.multiCoreSetup()
        else
            settings.multiCoreEnabled = false
            saveSettings()
        end
    end

    ----------------------------

    container.actionLayout:setPosition(1, 1, container.actionLayout:addChild(p_dangerButton(1, 1, 10, 3, "Cancel"))).onTouch = function()
        container:remove()
        application:draw()
    end

    container.actionLayout:setPosition(1, 1, container.actionLayout:addChild(p_successButton(1, 1, 10, 3, "Save"))).onTouch = function()
        settings.proxyEnabled = proxySwitch.switch.state
        settings.proxyAddress = proxyInput.text
        settings.accentColor = selector.color

        saveSettings()

        container:remove()
        application:draw()
    end
end

--------------------------------------------------------------------------------
-- Startup code

loadSettings()

-- Main container

application:addChild(GUI.panel(1, 1, application.width, application.height, colors.elevation1))

local menu = application:addChild(GUI.menu(1, 1, application.width, colors.elevation4, colors.contentColor, colors.accentColor, colors.accentPressedColor))

local contextMenu = menu:addContextMenu("PonOS")
contextMenu:addItem("Open debug window").onTouch = function()
    windowManager.openWindow(windows["debug"]())
end

local wrapperButton = contextMenu:addItem("Switch demo mode (" .. tostring(wrapper.demoMode) .. ")")
wrapperButton.onTouch = function()
    wrapper.demoMode = not wrapper.demoMode

    wrapperButton.text = "Switch demo mode (" .. tostring(wrapper.demoMode) .. ")"
end

contextMenu:addItem("Settomgs").onTouch = function()
    fullScreenContainers.settingsMain()
end

contextMenu:addItem("About").onTouch = function()
    fullScreenContainers.about()
end

contextMenu:addSeparator()

contextMenu:addItem("Exit").onTouch = function()
    application:stop()

    component.gpu.setBackground(0x000000)
    component.gpu.setForeground(0xFFFFFF)
    require("term").clear()
    print("Thanks for using PonOS!")
end

menu:addItem("Refresh info", colors.contentColor2).onTouch = function()
    windowManager.reloadWindows()
end

bar = application:addChild(p_appBar(1, 2, application.width, {
    { "Jump Menu", "jump" },
    { "Ship Info", "s_info" },
    { "Warp Radar", "radar" },
    { "Crew", "crew" },
    { "Cloaking", "cloaking" },
    { "Transporter", "transporter" }
}))

bar.onAppSelected = function(id)
    window = windows[id]()

    windowManager.openWindow(window)
end

if settings.firstStart then
    settings.firstStart = false
    saveSettings()

    fullScreenContainers.about()
end

--------------------------------------------------------------------------------

application:draw(true)
application:start()