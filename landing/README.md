# Kamote Rider landing page

A mobile landing page for the game, served from this computer so phones on the same Wi-Fi can open it and download the APK.

## Run it

1. Copy the APK next to the page (it is not committed here; the file lives in `releases/`):
   ```
   cp releases/kamote-rider-v1.0.0.apk landing/
   ```
2. Start the server from the project folder:
   ```
   python -m http.server 8080 --directory landing
   ```
3. Open http://localhost:8080 on this computer, or `http://<this computer's Wi-Fi IP>:8080` on a phone on the same Wi-Fi.

On Windows, find the Wi-Fi IP with `ipconfig`. `kamote_rider_local_qr.png` points to `http://10.5.50.243:8080`; if the IP changes on another network, make a new QR code for the new address.

If phones can't connect, the Wi-Fi may block devices from reaching each other. Turn on a phone's hotspot and connect the computer to it instead.
