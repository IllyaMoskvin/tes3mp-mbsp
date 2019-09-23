local dkjson = require("lib/dkjson")
local config

require("lib/struct")
require("lib/espParser")

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
    local file = io.open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

-- Load the config file
if not exists("generate.json") then
    print("Cannot find generate.json in current path")
    os.exit(1)
end

local config = dkjson.decode(readfile("generate.json"))

-- Verify that the config file loaded correctly
if config == nil then
    print("Failed to read generate.json")
    os.exit(1)
end

-- Verify that the files exist
for i, file in pairs(config['files']) do
    if not exists(file) then
        print("File not found: ", file)
        os.exit(1)
    end
end
