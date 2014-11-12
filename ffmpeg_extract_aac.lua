local ffi = require 'ffi'
local FILENAME = arg[1] or 'video.ts'
local SECTION = print
local output_file_name = 'output.aac'

SECTION "Initializing the FFI library"

local transmux = require("transmux")

SECTION "Opening file"

local input_file = assert(io.open(FILENAME, "r"))

local function read_function(opaque, buf, buf_size)
  local data = input_file:read(buf_size)
  if data == nil then
    return 0
  end
  ffi.copy(buf, data, #data)
  return #data
end

local output_file = io.open(output_file_name, "w")

local write_function = function(opaque, buf, buf_size)
  output_file:write(ffi.string(buf, buf_size))
  return buf_size
end

local seek_function = function(opaque, offset, whence)
  if whence ~= 0 then
    error("unknown whence")
  end
  return output_file:seek("set", tonumber(offset))
end

transmux.extract_audio(read_function, write_function)
-- transmux.remux(read_function, write_function, seek_function)

SECTION(output_file_name .. " created")
