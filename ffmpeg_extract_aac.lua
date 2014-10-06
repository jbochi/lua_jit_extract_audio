-- How to decode an audio file with Lua, using LuaJIT FFI and ffmpeg...
-- Michal Kottman, 2011

local FILENAME = arg[1] or 'video.ts'
local SECTION = print

SECTION "Initializing the FFI library"

local ffi = require 'ffi'
local C = ffi.C

--[[
To recreate ffmpeg.h, create a file tmp.h with the following content
(or more, or less, depending on what you want):

#include "config.h"
#include "libavutil/avstring.h"
#include "libavutil/pixdesc.h"
#include "libavformat/avformat.h"
#include "libavdevinputContexte/avdevinputContexte.h"
#include "libswscale/swscale.h"
#include "libavcodec/audioconvert.h"
#include "libavcodec/colorspace.h"
#include "libavcodec/opt.h"
#include "libavcodec/avfft.h"
#include "libavfilter/avfilter.h"
#include "libavfilter/avfiltergraph.h"
#include "libavfilter/graphparser.h"

Then run gcc -E -I $PATH_TO_FFMPEG_SRC tmp.h > ffmpeg.h
]]

local avcodec = ffi.load('avcodec-55')
local avformat = ffi.load('avformat-55')
local avutil = ffi.load('avutil-52')
local header = assert(io.open('ffmpeg.h')):read('*a')
ffi.cdef(header)

local function avAssert(err)
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

SECTION "Initializing the avcodec and avformat libraries"

-- avcodec.avcodec_init()
avcodec.avcodec_register_all()
avformat.av_register_all()

SECTION "Opening file"

local pinputContext = ffi.new("AVFormatContext*[1]")
avAssert(avformat.avformat_open_input(pinputContext, FILENAME, nil, nil))
local inputContext = pinputContext[0]

avAssert(avformat.av_find_stream_info(inputContext))

SECTION "Finding audio stream"

local audioCtx
local nStreams = tonumber(inputContext.nb_streams)

print("n streams: " .. nStreams)

local audio_stream_id = avAssert(avformat.av_find_best_stream(inputContext, avformat.AVMEDIA_TYPE_AUDIO, -1, -1, nil, 0));

print("stream aac: " .. audio_stream_id)

local input_audio_stream = inputContext.streams[audio_stream_id]
local output_format_context = avformat.avformat_alloc_context()
local output_audio_stream = avformat.avformat_new_stream(output_format_context, nil)


local file = io.open("output.aac", "w")

local write_packet = function(opaque, buf, buf_size)
	file:write(ffi.string(buf, buf_size))
	return buf_size
end

local buffer_size = 1024
local exchange_area = ffi.new("unsigned char[" .. buffer_size .. "]")
local io_context = avformat.avio_alloc_context(exchange_area, buffer_size, 1, nil, nil, write_packet, nil)

output_format_context.pb = io_context
output_format_context.oformat = avformat.av_guess_format("adts", nil, nil)

avformat.avcodec_copy_context(output_audio_stream.codec, input_audio_stream.codec)
avformat.avformat_write_header(output_format_context, nil)

SECTION "header written"

local packet = ffi.new("AVPacket")
packet.data = nil
packet.size = 0

while (avformat.av_read_frame(inputContext, packet) >= 0) do
	if packet.stream_index == audio_stream_id then
		local new_packet = ffi.new("AVPacket")
		new_packet.stream_index = 0;
		new_packet.pts = packet.pts;
		new_packet.dts = packet.dts;
		new_packet.data = packet.data;
		new_packet.size = packet.size;
		avformat.av_interleaved_write_frame(output_format_context, new_packet)
	end
end

avformat.av_write_trailer(output_format_context)
avformat.av_free(io_context)

SECTION "output.aac created"
