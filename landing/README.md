# Kamote Rider landing page

A mobile landing page for the game, served from this computer so phones on the same Wi-Fi can open it and download the APK.

## Run it

1. Copy the APK next to the page (it is not committed here; the file lives in `releases/`):
   ```
   cp releases/kamote-rider-v1.1.0.apk landing/
   ```
2. Start the server from the project folder:
   ```
   python -m http.server 8080 --directory landing
   ```
3. Open http://localhost:8080 on this computer, or `http://<this computer's Wi-Fi IP>:8080` on a phone on the same Wi-Fi.

On Windows, find the Wi-Fi IP with `ipconfig`.

If phones can't connect, the Wi-Fi may block devices from reaching each other. Turn on a phone's hotspot and connect the computer to it instead.

## Public page and QR code

The page is also public at https://piolo284.github.io/Kamote-Rider-High-way-Escape/ (the `gh-pages` branch). `kamote_rider_public_qr.png` (poster) and `kamote_rider_public_qr_plain.png` (QR only) in the project folder point to it, so they work on any network.
