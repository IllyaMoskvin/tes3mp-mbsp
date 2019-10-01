--[[-------------------------------------------------------------------

Spell List Generator for TES3MP-MBSP v1.0.0 by Illya Moskvin

SOURCE:
    https://github.com/IllyaMoskvin/tes3mp-mbsp

DESCRIPTION:
    This script scans ESP/ESM files listed in `generate.json` and
    extracts spell costs and IDs from those mods into a JSON file,
    `spells/custom.json`. If moved to the right place as described
    in the documentation, this list will be used by TES3MP-MBSP to
    look up spell costs for the purposes of issuing Magicka refunds
    and awarding bonus skill progression.

LICENSE:
    Copyright (c) 2019 Illya Moskvin <https://github.com/IllyaMoskvin>

    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
    BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
    ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

HISTORY:
    2019-09-30 - v1.0.0 - Initial release

]]---------------------------------------------------------------------

local dkjson = require('lib/dkjson')
local config

require('lib/struct')
require('lib/espParser')

-- Check if a file or directory exists in this path
-- https://stackoverflow.com/a/40195356
function exists(file)
   local ok, err, code = os.rename(file, file)
   if not ok then
      if code == 13 then
         -- Permission denied, but it exists
         return true
      end
   end
   return ok, err
end

-- Get contents of file
-- https://stackoverflow.com/a/31857671
local function readfile(path)
    local file = io.open(path, 'rb') -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read '*a' -- *a or *all reads the whole file
    file:close()
    return content
end

-- Load the config file
if not exists('generate.json') then
    print('Cannot find generate.json in current path')
    os.exit(1)
end

local config = dkjson.decode(readfile('generate.json'))

-- Verify that the config file loaded correctly
if config == nil then
    print('Failed to read generate.json')
    os.exit(1)
end

-- Verify that the files exist
for i, file in pairs(config['files']) do
    if not exists(file) then
        print('File not found: ', file)
        os.exit(1)
    end
end

-- Adapted from `parseMiscs` in original `espParser.lua`
-- https://github.com/JakobCh/tes3mp_scripts/blob/4096203/espParser/scripts/espParser.lua#L333
function parseSpells(filename)
    local records = espParser.getRecords(filename, 'SPEL')

    if espParser.files[filename] == nil then
        espParser.files[filename] = {}
    end

    espParser.files[filename].spells = {}

    local dataTypes = {
        NAME = {'s', 'refId'},
        FNAM = {'s', 'name'},
        SPDT = {
            {
                {'i', 'type'},
                {'i', 'cost'},
                {'i', 'flags'}
            }, 'data'
        }
        -- We don't care about ENAM
    }

    for _, record in pairs(records) do
        local refId = struct.unpack( 's', record:getSubRecordsByName('NAME')[1].data )
        espParser.files[filename].spells[refId] = {}

        for _, subrecord in pairs(record.subRecords) do
            espParser.files[filename].spells[refId] = espParser.subrecordParseHelper(espParser.files[filename].spells[refId], dataTypes, subrecord)
        end
    end
end

-- Start building our table for output
local spells = {}

-- Use our modified espParser to load all magic effects
-- https://github.com/JakobCh/tes3mp_scripts/blob/4096203/espParser/scripts/espParser.lua#L398
for i, file in pairs(config['files']) do
    print('Loading ' .. file)

    if not espParser.addEsp(file) then
        print('Failed to load: ' .. file)
        os.exit(1)
    end

    parseSpells(file)

    -- https://github.com/JakobCh/tes3mp_scripts/blob/b703731/espParser/scripts/espParserTest.lua
    for _, spell in pairs(espParser.files[file].spells) do
        -- type: 0 = Spell, see https://en.uesp.net/morrow/tech/mw_esm.txt
        if spell.data.type == 0 then
            spells[spell.refId] = spell.data.cost
        end
    end
end

-- Helper to sort spells alphabetically when outputting to JSON
local spellIds = {}
local spellCount = 0

for spellId, spellCost in pairs(spells) do
    spellIds[spellCount] = spellId
    spellCount = spellCount + 1
end

table.sort(spellIds)

-- Output our spell list to file
local file = io.open('spells/custom.json', 'w+b')

if file then
    local content = dkjson.encode(spells, { indent = true, keyorder = spellIds })
    file:write(content)
    file:close()
end

print('Success! ' .. tostring(spellCount) .. ' spells written to `spells/custom.json`')
