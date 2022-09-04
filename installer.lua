--By ECS
local component = require("component")
local unicode = require("unicode")
local fs = require("filesystem")
local event = require("event")
local gpu = component.gpu
local internet = component.internet

---------------------------------------------------------------------------------------------------------------------------------

-- Specify required files for downloading
local files = {}
print("Идет загрузка списка файлов..")
fs.makeDirectory("/PonOS/")
require("shell").execute("wget https://raw.githubusercontent.com/IteratorW/Interstellar2/master/filelist.txt /PonOS/filelist.txt -fq")
local file = io.open("/PonOS/filelist.txt", "r")
files = require("serialization").unserialize(file:read("*a"))
file:close()

component.gpu.setBackground(0x000000)
require("term").clear()


local properties = {
    -- Comment any coordinate to calculate it automatically (will centerize window on screen by specified axis)
    -- windowX = 2,
    -- windowY = 2,
    -- Set window width value lower than zero (0.5 for example) to calculate it dependent on screen width
    windowWidth = 54,
    -- Customize offset by X axis from window corners
    GUIElementsOffset = 2,
    -- Customize localization as you want to
    localization = {
        -- Specify title of your installer
        title = "Intestellar 2 Installer",
        -- Use <currentProgress>, <totalProgress> and <currentFile> text insertions to automatically display their values
        currentFile = "Downloading \"<currentFile>\"...",
        totalProgress = "Total: <totalProgress>%",
        -- Comment this lines to automatically close installer window
        finished1 = "Interstellar2 is successfully installed!",
        finished2 = "Please press any key to leave and open Interstellar2."
    },
    -- Customize color scheme as you want to
    colors = {
        window = {
            background = 0xFFFFFF,
            text = 0x000000,
            shadow = 0x3C3C3C
        },
        title = {
            background = 0x0000AA,
            text = 0xFFFFFF,
        },
        progressBar = {
            active = 0x0000AA,
            passive = 0xC0C0C0
        }
    }
}

---------------------------------------------------------------------------------------------------------------------------------

local screenWidth, screenHeight = gpu.getResolution()
properties.windowHeight = 8

if properties.windowWidth < 1 then
    properties.windowWidth = math.floor(screenWidth * properties.windowWidth)
end
progressBarWidth = properties.windowWidth - properties.GUIElementsOffset * 2

if not properties.windowX then
    properties.windowX = math.floor(screenWidth / 2 - properties.windowWidth / 2)
end

if not properties.windowY then
    properties.windowY = math.floor(screenHeight / 2 - properties.windowHeight / 2)
end

local currentBackground, currentForeground

---------------------------------------------------------------------------------------------------------------------------------

local function setBackground(color)
    if currentBackground ~= color then
        gpu.setBackground(color)
        currentBackground = color
    end
end

local function setForeground(color)
    if currentForeground ~= color then
        gpu.setForeground(color)
        currentForeground = color
    end
end

local function rectangle(x, y, width, height, color)
    setBackground(color)
    gpu.fill(x, y, width, height, " ")
end

local function centerizedText(y, color, text)
    local textLength = unicode.len(text)
    if textLength > progressBarWidth then
        text = unicode.sub(text, 1, progressBarWidth)
        textLength = progressBarWidth
    end

    setForeground(color)
    gpu.set(properties.windowX + properties.GUIElementsOffset, y, string.rep(" ", progressBarWidth))
    gpu.set(math.floor(properties.windowX + properties.GUIElementsOffset + progressBarWidth / 2 - textLength / 2), y, text)
end

local function progressBar(y, percent, text, totalProgress, currentProgress, currentFile)
    setForeground(properties.colors.progressBar.passive)
    gpu.set(properties.windowX + properties.GUIElementsOffset, y, string.rep("━", progressBarWidth))
    setForeground(properties.colors.progressBar.active)
    gpu.set(properties.windowX + properties.GUIElementsOffset, y, string.rep("━", math.ceil(progressBarWidth * percent)))

    text = text:gsub("<totalProgress>", totalProgress)
    text = text:gsub("<currentProgress>", currentProgress)
    text = text:gsub("<currentFile>", currentFile)

    centerizedText(y + 1, properties.colors.window.text, text)
end

local function download(url, path, totalProgress)
    fs.makeDirectory(fs.path(path))

    local file, fileReason = io.open(path, "w")
    if file then
        local pcallSuccess, requestHandle = pcall(internet.request, url)
        if pcallSuccess then
            if requestHandle then
                -- Drawing progressbar once with zero percentage
                local y = properties.windowY + 2
                progressBar(y, 0, properties.localization.currentFile, totalProgress, "0", path)

                -- Waiting for any response code
                local responseCode, responseName, responseData
                repeat
                    responseCode, responseName, responseData = requestHandle:response()
                until responseCode

                -- Downloading file by chunks
                local contentLength = 12 * 1024 * 1024
                local currentLength = 0

                if responseData and responseData["Content-Length"] then
                    contentLength = tonumber(responseData["Content-Length"][1])
                end

                while true do
                    local data, reason = requestHandle.read(math.huge)
                    if data then
                        currentLength = currentLength + #data
                        local percent = currentLength / contentLength
                        progressBar(y, percent, properties.localization.currentFile, totalProgress, tostring(math.ceil(percent)), path)

                        file:write(data)
                    else
                        requestHandle:close()
                        if reason then
                            error(reason)
                        else
                            file:close()
                            return
                        end
                    end
                end
            else
                error("Invalid URL-address: " .. tostring(url))
            end
        else
            error("Usage: component.internet.request(string url)")
        end

        file:close()
    else
        error("Failed to open file for writing: " .. tostring(fileReason))
    end
end

---------------------------------------------------------------------------------------------------------------------------------

-- Copying current screen data
local oldPixels = {}
for y = properties.windowY, properties.windowY + properties.windowHeight do
    oldPixels[y] = {}
    for x = properties.windowX, properties.windowX + properties.windowWidth do
        oldPixels[y][x] = { gpu.get(x, y) }
    end
end

local function shadowPixel(x, y, symbol)
    setBackground(oldPixels[y][x][3])
    gpu.set(x, y, symbol)
end

-- Vertical shadow
rectangle(properties.windowX + properties.windowWidth, properties.windowY + 1, 1, properties.windowHeight - 1, properties.colors.window.shadow)
setForeground(properties.colors.window.shadow)
shadowPixel(properties.windowX + properties.windowWidth, properties.windowY, "▄")

-- Horizontal shadow
for i = properties.windowX + 1, properties.windowX + properties.windowWidth do
    shadowPixel(i, properties.windowY + properties.windowHeight, "▀")
end

-- Window background
rectangle(properties.windowX, properties.windowY + 1, properties.windowWidth, properties.windowHeight - 1, properties.colors.window.background)

-- Title
rectangle(properties.windowX, properties.windowY, properties.windowWidth, 1, properties.colors.title.background)
centerizedText(properties.windowY, properties.colors.title.text, properties.localization.title)
setBackground(properties.colors.window.background)

-- Downloading
local y = properties.windowY + 5
progressBar(y, 0, properties.localization.totalProgress, "0", "0", files[1].path)
for i = 1, #files do
    local percent = i / #files
    local totalProgress = tostring(math.ceil(percent * 100))
    download(files[i].url, files[i].path, totalProgress)
    progressBar(y, percent, properties.localization.totalProgress, totalProgress, "0", files[i].path)
end

-- On exit
if properties.localization.finished1 then
    rectangle(properties.windowX, properties.windowY + 1, properties.windowWidth, properties.windowHeight - 1, properties.colors.window.background)
    centerizedText(properties.windowY + 3, properties.colors.window.text, properties.localization.finished1)
    centerizedText(properties.windowY + 4, properties.colors.window.text, properties.localization.finished2)

    while true do
        local eventType = event.pull()
        if eventType == "key_down" or eventType == "touch" then
            break
        end
    end
end
