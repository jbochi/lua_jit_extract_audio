-- Initializing the FFI library
local M = {}
local ffi = require 'ffi'
local avformat = ffi.load('avformat-55')
local avutil = ffi.load('avutil-52')
local header = assert(io.open('ffmpeg.h')):read('*a')
ffi.cdef(header)

avformat.av_register_all()

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


M.extract_audio = function(read_function, write_function)
  local read_buffer_size = 8192
  local read_exchange_area = ffi.C.malloc(read_buffer_size)

  local io_input_context = avformat.avio_alloc_context(read_exchange_area, read_buffer_size, 0, nil, read_function, nil, nil)

  local pinput_context = ffi.new("AVFormatContext*[1]")
  local input_context = avformat.avformat_alloc_context()
  input_context.pb = io_input_context
  pinput_context[0] = input_context

  av_assert(avformat.avformat_open_input(pinput_context, "dummy", nil, nil))
  av_assert(avformat.av_find_stream_info(input_context))
  local audio_stream_id = av_assert(avformat.av_find_best_stream(input_context, avformat.AVMEDIA_TYPE_AUDIO, -1, -1, nil, 0));

  local input_audio_stream = input_context.streams[audio_stream_id]
  local output_format_context = avformat.avformat_alloc_context()
  local output_audio_stream = avformat.avformat_new_stream(output_format_context, nil)

  local buffer_size = 1024
  local exchange_area = ffi.C.malloc(buffer_size)
  local io_context = avformat.avio_alloc_context(exchange_area, buffer_size, 1, nil, nil, write_function, nil)

  output_format_context.pb = io_context
  output_format_context.oformat = avformat.av_guess_format("adts", nil, nil)

  avformat.avcodec_copy_context(output_audio_stream.codec, input_audio_stream.codec)
  avformat.avformat_write_header(output_format_context, nil)

  local packet = ffi.new("AVPacket")

  while (avformat.av_read_frame(input_context, packet) >= 0) do
    if packet.stream_index == audio_stream_id then
      packet.stream_index = 0
      avformat.av_interleaved_write_frame(output_format_context, packet)
    end
  end

  avformat.av_write_trailer(output_format_context)
  avformat.av_free(io_context)
  avformat.av_free(input_context)
end

return M
