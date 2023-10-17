## Prepare SD Card
1. Install Raspberry Pi OS Lite (64-bit) using [Raspberry Pi Imager](https://www.raspberrypi.com/software/)

## Setup Raspberry Pi
1. SSH into rasp pi.
2. [Disable Bluetooth](https://di-marco.net/blog/it/2020-04-18-tips-disabling_bluetooth_on_raspberry_pi/)
    - Edit `/boot/config.txt`, add `dtoverlay=disable-bt` at the end of the file.
3. [Disable IPv6](https://www.howtoraspberry.com/2020/04/disable-ipv6-on-raspberry-pi/)
    - Edit `/boot/cmdline.txt`, add `ipv6.disable=1` at the end of the line.
4. System update
    - Run `sudo apt update && sudo apt upgrade -y` 
5. [Install Docker Engine using the Apt repository](https://docs.docker.com/engine/install/debian/#install-using-the-repository)
6. [Linux post-installation steps for Docker Engine](https://docs.docker.com/engine/install/linux-postinstall/)
7. [Configure Docker to start on boot with systemd](https://docs.docker.com/engine/install/linux-postinstall/#configure-docker-to-start-on-boot-with-systemd)
    - Run `sudo systemctl enable docker.service && sudo systemctl enable containerd.service`
8. Reboot
    - Run `sudo reboot`
9. SSH into rasp pi.
10. Clone this project
    - Run `git clone https://github.com/ledowong/docker-nordvpn-ap.git`
11. Go into the project folder
    - Run `cd docker-nordvpn-ap`
12. Edit `docker-compose.yml`
    - Replace `<nord_von_token>`, `<country>`, `<ssid>`, `<wifi_password>`, `<wifi_country_code>`
13. Start
    - Run `docker compose up -d`
