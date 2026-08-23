#!/bin/bash
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
RESET='\e[0m'

fake_metadata(){
	local name="$1"
	shift
	echo -n "Forging ${name}..."
	while [[ "$#" -gt 0 ]]; do
		sudo sed -i "$1" "${name}.ttx" >/dev/null 2>&1
		shift
	done
	sudo ttx -o "${name}.ttf" "${name}.ttx" >/dev/null 2>&1
	echo -e " | ${GREEN}Success${RESET}"
}

handler(){
    local RETRY_ATTEMP=3
    local MSG="$1"
    local CMD="$2"
    local ERR_MSG="$3"
    local SHOW_OUTPUT="$4"
    local EXEC_CMD="$CMD"
    if [[ -z "${SHOW_OUTPUT}" ]]; then
        EXEC_CMD="$CMD >/dev/null 2>&1"
        echo -n "${MSG}..."
    else
        echo "${MSG}..."
    fi
    while ! eval "$EXEC_CMD"; do
        ((RETRY_ATTEMP--))
        echo -e "\n--- $CMD | ${RED}Failed${RESET}\nRetrying..."
        if [[ "$RETRY_ATTEMP" -lt 1 ]];then
            echo -e "${RED}${ERR_MSG}, exit in 3 seconds${RESET}"
            sleep 3
            exit 1
        fi
        sleep 3
    done
    echo -e " | ${GREEN}Success${RESET}"
    return 0
}

sudo killall -9 wps >/dev/null 2>&1
sudo killall -9 wpp >/dev/null 2>&1
sudo killall -9 et >/dev/null 2>&1
sudo killall -9 wpspdf >/dev/null 2>&1
CURRENT_PATH=$(pwd)

handler "Updating repository metadata" "sudo dnf makecache" "Pls recheck your network connection"
# Notice dpkg was added here so the deb extraction below still works

handler "Downloading packages" "sudo dnf install curl wget git meson ninja-build gcc gcc-c++ make fcitx5 fcitx5-unikey fcitx5-qt fcitx5-gtk jq dpkg cabextract fontconfig xorg-x11-font-utils -y" "Pls recheck your network connection"
sudo rpm -i --nodigest --nosignature https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
handler "Downloading freetype2.13.0 source code" "sudo wget -q -O freetype-2.13.0.tar.xz https://sourceforge.net/projects/freetype/files/freetype2/2.13.0/freetype-2.13.0.tar.xz" "Cant access to sourceforge. Pls recheck your network connection"

sudo tar xf freetype-2.13.0.tar.xz >/dev/null 2>&1 && sudo rm -f ./freetype-2.13.0.tar.xz

handler "Extracting latest version number..." "sudo curl -Ls https://params.wps.com/api/map/web/newwpsapk?pttoken=newlinuxpackages" "Pls recheck your network connection"
# Changed .linux_deb to .linux_rpm
URL_DOWNLOAD=$(sudo curl -Ls https://params.wps.com/api/map/web/newwpsapk?pttoken=newlinuxpackages | jq -r ".staticjs.website.wpsnewpackages.downloads" | base64 -d | jq -r ".linux_rpm")
LATEST_VERSION="$(echo ${URL_DOWNLOAD}| grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
echo "Latest Version:${LATEST_VERSION}"

OPTION=0
# Changed dpkg check to rpm check
if rpm -q wps-office >/dev/null 2>&1 ;then
	read -p "WPS already installed, do you want to reinstall(y/n):" REINSTALL
	if [[ "$REINSTALL" == "y" ]]; then
		handler "Deleting WPS" "sudo dnf remove wps-office -y >/dev/null 2>&1 && sudo dnf autoremove -y >/dev/null 2>&1" "Cant remove wps-office"
		handler "Clearing all WPS cache and user data" "sudo rm -rf ~/.cache/Kingsoft ~/.config/Kingsoft ~/.local/share/Kingsoft /tmp/Kingsoft* /opt/kingsoft/wps-office" "Failed to clear WPS data"
	else
		OPTION=-1
	fi
fi

if [[ "${OPTION}" -eq 0 ]];then
	echo "Finding local wps rpm..."
	PATH_RPM=$(find ~/ -name "*.rpm" 2>/dev/null)
	readarray -t ITEMS <<<"$PATH_RPM"
	NEW=()
	for item in "${ITEMS[@]}"; do
        # Changed dpkg-deb query to rpm query
		if [[ "$(rpm -qp --nodigest --nosignature --queryformat '%{NAME}' "$item" 2> /dev/null)" == "wps-office" ]];then
			NEW+=("${item}")
		fi
	done

	NEW_VERSION=()
	count=0
	if [[ "${#NEW[@]}" -ge 1 ]];then
		echo "Found ${#NEW[@]} wps rpm file"
		for item in "${NEW[@]}"; do
			((count++))
            # Changed dpkg-deb version extraction to rpm version extraction
			CURRENT_VERSION=$(rpm -qp --nodigest --nosignature --queryformat '%{VERSION}' "$item" 2> /dev/null)
			NEW_VERSION+=("${CURRENT_VERSION}")
			echo "${count}===${CURRENT_VERSION} ${item}"
		done
		((count++))
		
		if [[ "${#NEW[@]}" -eq 1 && "${CURRENT_VERSION[0]}" == "$LATEST_VERSION" ]];then
			OPTION=1
		else
			echo "${count}===Download lastest version from internet"
			read -p "Do you want to install by one of those local or install with latest version in internet(1-${count}):" OPTION
		fi
	else
		OPTION=1
		count=1
	fi

	while [[ "${OPTION}" -lt 1 || "${OPTION}" -gt "${count}" ]];do
		read -p "Invalid option,pls retry:" OPTION
	done

	if [[ "${OPTION}" -eq "${count}" ]];then
		handler "Downloading latest WPS from internet" "wget -q -O wps-${LATEST_VERSION}.rpm ${URL_DOWNLOAD}" "Pls recheck your network connection"
		RPM_FILE="./wps-${LATEST_VERSION}.rpm"
	else
		RPM_FILE="${NEW[--OPTION]}"
	fi
    
    # Install RPM using dnf
	handler "Installing WPS-${LATEST_VERSION}" "sudo rpm -i --nodigest --nosignature ${RPM_FILE}" "Failed to install WPS" "show"
fi

echo "Fixing WPS bug"
cd freetype-2.13.0 >/dev/null 2>&1
handler "Compiling old version freetype" "meson setup build >/dev/null 2>&1 && meson compile -C build >/dev/null 2>&1" "Failed to compile freetype"
handler "Applying freetype to WPS" "sudo cp -a build/libfreetype.so* /opt/kingsoft/wps-office/office6/" "Applying failed"
if [ -L /usr/lib64/libtiff.so.5 ]; then
	sudo rm /usr/lib64/libtiff.so.5
fi
# Changed Debian lib path /usr/lib/x86_64-linux-gnu/ to standard RPM /usr/lib64/
handler "Fix export to pdf" "sudo ln -s /usr/lib64/libtiff.so.6 /usr/lib64/libtiff.so.5" "Applying failed"

if ! grep -q "EnableGraphicsCardAcceleration" ~/.config/Kingsoft/Office.conf; then
	echo "wpp\Application%20Settings\EnableGraphicsCardAcceleration=1" >> ~/.config/Kingsoft/Office.conf
else
	sed -i "s/EnableGraphicsCardAcceleration=./EnableGraphicsCardAcceleration=1/g" ~/.config/Kingsoft/Office.conf
fi
handler "Fix cant play video" "wpp & sleep 3 ; killall -9 wpp ; sleep 1 ; sed -i 's/EnableGraphicsCardAcceleration=./EnableGraphicsCardAcceleration=0/g' ~/.config/Kingsoft/Office.conf" "Fix failed"

cd "${CURRENT_PATH}" >/dev/null 2>&1
sudo rm -rf ./freetype-2.13.0 >/dev/null 2>&1
sudo killall -9 wps >/dev/null 2>&1
sudo killall -9 wpp >/dev/null 2>&1
sudo killall -9 et >/dev/null 2>&1
sudo killall -9 wpspdf >/dev/null 2>&1
echo "Installing missing fonts"
# Updated font package names to Fedora/RPM standards
handler "Install Roboto fonts" "sudo dnf install google-roboto-fonts -y" "Pls recheck your network connection"
handler "Install Open Sans" "sudo dnf install open-sans-fonts -y" "Pls recheck your network connection"
handler "Install Dejavu And Liberation2" "sudo dnf install dejavu-sans-fonts liberation-sans-fonts -y" "Pls recheck your network connection"

echo -e "Personal:will applying fonts from microsoft and it violate copyright"
echo -e "Bussiness:will applying open source fonts.But cambria math fonts wont work"
read -p "Personal use(1) or Bussiness use(2):" OPTION

while [[ "$OPTION" != 1 && "$OPTION" != 2 ]];do
	read -p "Invalid option,retry:" OPTION
done

sudo rm -rf /usr/share/fonts/truetype/microsoft >/dev/null 2>&1
sudo rm -rf /usr/share/fonts/truetype/open-source >/dev/null 2>&1

if [[ "$OPTION" -eq 1 ]]; then
	sudo rm -rf ./wps-fonts >/dev/null 2>&1
	sudo rm -rf ./Windows-10-Fonts-Default >/dev/null 2>&1
	handler "Downloading microsoft fonts" "sudo git clone https://github.com/udoyen/wps-fonts.git >/dev/null 2>&1 && sudo git clone https://github.com/taveevut/Windows-10-Fonts-Default.git >/dev/null 2>&1" "Pls recheck your network connection"
	sudo rm -f ./wps-fonts/wps/WEBDINGS.TTF >/dev/null 2>&1
	sudo mv ./wps-fonts/wps/WINGDNG3.ttf ./wps-fonts/wps/wingding3.ttf >/dev/null 2>&1
	sudo mv ./wps-fonts/wps/WINGDNG2.ttf ./wps-fonts/wps/wingding2.ttf >/dev/null 2>&1
	
	handler "Creating folder" "sudo mkdir -p /usr/share/fonts/truetype/microsoft" "Failed to create folder"
	handler "Applying fonts" "sudo mv ./wps-fonts/wps/* /usr/share/fonts/truetype/microsoft/ && sudo mv ./Windows-10-Fonts-Default/calibri.ttf /usr/share/fonts/truetype/microsoft/ && sudo mv ./Windows-10-Fonts-Default/calibrib.ttf /usr/share/fonts/truetype/microsoft/ && sudo mv ./Windows-10-Fonts-Default/calibrii.ttf /usr/share/fonts/truetype/microsoft/ && sudo mv ./Windows-10-Fonts-Default/calibriz.ttf /usr/share/fonts/truetype/microsoft/ && sudo mv ./Windows-10-Fonts-Default/calibril.ttf /usr/share/fonts/truetype/microsoft/ && sudo mv ./Windows-10-Fonts-Default/calibrili.ttf /usr/share/fonts/truetype/microsoft/ && sudo mv ./Windows-10-Fonts-Default/cambria.ttc /usr/share/fonts/truetype/microsoft/ && sudo mv ./Windows-10-Fonts-Default/cambriab.ttf /usr/share/fonts/truetype/microsoft/ && sudo mv ./Windows-10-Fonts-Default/cambriai.ttf /usr/share/fonts/truetype/microsoft/ && sudo mv ./Windows-10-Fonts-Default/cambriaz.ttf /usr/share/fonts/truetype/microsoft/" "Fonts apply failed"
	
	sudo rm -rf ./wps-fonts >/dev/null 2>&1
	sudo rm -rf ./Windows-10-Fonts-Default >/dev/null 2>&1
else
	handler "Creating folder" "sudo mkdir -p /usr/share/fonts/truetype/open-source" "Failed to create folder"
	handler "Installing fonttools" "sudo dnf install fonttools -y" "Pls recheck your network connection"
	
    handler "Downloading Deepin" "sudo wget -q -O ttf-deepin-opensymbol_2.2_all.deb https://tux.rainside.sk/deepin/apricot/pool/non-free/t/ttf-deepin-opensymbol/ttf-deepin-opensymbol_2.2_all.deb" "Pls recheck your network connection"
	
    # Changed Ubuntu fonts to RPM font packages
    handler "Downloading Carlito(Replacement for Calibri)" "sudo dnf install google-carlito-fonts -y" "Pls recheck your network connection"
	handler "Downloading Caladea(Replacement for Cambria)" "sudo dnf install google-crosextra-caladea-fonts -y" "Pls recheck your network connection"
	
    # This works natively because we added 'dpkg' to the dnf install list at the top!
	sudo dpkg-deb -x ttf-deepin-opensymbol_2.2_all.deb extracted_fonts >/dev/null 2>&1
	sudo rm -f ./ttf-deepin-opensymbol_2.2_all.deb >/dev/null 2>&1
	
	cd extracted_fonts/usr/share/fonts/truetype/deepin/ >/dev/null 2>&1
	echo "Decompiling to XML..."
	sudo ttx -o "wingding.ttx" DeepinOpenSymbol.ttf > /dev/null 2>&1
	sudo ttx -o "wingding2.ttx" DeepinOpenSymbol2.ttf > /dev/null 2>&1
	sudo ttx -o "wingding3.ttx" DeepinOpenSymbol3.ttf > /dev/null 2>&1
	sudo ttx -o "mtextra.ttx" DeepinOpenSymbol5.ttf > /dev/null 2>&1
	sudo ttx -o "symbol.ttx" DeepinOpenSymbol6.ttf > /dev/null 2>&1
	sudo rm -rf ./*.ttf >/dev/null 2>&1
	
    # RPM standard paths for fonts vary, so we dynamically find and copy them instead of guessing the folder
    mkdir -p "${CURRENT_PATH}/temp_carlito_caladea"
    sudo find /usr/share/fonts -type f -name "Carlito*.ttf" -exec cp {} "${CURRENT_PATH}/temp_carlito_caladea/" \;
    sudo find /usr/share/fonts -type f -name "Caladea*.ttf" -exec cp {} "${CURRENT_PATH}/temp_carlito_caladea/" \;
	cd "${CURRENT_PATH}/temp_carlito_caladea/" >/dev/null 2>&1

	sudo ttx -o "calibri.ttx" Carlito-Regular.ttf > /dev/null 2>&1
	sudo ttx -o "calibrib.ttx" Carlito-Bold.ttf > /dev/null 2>&1
	sudo ttx -o "calibrii.ttx" Carlito-Italic.ttf > /dev/null 2>&1
	sudo ttx -o "calibriz.ttx" Carlito-BoldItalic.ttf > /dev/null 2>&1
	sudo ttx -o "cambria.ttx" Caladea-Regular.ttf > /dev/null 2>&1
	sudo ttx -o "cambriab.ttx" Caladea-Bold.ttf > /dev/null 2>&1
	sudo ttx -o "cambriai.ttx" Caladea-Italic.ttf > /dev/null 2>&1
	sudo ttx -o "cambriaz.ttx" Caladea-BoldItalic.ttf > /dev/null 2>&1
	sudo rm -rf ./*.ttf >/dev/null 2>&1
	
	echo "Forging metadata to trick WPS"
	cd "${CURRENT_PATH}/extracted_fonts/usr/share/fonts/truetype/deepin/" >/dev/null 2>&1
	rules=("s/Deepin OpenSymbol Regular/Wingdings/g" "s/DeepinOpenSymbolRegular/Wingdings/g")
	fake_metadata "wingding" "${rules[@]}"
	rules=("s/Deepin OpenSymbol 2/Wingdings 2/g" "s/DeepinOpenSymbol2Regular/Wingdings2/g")
	fake_metadata "wingding2" "${rules[@]}"
	rules=("s/Deepin OpenSymbol 3/Wingdings 3/g" "s/DeepinOpenSymbol3Regular/Wingdings3/g")
	fake_metadata "wingding3" "${rules[@]}"
	rules=("s/Deepin OpenSymbol 5 Regular/MT Extra/g" "s/DeepinOpenSymbolRegular5/MTExtra/g")
	fake_metadata "mtextra" "${rules[@]}"
	rules=("s/Deepin OpenSymbol 6 Regular/Symbol/g" "s/DeepinOpenSymbolRegular6/Symbol/g")
	fake_metadata "symbol" "${rules[@]}"

	cd "${CURRENT_PATH}/temp_carlito_caladea/" >/dev/null 2>&1
	rules=("s/Carlito Regular/Calibri/g" "s/Carlito-Regular/Calibri/g" "s/Carlito/Calibri/g")
	fake_metadata "calibri" "${rules[@]}"
	rules=("s/Carlito Bold/Calibri Bold/g" "s/Carlito-Bold/Calibri-Bold/g" "s/Carlito/Calibri/g")
	fake_metadata "calibrib" "${rules[@]}"
	rules=("s/Carlito Italic/Calibri Italic/g" "s/Carlito-Italic/Calibri-Italic/g" "s/Carlito/Calibri/g")
	fake_metadata "calibrii" "${rules[@]}"
	rules=("s/Carlito Bold Italic/Calibri Bold Italic/g" "s/Carlito-BoldItalic/Calibri-BoldItalic/g" "s/Carlito/Calibri/g")
	fake_metadata "calibriz" "${rules[@]}"
	rules=("s/Caladea Regular/Cambria/g" "s/Caladea-Regular/Cambria/g" "s/Caladea/Cambria/g")
	fake_metadata "cambria" "${rules[@]}"
	rules=("s/Caladea Bold/Cambria Bold/g" "s/Caladea-Bold/Cambria-Bold/g" "s/Caladea/Cambria/g")
	fake_metadata "cambriab" "${rules[@]}"
	rules=("s/Caladea Italic/Cambria Italic/g" "s/Caladea-Italic/Cambria-Italic/g" "s/Caladea/Cambria/g")
	fake_metadata "cambriai" "${rules[@]}"
	rules=("s/Caladea Bold Italic/Cambria Bold Italic/g" "s/Caladea-BoldItalic/Cambria-BoldItalic/g" "s/Caladea/Cambria/g")
	fake_metadata "cambriaz" "${rules[@]}"
	
	handler "Applying fonts" "sudo mv ${CURRENT_PATH}/extracted_fonts/usr/share/fonts/truetype/deepin/*.ttf /usr/share/fonts/truetype/open-source/ && sudo mv ${CURRENT_PATH}/temp_carlito_caladea/*.ttf /usr/share/fonts/truetype/open-source/" "Apply fonts failed"
	
	cd "${CURRENT_PATH}" >/dev/null 2>&1
	sudo rm -rf ./extracted_fonts >/dev/null 2>&1
	sudo rm -rf ./temp_carlito_caladea >/dev/null 2>&1
	
    # Clean up and re-sync using dnf
# Clean up and re-sync using dnf
    sudo dnf reinstall google-carlito-fonts -y >/dev/null 2>&1
    sudo dnf reinstall google-crosextra-caladea-fonts -y >/dev/null 2>&1
    sudo dnf remove google-carlito-fonts -y >/dev/null 2>&1
    sudo dnf remove google-crosextra-caladea-fonts -y >/dev/null 2>&1
	sudo dnf autoremove -y >/dev/null 2>&1
fi

handler "Reseting fonts cache" "sudo fc-cache -fvs >/dev/null 2>&1" "Failed to reset cache"
read -p "Completed,reboot now? y/n:" REBOOT
if [[ "${REBOOT}" == "y" ]];then
	sudo reboot
fi
