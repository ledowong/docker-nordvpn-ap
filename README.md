## Prepare SD Card
1. Install Raspberry Pi OS Lite (64-bit) using [Raspberry Pi Imager](https://www.raspberrypi.com/software/)

## Setup Raspberry Pi
1. [Disable Bluetooth](https://di-marco.net/blog/it/2020-04-18-tips-disabling_bluetooth_on_raspberry_pi/)
    - Edit `/boot/config.txt`, add `dtoverlay=disable-bt` at the end of the file.
2. [Disable IPv6](https://www.howtoraspberry.com/2020/04/disable-ipv6-on-raspberry-pi/)
    - Edit `/boot/cmdline.txt`, add `ipv6.disable=1` at the end of the line.
3. System update
    - Run `sudo apt update && sudo apt upgrade -y` 
4. [Install Docker Engine using the Apt repository](https://docs.docker.com/engine/install/debian/#install-using-the-repository)
5. [Linux post-installation steps for Docker Engine](https://docs.docker.com/engine/install/linux-postinstall/)
6. Reboot
    - Run `sudo reboot`
7. 
