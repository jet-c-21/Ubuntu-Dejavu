# xscreensaver

## Enable Movie Playing Feature

1. open the xscreensaver and close it
2. edit the `~/.xscreensaver` file
3. copy the following code below and paste it under the last `GL:` line
```bash
  Best: 	      "Movies" 	mpv --really-quiet --no-audio --fs	      \
				  --loop=inf --no-stop-screensaver	      \
				  --shuffle --wid=$XSCREENSAVER_WINDOW	      \
				  ~/my_home/my_data/LiveWallpaper/Infinity-Journey-v2-3840x2160.mp4 \n\
```
