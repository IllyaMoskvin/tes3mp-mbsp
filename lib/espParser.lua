--[[
    espParser 0.5
    By Jakob https://github.com/JakobCh
    Mostly using: https://en.uesp.net/morrow/tech/mw_esm.txt

    Updates will probably break your shit right now in the early stages.

    Almost all record/subrecord data isn't parsed.

    Things that are currently parsed:
        Cells - espParser.files["Morrowind.esm"].cells

    Installation:
        1. Put this file and struct.lua ( https://github.com/iryont/lua-struct ) in /server/scripts/custom/
        2. Add "require("custom.espParser")" to /server/scripts/customScripts.lua
        3. Create a folder called "esps" in /server/data/custom/
        4. Place your esp/esm files in the new folder (/server/data/custom/esps/)
        5. Change the "files" table a couple lines down to match your files
        (6. Check the espParserTest.lua file for examples)

    ~~~~~~~~

    Jakob has given permission for this script to be used by and bundled with TES3MP-MBSP.
    https://github.com/IllyaMoskvin/tes3mp-mbsp

    It has been modified by Illya Moskvin to work outside TES3MP.
    It has been further modified to only extract "SPEL" records.
    No modifications were made to the description above.
    For usage rights, contact Jakob.
]]

-- Add this to whatever requires espParser
-- require("lib.struct") -- Requires https://github.com/iryont/lua-struct

--Global
espParser = {}

--print(debug.getinfo(2, "S").source:sub(2))

--Stream class
espParser.Stream = {}
espParser.Stream.__index = espParser.Stream
function espParser.Stream:create(data)
    local newobj = {}
    setmetatable(newobj, espParser.Stream)
    newobj.data = data
    newobj.pointer = 1
    return newobj
end
function espParser.Stream:len()
    return string.len(self.data)
end
function espParser.Stream:read(amount)
    local temp = string.sub(self.data, self.pointer, self.pointer+amount-1)
    self.pointer = self.pointer + amount
    return temp
end
function espParser.Stream:sub(start, send)
    local temp = string.sub(self.data, start, send)
    return temp
end

--Record class
espParser.Record = {}
espParser.Record.__index = espParser.Record
function espParser.Record:create(stream)
    local newobj = {}
    setmetatable(newobj, espParser.Record)
    newobj.name = stream:read(4)

    newobj.size = struct.unpack( "i", stream:read(4) )
    newobj.header1 = struct.unpack( "i", stream:read(4) )
    newobj.flags = struct.unpack( "i", stream:read(4) )
    newobj.data = stream:read(newobj.size)
    newobj.subRecords = {}

    --get subrecords
    local st = espParser.Stream:create(newobj.data)
    while st.pointer < st:len() do
        table.insert(newobj.subRecords, espParser.SubRecord:create(st) )
    end

    -- We only care about saving spells in this case!
    if tostring(newobj.name) ~= "SPEL" then
        return nil
    end

    return newobj
end
function espParser.Record:getSubRecordsByName(name)
    local out = {}
    for _, subrecord in pairs(self.subRecords) do
        if tostring(subrecord.name) == name then
            table.insert(out, subrecord)
        end
    end
    return out
end

--SubRecord class
espParser.SubRecord = {}
espParser.SubRecord.__index = espParser.SubRecord
function espParser.SubRecord:create(stream)
    local newobj = {}
    setmetatable(newobj, espParser.SubRecord)
    newobj.name = stream:read(4)
    newobj.size = struct.unpack( "i", stream:read(4) )
    newobj.data = stream:read(newobj.size)
    --print("Creating subrecord with name: " .. tostring(newobj.name))
    return newobj
end

--helper functions
espParser.getRecords = function(filename, recordName)
    local out = {}
    for i,record in pairs(espParser.rawFiles[filename]) do
        if tostring(record.name) == recordName then
            table.insert(out, record)
        end
    end
    return out
end

espParser.getSubRecords = function(filename, recordName, subRecordName)
    local out = {}
    for _,record in pairs(espParser.rawFiles[filename]) do
        if tostring(record.name) == recordName then
            for _, subrecord in pairs(record.subRecords) do
                if tostring(subrecord.name) == subRecordName then
                    table.insert(out, subrecord)
                end
            end
        end
    end
    return out
end

espParser.getAllRecords = function(recordName)
    local out = {}
    for filename,records in pairs(espParser.files) do
        for _,record in pairs(records) do
            if record.name == recordName then
                table.insert(out, record)
            end
        end
    end
    return out
end

espParser.getAllSubRecords = function(recordName, subRecordName)
    local out = {}
    for filename,records in pairs(espParser.files) do
        for _,record in pairs(records) do
            if record.name == recordName then
                for _, subrecord in pairs(record.subRecords) do
                    if subrecord.name == subRecordName then
                        table.insert(out, subrecord)
                    end
                end
            end
        end
    end
    return out
end


espParser.rawFiles = {} --contains each .esp file as a key (raw Records and subrecords)
espParser.files = {} --contains each .esp file as a key (parsed)
--TODO have a merged one that carry over changes depending on the loadorder

espParser.subrecordParseHelper = function(obj, dataTypes, subrecord)
    if dataTypes[subrecord.name] ~= nil then
        if type(dataTypes[subrecord.name][1]) == "table" then
            local stream = espParser.Stream:create( subrecord.data )
            for _, ty in pairs(dataTypes[subrecord.name][1]) do
                if dataTypes[subrecord.name][2] == nil then --assign directly to the object
                    obj[ ty[2] ] = struct.unpack( ty[1], stream:read(4) )
                else --put the values in a table
                    if obj[ dataTypes[subrecord.name][2] ] == nil then
                        obj[ dataTypes[subrecord.name][2] ] = {}
                    end
                    obj[ dataTypes[subrecord.name][2] ][ ty[2] ] = struct.unpack( ty[1], stream:read(4) )
                end
            end
        else
            obj[ dataTypes[subrecord.name][2] ] = struct.unpack( dataTypes[subrecord.name][1], subrecord.data )
        end
    end
    return obj
end

espParser.addEsp = function(filename)
    local currentFile = filename

    -- it's up to the user to ensure their paths match their operating system
    local f = io.open(currentFile, "rb")

    if f == nil then return false end --could not open the file

    local mainStream = espParser.Stream:create(f:read("*a")) --read all
    espParser.rawFiles[currentFile] = {}
    while mainStream.pointer < mainStream:len() do
        local r = espParser.Record:create(mainStream)

        if r ~= nil then
            table.insert(espParser.rawFiles[currentFile], r)
        end
    end

    return true
end
