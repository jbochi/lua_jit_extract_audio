local M = {}
local ffi = require 'ffi'
local avformat = ffi.load('avformat')
local avutil = ffi.load('avutil')
local header = assert(io.open('ffmpeg.h')):read('*a')
local AV_LOG_FATAL = 8
local callback = "int (*)(void *, uint8_t *, int)"
ffi.cdef(header)

avformat.av_register_all()
avformat.av_log_set_level(AV_LOG_FATAL)

local function av_assert(err)
  if err < 0 then
    local errbuf = ffi.new("uint8_t[256]")
    local ret = avutil.av_strerror(err, errbuf, 256)
    if ret ~= -1 then
      error(ffi.string(errbuf), 2)
    else
      error('Unknown AV error: '..tostring(ret), 2)
    end
  end
  return err
end

local id3_timestamp_representation = function(timestamp)
  local hex_timestamp = string.format("%016x", timestamp)
  local chars = {}
  for i = 1, 16, 2 do
    local byte = tonumber(string.sub(hex_timestamp, i, i + 1), 16)
    chars[#chars + 1] = string.char(byte)
  end
  return table.concat(chars)
end

local id3_header = function(timestamp)
  local OWNER = "com.apple.streaming.transportStreamTimestamp"
  local buffer = {
    -- header
    "ID3",                          -- file identifier
    string.char(0x04, 0),           -- version
    string.char(0),                 -- flags
    string.char(0, 0, 0, 63),       -- size: 63 bytes
    -- frame
    "PRIV",                         -- frame id
    string.char(0, 0, 0, 53),       -- frame size: 53 bytes
    string.char(0, 0),              -- flags
    OWNER,                          -- owner
    string.char(0),                 -- owner terminator
    id3_timestamp_representation(timestamp)
  }
  return table.concat(buffer)
end

local function extract_audio(read_function, write_function)
  local read_buffer_size = 8192
  local read_exchange_area = ffi.C.malloc(read_buffer_size)
  local first_packet = true

  local io_input_context = avformat.avio_alloc_context(read_exchange_area, read_buffer_size, 0, nil, read_function, nil, nil)

  local pinput_context = ffi.new("AVFormatContext*[1]")
  local input_context = avformat.avformat_alloc_context()
  input_context.pb = io_input_context
  pinput_context[0] = input_context

  av_assert(avformat.avformat_open_input(pinput_context, "dummy", nil, nil))
  av_assert(avformat.av_find_stream_info(input_context))
  local audio_stream_id = av_assert(avformat.av_find_best_stream(input_context, avformat.AVMEDIA_TYPE_AUDIO, -1, -1, nil, 0))

  local input_audio_stream = input_context.streams[audio_stream_id]
  local output_format_context = avformat.avformat_alloc_context()
  local output_audio_stream = avformat.avformat_new_stream(output_format_context, nil)

  local buffer_size = 8192
  local exchange_area = ffi.C.malloc(buffer_size)
  local io_context = avformat.avio_alloc_context(exchange_area, buffer_size, 1, nil, nil, write_function, nil)

  output_format_context.pb = io_context
  output_format_context.oformat = avformat.av_guess_format("adts", nil, nil)

  av_assert(avformat.avcodec_copy_context(output_audio_stream.codec, input_audio_stream.codec))
  av_assert(avformat.avformat_write_header(output_format_context, nil))

  local packet = ffi.new("AVPacket")

  while (avformat.av_read_frame(input_context, packet) >= 0) do
    if packet.stream_index == audio_stream_id then
      if first_packet then
        local id3_tag = id3_header(tonumber(packet.pts))
        write_function(nil, ffi.cast("uint8_t *", id3_tag), #id3_tag)
        first_packet = false
      end
      packet.stream_index = 0
      av_assert(avformat.av_interleaved_write_frame(output_format_context, packet))
    end
    avformat.av_free_packet(packet)
  end

  av_assert(avformat.av_write_trailer(output_format_context))
  avformat.av_free(io_context)
  avformat.av_free(io_input_context)
  avformat.av_free(input_context)
  avformat.avformat_free_context(output_format_context)
end
jit.off(extract_audio)
M.extract_audio = extract_audio

M.extract_audio_from_string = function(data)
  local pos = 1

  local read_function = ffi.cast(callback, function(opaque, buf, buf_size)
    local final_pos = math.min(pos + buf_size, #data + 1)
    local delta = final_pos - pos
    if delta == 0 then
      return 0
    end
    ffi.copy(buf, string.sub(data, pos, final_pos - 1), delta)
    pos = final_pos
    return delta
  end)

  local output = {}
  local write_function = ffi.cast(callback, function(opaque, buf, buf_size)
    output[#output + 1] = ffi.string(buf, buf_size)
    return buf_size
  end)

  extract_audio(read_function, write_function)
  read_function:free()
  write_function:free()
  return table.concat(output)
end

return M
