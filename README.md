# WPS Office Linux Bug & Font Fixer

A pair of automated bash scripts dedicated to fixing the most common bugs, crashes, and missing fonts in WPS Office for Linux. 

Beyond simply installing the software, this tool solves document formatting issues when switching files between Windows Office and Linux WPS. It prevents presentation slides from misaligning and offers two distinct installation paths based on your needs:

* #### Business Mode (Open Source): Avoids copyright issues by forging open-source alternatives to mimic Microsoft fonts (~90% compatibility).
* #### Personal Mode (Proprietary): Directly installs actual Microsoft fonts for 100% pixel-perfect compatibility.

## Supported Distributions:
* `wps-install-apt.sh`: For Ubuntu, Debian, Linux Mint, Pop!_OS
* `wps-install-dnf.sh`: For Fedora, RHEL, CentOS, AlmaLinux

## What This Script Fixes

* Missing Document Fonts: Installs Roboto, Open Sans, and the full suite of Microsoft Core/Windows fonts: Arial, Arial Black, Comic Sans MS, Courier New, Georgia, Impact, Times New Roman, Trebuchet MS, Verdana, Webdings, Wingdings (1, 2, 3), Symbol, MT Extra, Calibri, and Cambria. (Note: Business mode automatically uses open-source forged equivalents for the proprietary fonts).
* Broken PDF Exporting (WPS cant export to PDF)
* Video Playback Freeze (Fixes videos not playing in WPS Presentation)
* Fake Bold Font Rendering Bug
* Outdated Software (Pulls the absolute newest build directly from the API)

## How to Install

Open your terminal and enter these commands:

For Ubuntu/Debian:
```
wget https://raw.githubusercontent.com/tranhoangnam712/wps-bug-ubuntu-fonts/refs/heads/main/wps-install-apt.sh
chmod +x wps-install-apt.sh
./wps-install-apt.sh
```
For Fedora/Red Hat:
```
wget https://raw.githubusercontent.com/tranhoangnam712/wps-bug-ubuntu-fonts/refs/heads/main/wps-install-dnf.sh
chmod +x wps-install-dnf.sh
./wps-install-dnf.sh
```
Note: The script will ask if you want to use a Personal (Microsoft proprietary fonts) or Business (Open-source alternative fonts) setup. Type 1 or 2 when prompted.
# Demo run(Note:video demo are from old version of this script)
![Embedded Video Bug](https://github.com/tranhoangnam712/wps-bug-ubuntu-fonts/blob/main/baocao_files/image001.gif)
# Details explain reports
## 1. Bugs & Fixes

### Bug 1: Embedded Video Playback Failure in PPTX
* **Description:** WPS Presentation on Linux fails to play embedded videos inside PowerPoint slides out of the box.
* **Bug Demonstration:**
  ![Embedded Video Bug](https://github.com/tranhoangnam712/wps-bug-ubuntu-fonts/blob/main/baocao_files/image002.gif)
* **How to Fix:** Adjust hardware acceleration and codecs.
  ![Video Fix Result](https://github.com/tranhoangnam712/wps-bug-ubuntu-fonts/blob/main/baocao_files/image003.gif)

### Bug 2: Font Rendering Bug (Fake Bold Issue)
* **Cause:** WPS Office utilizes the latest `freetype` library, which glitches when rendering fonts that lack a native Bold weight design, failing to generate a proper "fake bold."
* **Bug Demonstration:**
  ![Font Rendering Bug](https://github.com/tranhoangnam712/wps-bug-ubuntu-fonts/blob/main/baocao_files/image004.gif)
* **How to Fix:** Downgrade the `freetype` library to version `2.13.0` and compile it directly into the WPS system path.
  ```bash
  sudo apt install meson ninja-build build-essential -y
  sudo wget -q -O freetype-2.13.0.tar.xz https://sourceforge.net/projects/freetype/files/freetype2/2.13.0/freetype-2.13.0.tar.xz
  sudo tar xf freetype-2.13.0.tar.xz
  cd freetype-2.13.0
  meson setup build && meson compile -C build
  sudo cp -a build/libfreetype.so* /opt/kingsoft/wps-office/office6/
  ```

### Bug 3: Broken PDF & Image Export (Missing libtiff)
* **Cause:** Ubuntu upgrades to `libtiff.so.6`, but WPS Office rigidly searches for the legacy `libtiff.so.5` library to execute export functions.
* **How to Fix:** Create a symbolic link to bridge the version mismatch:
  ```bash
  sudo ln -s /usr/lib/x86_64-linux-gnu/libtiff.so.6 /usr/lib/x86_64-linux-gnu/libtiff.so.5
  ```

---

## 2. Font Solutions: Proprietary vs. Open Source

When switching between Microsoft Office and Linux, formatting often breaks due to missing fonts. This tool provides two distinct installation paths:

| Feature | Personal Mode (Proprietary Microsoft Fonts) | Business Mode (Open Source Forged Fonts) |
| :--- | :--- | :--- |
| **Compatibility** | 100% exact layout, sizing, and styling matching Windows Office. | ~90% compatible; keeps presentations and documents aligned. |
| **Legal Status** | Violates copyright unless the machine holds a valid Windows license. | Fully open-source and safe for corporate/enterprise legal compliance. |
| **Limitations** | None regarding layout. | `Cambria Math` has no open-source equivalent; some math symbols may differ. |

### Shared Open-Source Fonts Installed in Both Modes:
* `Roboto`
* `Open Sans`
* `DejaVu Sans`
* `Liberation2`

### Font Replacement Mapping (Business Mode)
Using `fonttools` (TTX), open-source alternatives are decompiled, metadata-forged, and recompiled so WPS recognizes them as standard Microsoft fonts:

| Required Microsoft Font | Open Source Alternative Used |
| :--- | :--- |
| `Symbol` | `Deepin Open Symbol 6` |
| `Wingdings` | `Deepin Open Symbol` |
| `Wingdings 2` | `Deepin Open Symbol 2` |
| `Wingdings 3` | `Deepin Open Symbol 3` |
| `MT Extra` | `Deepin Open Symbol 5` |
| `Calibri` | `Carlito` |
| `Cambria` | `Caladea` |

---

## 3. Visual Font Comparisons (Office vs. Open Source)

Below is the visual comparison between original Microsoft Office fonts and our forged open-source solutions:

### 1. Symbol
![Symbol Open Source](https://github.com/tranhoangnam712/wps-bug-ubuntu-fonts/blob/main/baocao_files/image005.png)

### 2. Wingdings
![Wingdings Open Source](https://github.com/tranhoangnam712/wps-bug-ubuntu-fonts/blob/main/baocao_files/image006.png)

### 3. Wingdings 2
![Wingdings 2 Open Source](https://github.com/tranhoangnam712/wps-bug-ubuntu-fonts/blob/main/baocao_files/image007.png)

### 4. Wingdings 3
![Wingdings 3 Open Source](https://github.com/tranhoangnam712/wps-bug-ubuntu-fonts/blob/main/baocao_files/image008.png)

### 5. MT Extra
![MT Extra Open Source](https://github.com/tranhoangnam712/wps-bug-ubuntu-fonts/blob/main/baocao_files/image009.png)

### 6. Calibri
![Calibri Open Source](https://github.com/tranhoangnam712/wps-bug-ubuntu-fonts/blob/main/baocao_files/image010.png)

### 7. Cambria
![Cambria Open Source](https://github.com/tranhoangnam712/wps-bug-ubuntu-fonts/blob/main/baocao_files/image011.png)

---

