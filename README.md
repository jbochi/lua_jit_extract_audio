Sample application of how to use lua jit and ffmpeg to extract audio tracks from video files.

Code and idea inspired by [ngx-audio-track-for-hls-module](https://github.com/flavioribeiro/nginx-audio-track-for-hls-module/blob/master/ngx_http_aac_module.c). Lua jit bindings from [ffi_fun](https://github.com/mkottman/ffi_fun/blob/master/ffmpeg_audio.lua)

To recreate ffmpeg.h, run `gcc -E -I $PATH_TO_FFMPEG_SRC tmp.h > ffmpeg.h`

Or on a MacOSX: `gcc -E -I /usr/local/Cellar/ffmpeg/2.3.3/ tmp.h | sed '/^#/ d' | sed 's/\(\^\)/(*)/' > ffmpeg.h`
