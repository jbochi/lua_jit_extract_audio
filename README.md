Sample application of how to use lua jit and ffmepg to extract audio tracks from video files.

Code and idea inspired by [ngx-audio-track-for-hls-module](https://github.com/flavioribeiro/nginx-audio-track-for-hls-module/blob/master/ngx_http_aac_module.c).

To recreate ffmpeg.h, run `gcc -E -I $PATH_TO_FFMPEG_SRC tmp.h > ffmpeg.h`
