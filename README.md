# rpi-dualbootify

Combine two Raspberry Pi images into a single one that contains both.

```
npm install -g rpi-dualbootify
```

## Usage

First download two Pi images you want to combine.

For an example try downloading [piCore](http://tinycorelinux.net/9.x/armv6/releases/RPi/) and [raspbian](https://www.raspberrypi.org/downloads/raspbian/) (remember to unzip them to get the raw .img files).

Then to combine the two run:

``` sh
rpi-dualbootify piCore-9.0.3.img 2017-09-07-raspbian-stretch-lite.img dual-image.img
```

The combined image will be stored in `dual-image.img`.

You can now flash this to your SD card and it will boot the first image on the dual image.
To boot the other one you can use the `autoboot.txt` feature on most bootloaders.

For more options run

``` sh
rpi-dualbootify --help
```

## License

This project is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
