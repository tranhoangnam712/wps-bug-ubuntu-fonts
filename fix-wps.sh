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
        echo "${MSG}..." # Prints normally with a newline so apt gets its own space
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
handler "Running apt update" "sudo apt update" "Pls recheck your network connection"
handler "Downloading package" "sudo apt install curl wget git meson ninja-build build-essential fcitx5 fcitx5-unikey fcitx5-frontend-qt5 fcitx5-frontend-gtk3 jq -y" "Pls recheck your network connection"
handler "Downloading freetype2.13.0 source code" "sudo wget -q -O freetype-2.13.0.tar.xz https://sourceforge.net/projects/freetype/files/freetype2/2.13.0/freetype-2.13.0.tar.xz" "Cant access to https://sourceforge.net/projects/freetype/files/freetype2/2.13.0/freetype-2.13.0.tar.xz .Pls recheck your network connection"
sudo tar xf freetype-2.13.0.tar.xz --remove-files >/dev/null 2>&1
handler "Extracting latest verion number..." "sudo curl -Ls https://params.wps.com/api/map/web/newwpsapk?pttoken=newlinuxpackages" "Pls recheck your network connection"
URL_DOWNLOAD=$(sudo curl -Ls https://params.wps.com/api/map/web/newwpsapk?pttoken=newlinuxpackages | jq -r ".staticjs.website.wpsnewpackages.downloads" | base64 -d | jq -r ".linux_deb")
LATEST_VERSION="$(echo ${URL_DOWNLOAD}| grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
echo "Latest Version:${LATEST_VERSION}"
OPTION=0
if dpkg -s "wps-office" >/dev/null 2>&1 ;then
	read -p "WPS already installed, do you want to reinstall(y/n):" REINSTALL
	if [[ "$REINSTALL" == "y" ]]; then
		handler "Deleting WPS" "sudo apt purge wps-office -y >/dev/null 2>&1 && sudo apt autoremove -y >/dev/null 2>&1" "Cant remove wps-office"
		handler "Clearing all WPS cache and user data" "sudo rm -rf ~/.cache/Kingsoft ~/.config/Kingsoft ~/.local/share/Kingsoft /tmp/Kingsoft* /opt/kingsoft/wps-office" "Failed to clear WPS data"
	else
		OPTION=-1
	fi
fi
if [[ "${OPTION}" -eq 0 ]];then
	echo "Finding local wps deb..."
	PATH_DEB=$(find ./ ~/Downloads ~/Desktop -maxdepth 1 -name "wps-office*.deb" 2>/dev/null)
	readarray -t ITEMS <<<"$PATH_DEB"
	NEW=()
	for item in "${ITEMS[@]}"; do
		if [[ "$(dpkg-deb -f "$item" Package 2> /dev/null)" == "wps-office" ]];then
			NEW+=("${item}")
		fi
	done
	NEW_VERSION=()
	count=0
	if [[ "${#NEW[@]}" -ge 1 ]];then
		echo "Found ${#NEW[@]} wps deb file"
		for item in "${NEW[@]}"; do
			((count++))
			CURRENT_VERSION=$(dpkg-deb -f "$item" Version 2> /dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")
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
		handler "Downloading latest WPS from internet" "wget -q -O wps-${LATEST_VERSION}.deb ${URL_DOWNLOAD}" "Pls recheck your network connection"
		DEB_FILE="./wps-${LATEST_VERSION}.deb"
	else
		DEB_FILE="${NEW[--OPTION]}"
	fi
	handler "Installing WPS-${LATEST_VERSION}" "sudo apt install ${DEB_FILE} -y" "Failed to install WPS" "show"
fi
echo "Fixing WPS bug"
cd freetype-2.13.0 >/dev/null 2>&1
handler "Compiling old version freetype" "meson setup build >/dev/null 2>&1 && meson compile -C build >/dev/null 2>&1" "Failed to compile freetype"
handler "Applying freetype to WPS" "sudo cp -a build/libfreetype.so* /opt/kingsoft/wps-office/office6/" "Applying failed"
cd "${CURRENT_PATH}" >/dev/null 2>&1
sudo rm -rf ./freetype-2.13.0 >/dev/null 2>&1
echo "Installing missing fonts"
handler "Install Roboto fonts" "sudo apt install fonts-roboto -y" "Pls recheck your network connection"
handler "Install Open Sans" "sudo apt install fonts-open-sans -y" "Pls recheck your network connection"
handler "Install Dejavu And Liberation2" "sudo apt install fonts-dejavu fonts-liberation2 -y" "Pls recheck your network connection"
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
	handler "Installing fonttools" "sudo apt install fonttools -y" "Pls recheck your network connection"
	handler "Downloading Deepin" "sudo wget -q -O ttf-deepin-opensymbol_2.2_all.deb https://tux.rainside.sk/deepin/apricot/pool/non-free/t/ttf-deepin-opensymbol/ttf-deepin-opensymbol_2.2_all.deb" "Pls recheck your network connection"
	handler "Downloading Carlito(Replacement for Calibri)" "sudo apt install fonts-crosextra-carlito -y" "Pls recheck your network connection"
	handler "Downloading Caladea(Replacement for Cambria)" "sudo apt install fonts-crosextra-caladea -y" "Pls recheck your network connection"
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
	cd /usr/share/fonts/truetype/crosextra/ >/dev/null 2>&1
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

	cd /usr/share/fonts/truetype/crosextra/ >/dev/null 2>&1
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
	handler "Applying fonts" "sudo mv ${CURRENT_PATH}/extracted_fonts/usr/share/fonts/truetype/deepin/*.ttf /usr/share/fonts/truetype/open-source/ && sudo mv /usr/share/fonts/truetype/crosextra/*.ttf /usr/share/fonts/truetype/open-source/" "Apply fonts failed"
	cd "${CURRENT_PATH}" >/dev/null 2>&1
	sudo rm -rf ./extracted_fonts >/dev/null 2>&1
	sudo rm -rf /usr/share/fonts/truetype/crosextra >/dev/null 2>&1
	sudo apt reinstall fonts-crosextra-carlito -y >/dev/null 2>&1
	sudo apt reinstall fonts-crosextra-caladea -y >/dev/null 2>&1
	sudo apt purge fonts-crosextra-carlito -y >/dev/null 2>&1
	sudo apt purge fonts-crosextra-caladea -y >/dev/null 2>&1
	sudo apt autoremove -y >/dev/null 2>&1
fi
handler "Reseting fonts cache" "sudo fc-cache -fvs >/dev/null 2>&1" "Failed to reset cache"

# read -p "Do you want to install fcitx5 and Unikey(y/n):" OPTION
# while [[ ! "${OPTION}" == "y" && ! "${OPTION}" == "n" ]];do
# 	read -p "Invalid option,retry:" OPTION
# done
# if [[ "${OPTION}" == "y" ]];then
#	handler "Installing fcitx5 and Unikey" "im-config -n fcitx5 && echo -e \"\nexport GTK_IM_MODULE=fcitx\nexport QT_IM_MODULE=fcitx\nexport XMODIFIERS=@im=fcitx\" >> ~/.profile" "Applying fcitx5 and Unikey failed"
# fi

read -p "Completed,reboot now? y/n:" REBOOT
if [[ "${REBOOT}" == "y" ]];then
	sudo reboot
fi
