# Docker NordVPN AP
Create a Raspberry Pi wireless access point that tunnels traffic through NordVPN. The project ships a Docker Compose stack (NordVPN + AP container) and an optional Flask-based restart API that can be triggered from an iPhone Shortcut.

## Prerequisites
- Raspberry Pi with 5GHz-capable Wi-Fi and Raspberry Pi OS Lite (64-bit).
- NordVPN account and API token.
- Another internet-connected device (iPhone) if you want the shortcut trigger.

## Setup Raspberry Pi (including SD card prep)
1. Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) to flash Raspberry Pi OS Lite (64-bit) to an SD card.
2. Boot the Pi, SSH in, and harden the OS:
   - [Disable Bluetooth](https://di-marco.net/blog/it/2020-04-18-tips-disabling_bluetooth_on_raspberry_pi/) by adding `dtoverlay=disable-bt` to `/boot/firmware/config.txt`.
   - [Disable IPv6](https://www.howtoraspberry.com/2020/04/disable-ipv6-on-raspberry-pi/) by appending `ipv6.disable=1` to `/boot/firmware/cmdline.txt`.
3. Update the system:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```
4. [Install Docker Engine via apt](https://docs.docker.com/engine/install/debian/#install-using-the-repository), complete the [post-install steps](https://docs.docker.com/engine/install/linux-postinstall/).
5. Reboot (`sudo reboot`) and SSH back in.

## Checkout project and update the config
1. Clone and enter the repo:
   ```bash
   git clone https://github.com/ledowong/docker-nordvpn-ap.git
   cd docker-nordvpn-ap
   ```
2. Install Python tooling for the helper API:
   ```bash
   sudo apt install -y python3 python3-venv python3-pip
   ```
3. Create the Flask virtualenv and install dependencies:
   ```bash
   python3 -m venv flask-env
   source flask-env/bin/activate
   pip install flask
   deactivate
   ```
4. Edit `docker-compose.yml` and update:
   - `<nord_vpn_token>`, `<country>`, `<ssid>`, `<wifi_password>`, `<wifi_country_code>`
   - Any Wi-Fi parameters (channel, DNS, country code, etc.) you need to customize.
5. Configure the WiFi restart API secret by exporting `X_AUTH_TOKEN=<your_token>` before running `app.py` or by setting it in the service file (default is `password`, but change it for production).
6. Start the stack once you are ready:
   ```bash
   docker compose up -d
   ```

## Setup restart service
1. Copy the unit file:
   ```bash
   sudo cp wifi-restart-api.service /etc/systemd/system/
   ```
2. Edit `/etc/systemd/system/wifi-restart-api.service`:
   - Replace `/home/user/docker-nordvpn-ap` in `WorkingDirectory` and `ExecStart` with your actual clone path.
   - Add `Environment=X_AUTH_TOKEN=<your_token>` under `[Service]` so the Flask app enforces your secret.
3. Reload systemd and enable the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now wifi-restart-api.service
   sudo systemctl status wifi-restart-api.service
   ```
   The status output should show `active (running)`; check `journalctl -u wifi-restart-api.service` if you need logs.

## Setup iPhone shortcut
1. Install the shortcut: https://www.icloud.com/shortcuts/621bbf353f604e1e932d05df81bebaae
2. Open it in the Shortcuts app and edit the HTTP action:
   - Point the URL at your Pi (e.g. `http://<pi_ip>:5000/check?force=1`).
   - Under Headers, change `X-Auth-Token` to match the `X_AUTH_TOKEN` you configured on the Pi.
3. Optional hardening:
   - Disable “Limit IP Address Tracking” on your iPhone when connected to this AP so the shortcut can reach the Pi without a relay.
   - Consider locking the shortcut with Face ID/Touch ID if you treat it as an admin-only action.

## Verify everything works
- Run `docker compose ps` to confirm `nordvpn` and `docker-ap` are healthy.
- Hit `http://<pi_ip>:5000/check` with the correct token; you should get a JSON response describing the status.
- From the iPhone, run the shortcut and confirm it reports success and the AP remains online.
