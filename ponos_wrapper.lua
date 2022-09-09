local component = require("component")
local event = require("event")
local thread = require("thread")

local wrapper = {}

wrapper.demoMode = false -- Demo mode prevents actual components from being used. Makes debugging easier.
wrapper.ship = {} -- ShipController
wrapper.radar = {} -- Radar
wrapper.transporter = {} -- MatterOverdrive Transporter

wrapper.ship.controllerTimes = {}

local t = thread.create(function()
    while true do
        local addr = event.pull("shipCoreCooldownDone")

        wrapper.ship.controllerTimes[addr] = 0
    end
end)

t:detach()

wrapper.shipApiAvailable = function()
    return component.isAvailable("warpdriveShipController") or wrapper.demoMode
end

wrapper.radarApiAvailable = function()
    return component.isAvailable("warpdriveRadar") or wrapper.demoMode
end

wrapper.transporterApiAvailable = function()
    return component.isAvailable("mo_transporter") or wrapper.demoMode
end

wrapper.toggleDemoMode = function()
    wrapper.demoMode = not wrapper.demoMode
end

wrapper.ship.getComponent = function(addr)
    if addr ~= nil then
        return component.proxy(addr)
    else
        return component.warpdriveShipController
    end
end

wrapper.radar.getComponent = function()
    return component.warpdriveRadar
end

wrapper.transporter.getComponent = function()
    return component.mo_transporter
end

wrapper.transporter.setCoordinates = function(x, y, z)
    if wrapper.demoMode then
        return
    end

    wrapper.transporter.getComponent().setX(0, x)
    wrapper.transporter.getComponent().setY(0, y)
    wrapper.transporter.getComponent().setZ(0, z)
end

wrapper.radar.scan = function(radius)
    -- Scans within the specified radius. An event containing scan index is pushed when the scan is done.
    if wrapper.demoMode then
        event.push("is2wrapperRadarScan", -1)
        return
    end

    wrapper.radar.getComponent().radius(radius)
    wrapper.radar.getComponent().start()

    os.sleep(wrapper.radar.getComponent().getScanDuration(radius))

    event.push("is2wrapperRadarScan", wrapper.radar.getComponent().getResultsCount())
end

wrapper.radar.getResult = function(index)
    if wrapper.demoMode then
        return nil
    end

    local success, objectType, name, x, y, z, mass = wrapper.radar.getComponent().getResult(index)

    if not success then
        return nil
    end

    return objectType, name, x, y, z, mass
end

wrapper.radar.getMaxRadarEnergy = function()
    -- Gets maximum radar energy
    if wrapper.demoMode then
        return 100000000
    end

    local _, maxEnergy = wrapper.radar.getComponent().energy()

    return maxEnergy
end

wrapper.radar.getRadarEnergy = function()
    -- Gets current radar energy
    if wrapper.demoMode then
        return 10000
    end

    local energy = wrapper.radar.getComponent().energy()

    return energy
end

wrapper.radar.getRequiredEnergy = function(radius)
    -- Get required energy for a scan
    if wrapper.demoMode then
        return 20
    end

    return wrapper.radar.getComponent().getEnergyRequired(radius)
end

wrapper.ship.hasMultipleControllers = function()
    -- Returns true if multiple controllers are connected at the moment
    if wrapper.demoMode then
        return true
    end

    return #component.list("warpdriveShipController") > 1
end

wrapper.ship.getCoreStats = function()
    -- Return a list of strings describing each core.
    -- "active" means that this core's command is not OFFLINE
    -- "ready" means that this core hasn't been used recently (40 seconds)
    -- "cooldown" means that this core has been used recently and is currently on cooldown

    if wrapper.demoMode then
        return {"ready", "active", "cooldown", "cooldown", "ready", "cooldown", "ready", "ready", "ready", "ready", "ready", "ready", "ready", "ready", "ready", "ready", "ready", "ready"}
    end

    local results = {}

    for ship, _ in pairs(component.list("warpdriveShipController")) do
       local shipTime = wrapper.ship.controllerTimes[ship]

        if shipTime ~= nil and shipTime ~= 0 then
            table.insert(results, "cooldown")
        elseif wrapper.ship.getCommand(ship) ~= "OFFLINE" then
            table.insert(results, "active")
        else
            table.insert(results, "ready")
        end
    end

    return results
end

wrapper.ship.getAllControllersAddresses = function()
    -- Returns a list of all attached ship controllers' addresses
    if wrapper.demoMode then
        return {"Non-existent address 1", "Non-existent address 2", "Non-existent address 3"}
    end

    local addresses = {}

    for k, _ in pairs(component.list("warpdriveShipController")) do
        table.insert(addresses, k)
    end

    return addresses
end

wrapper.ship.getNextMultiCoreController = function()
    -- Returns a controller that doesn't have a cooldown or a controller with least cooldown.
    -- that's shitcode
    -- pls forgive me
    -- (and write a better thing)

    if wrapper.demoMode then
        return nil
    end

    local results = {}

    for ship, _ in pairs(component.list("warpdriveShipController")) do
        local shipTime = 0

        local savedShipTime = wrapper.ship.controllerTimes[ship]

        if savedShipTime ~= nil then
            shipTime = savedShipTime
        end

        results[ship] = shipTime
    end

    local sorted = {}
    for k, v in pairs(results) do
        table.insert(sorted, { k, v })
    end

    table.sort(sorted, function(a, b)
        return a[2] < b[2]
    end)

    return sorted[1][1]
end

wrapper.ship.setExclusivelyOnline = function(addr)
    -- Disables all cores and sets specified as online
    for ship_addr, _ in pairs(component.list("warpdriveShipController")) do
        if ship_addr == addr then
            wrapper.ship.setCommand("IDLE", ship_addr)
        else
            wrapper.ship.setCommand("OFFLINE", ship_addr)
        end
    end
end

wrapper.ship.getDimensionType = function(addr)
    -- 0 - Space, 1 - Hyperspace, 2 - Unknown (WarpDrive is weird)
    if wrapper.demoMode then
        return 0
    end

    if wrapper.ship.getComponent(addr).isInSpace() then
        return 0
    elseif wrapper.ship.getComponent().isInHyperspace() then
        return 1
    else
        return 2
    end
end

wrapper.ship.setCommand = function(command, addr)
    -- Sets ship command mode.
    if wrapper.demoMode then
        return
    end

    wrapper.ship.getComponent(addr).command(command)
end

wrapper.ship.getCommand = function(addr)
    -- Gets ship command mode.
    if wrapper.demoMode then
        return "IDLE"
    end

    return wrapper.ship.getComponent(addr).command()
end

wrapper.ship.getPosition = function(addr)
    -- X, Y, Z of ship.
    if wrapper.demoMode then
        return 1, 2, 3
    end

    local x, y, z = wrapper.ship.getComponent(addr).position()

    return x, y, z
end

wrapper.ship.getDimPositive = function(addr)
    -- Gets positive ship dimensions (Front, Right, Up)
    if wrapper.demoMode then
        return 10, 5, 7
    end

    return wrapper.ship.getComponent(addr).dim_positive()
end

wrapper.ship.getDimNegative = function(addr)
    -- Gets negative ship dimensions (Back, Left, Down)
    if wrapper.demoMode then
        return 4, 3, 6
    end

    return wrapper.ship.getComponent(addr).dim_negative()
end

wrapper.ship.getMaxJumpDistance = function(addr)
    -- Gets base maximum jump value. The real maximum for an axis is base + dim_positive + dim_negative
    if wrapper.demoMode then
        return 250
    end

    _, max = wrapper.ship.getComponent(addr).getMaxJumpDistance()

    return max
end

wrapper.ship.getMovement = function(addr)
    -- Gets last jump move coordinates
    if wrapper.demoMode then
        return 40, 30, 20
    end

    return wrapper.ship.getComponent(addr).movement()
end

wrapper.ship.setMovement = function(x, y, z, addr)
    -- Sets ship movement for jump
    if wrapper.demoMode then
        return
    end

    wrapper.ship.getComponent(addr).movement(x, y, z)
end

wrapper.ship.setRotationSteps = function(rotationSteps, addr)
    -- Sets ship rotation steps for jump
    if wrapper.demoMode then
        return
    end

    wrapper.ship.getComponent(addr).rotationSteps(rotationSteps)
end

wrapper.ship.enable = function(flag, addr)
    -- Executes the last movement command or cancels it, if flag is false.
    if wrapper.demoMode then
        return
    end

    wrapper.ship.getComponent(addr).enable(flag)
end

wrapper.ship.jump = function(rotationSteps, x, y, z, hyper, addr)
    -- Makes the ship jump. If hyper is true, all arguments are ignored.
    if wrapper.demoMode then
        return
    end

    if addr ~= nil then
        wrapper.ship.controllerTimes[addr] = os.time()
    else
        wrapper.ship.controllerTimes[wrapper.ship.getComponent().address] = os.time()
    end

    if hyper then
        wrapper.ship.setCommand("HYPERDRIVE", addr)
        wrapper.ship.enable(true, addr)
    else
        wrapper.ship.setCommand("MANUAL", addr)
        wrapper.ship.setRotationSteps(rotationSteps, addr)
        wrapper.ship.setMovement(x, y, z, addr)
        wrapper.ship.enable(true, addr)
    end
end

wrapper.ship.cancelJump = function(addr)
    -- Cancels the jump (Alias for ship.enable(false))
    if wrapper.demoMode then
        return
    end

    if addr ~= nil then
        wrapper.ship.controllerTimes[addr] = 0
    else
        wrapper.ship.controllerTimes[wrapper.ship.getComponent().address] = 0
    end

    wrapper.ship.enable(false, addr)
end

wrapper.ship.getPosition = function(addr)
    -- Returns X Y Z of the ship
    if wrapper.demoMode then
        return 1337, 228, 1488
    end

    return wrapper.ship.getComponent(addr).position()
end

wrapper.ship.getOrientation = function(addr)
    -- Returns X Z ship rotation
    if wrapper.demoMode then
        return 1, 0
    end

    local x, _, z = wrapper.ship.getComponent(addr).getOrientation()

    return x, z
end

wrapper.ship.getShipName = function(addr)
    -- Gets ship name
    if wrapper.demoMode then
        return "Demo mode ship"
    end

    return wrapper.ship.getComponent(addr).shipName()
end

wrapper.ship.getShipMass = function(addr)
    -- Gets ship mass in blocks
    if wrapper.demoMode then
        return 1500
    end

    return wrapper.ship.getComponent(addr).getShipSize()
end

wrapper.ship.isAssemblyValid = function(addr)
    -- Is ship assembly valid or not
    if wrapper.demoMode then
        return true
    end

    return wrapper.ship.getComponent(addr).isAssemblyValid()
end

wrapper.ship.getShipEnergy = function(addr)
    -- Gets ship energy
    if wrapper.demoMode then
        return 5
    end

    local energy = wrapper.ship.getComponent(addr).energy()

    return energy
end

wrapper.ship.getMaxShipEnergy = function(addr)
    -- Gets max ship energy
    if wrapper.demoMode then
        return 10
    end

    local _, max = wrapper.ship.getComponent(addr).energy()

    return max
end

wrapper.ship.setShipName = function(name, addr)
    -- Sets ship name
    if wrapper.demoMode then
        return
    end

    wrapper.ship.getComponent(addr).shipName(name)
end

wrapper.ship.setDimPositive = function(front, right, up, addr)
    -- Sets positive ship dimensions (Front, Right, Up)
    if wrapper.demoMode then
        return
    end

    return wrapper.ship.getComponent(addr).dim_positive(front, right, up)
end

wrapper.ship.setDimNegative = function(back, left, down, addr)
    -- Sets negative ship dimensions (Back, Left, Down)
    if wrapper.demoMode then
        return
    end

    return wrapper.ship.getComponent(addr).dim_negative(back, left, down)
end

return wrapper
