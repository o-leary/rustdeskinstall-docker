#!/bin/bash

# Get user options
while getopts i:-: option; do
    case "${option}" in
        -)
            case "${OPTARG}" in
                help)
                    help="true";;
                resolveip)
                    resolveip="true";;
                resolvedns)
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    resolvedns=${val};;
                install-http)
                    http="true";;
                skip-http)
                    http="false";;
            esac;;
        i) resolveip="true";;
    esac
done

function displayhelp() {
    if [[ ! -z $help ]]; then
        echo 'usage: install.sh --resolveip --resolvedns "fqdn"'
        echo "options:"
        echo "--resolveip    Use IP for server name.  Cannot use in combination with --resolvedns or -d"
        echo '--resolvedns "fqdn"    Use FQDN for server name.  Cannot use in combination with --resolveip or -i'
        echo "--install-http    Install http server to host installation scripts.  Cannot use in combination with --skip-http or -n"
        echo "--skip-http    Skip installation of http server.  Cannot use in combination with --install-http or -h"
        exit 0
    fi
}
displayhelp
# Get Username
uname=$(whoami)
gname=$(id -gn ${uname})
admintoken=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c16)

ARCH=$(uname -m)

# identify OS
if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID

    UPSTREAM_ID=${ID_LIKE,,}

    # Fallback to ID_LIKE if ID was not 'ubuntu' or 'debian'
    if [ "${UPSTREAM_ID}" != "debian" ] && [ "${UPSTREAM_ID}" != "ubuntu" ]; then
        UPSTREAM_ID="$(echo ${ID_LIKE,,} | sed s/\"//g | cut -d' ' -f1)"
    fi
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi


# output debugging info if $DEBUG set
if [ "$DEBUG" = "true" ]; then
    echo "OS: $OS"
    echo "VER: $VER"
    echo "UPSTREAM_ID: $UPSTREAM_ID"
    exit 0
fi

# Choice for DNS or IP
if [[ -z "$resolveip" && -z "$resolvedns" ]]; then
    PS3='Choose your preferred connection method: auto-resolve current WAN IP or enter your DNS/Domain:'
    WAN=("IP" "DNS/Domain")
    select WANOPT in "${WAN[@]}"; do
    case $WANOPT in
    "IP")
    wanip=$(dig @resolver4.opendns.com myip.opendns.com +short)
    break
    ;;

    "DNS/Domain")
    echo -ne "Enter your preferred domain/dns address ${NC}: "
    read wanip
    #check wanip is valid domain
    if ! [[ $wanip =~ ^[a-zA-Z0-9]+([a-zA-Z0-9.-]*[a-zA-Z0-9]+)?$ ]]; then
        echo -e "${RED}Invalid domain/dns address${NC}"
        exit 1
    fi
    break
    ;;
    *) echo "invalid option $REPLY";;
    esac
    done
elif [[ ! -z "$resolveip" && ! -z "$resolvedns" ]]; then
    echo -e "\nERROR: You cannot use both --resolveip & --resolvedns options simultaneously"
    exit 1
elif [[ ! -z "$resolveip" && -z "$resolvedns" ]]; then
    wanip=$(dig @resolver4.opendns.com myip.opendns.com +short)
elif [[ -z "$resolveip" && ! -z "$resolvedns" ]]; then
    wanip="$resolvedns"
    if ! [[ $wanip =~ ^[a-zA-Z0-9]+([a-zA-Z0-9.-]*[a-zA-Z0-9]+)?$ ]]; then
        echo -e "${RED}Invalid domain/dns address${NC}"
        exit 1
    fi
fi

# Make Folder /opt/rustdesk/
if [ ! -d "/opt/rustdesk" ]; then
    echo "Creating /opt/rustdesk"
    sudo mkdir -p /opt/rustdesk/
fi
sudo chown "${uname}" -R /opt/rustdesk
cd /opt/rustdesk/ || exit 1


#Download latest version of Rustdesk
RDLATEST=$(curl https://api.github.com/repos/rustdesk/rustdesk-server/releases/latest -s | grep "tag_name" | awk -F'"' '{print $4}')

echo "Installing Rustdesk Server"
if [ "${ARCH}" = "x86_64" ] ; then
wget "https://github.com/rustdesk/rustdesk-server/releases/download/${RDLATEST}/rustdesk-server-linux-amd64.zip"
unzip rustdesk-server-linux-amd64.zip
mv amd64/* /opt/rustdesk/
elif [ "${ARCH}" = "armv7l" ] ; then
wget "https://github.com/rustdesk/rustdesk-server/releases/download/${RDLATEST}/rustdesk-server-linux-armv7.zip"
unzip rustdesk-server-linux-armv7.zip
mv armv7/* /opt/rustdesk/
elif [ "${ARCH}" = "aarch64" ] ; then
wget "https://github.com/rustdesk/rustdesk-server/releases/download/${RDLATEST}/rustdesk-server-linux-arm64v8.zip"
unzip rustdesk-server-linux-arm64v8.zip
mv arm64v8/* /opt/rustdesk/
fi

chmod +x /opt/rustdesk/hbbs
chmod +x /opt/rustdesk/hbbr


# Make Folder /var/log/rustdesk/
if [ ! -d "/var/log/rustdesk" ]; then
    echo "Creating /var/log/rustdesk"
    sudo mkdir -p /var/log/rustdesk/
fi
sudo chown "${uname}" -R /var/log/rustdesk/

./hbbs &
./hbbr &

echo "wait 10 seconds for relay start"
sleep 10

pubname=$(find /opt/rustdesk -name "*.pub")
key=$(cat "${pubname}")

echo "Tidying up install"
if [ "${ARCH}" = "x86_64" ] ; then
rm rustdesk-server-linux-amd64.zip
rm -rf amd64
elif [ "${ARCH}" = "armv7l" ] ; then
rm rustdesk-server-linux-armv7.zip
rm -rf armv7
elif [ "${ARCH}" = "aarch64" ] ; then
rm rustdesk-server-linux-arm64v8.zip
rm -rf arm64v8
fi

echo "Grabbing installers"
string="{\"host\":\"${wanip}\",\"relay\":\"${wanip}\",\"key\":\"${key}\",\"api\":\"https://${wanip}\"}"
string64=$(echo -n "$string" | base64 -w 0 | tr -d '=')
string64rev=$(echo -n "$string64" | rev)

echo "$string64rev"

# We start these in entrypoint.sh
killall hbbr
killall hbbs

function setuphttp () {
    # Create windows install script
    wget https://raw.githubusercontent.com/o-leary/rustdeskinstall-docker/master/WindowsAgentAIOInstall.ps1
    sudo sed -i "s|secure-string|${string64rev}|g" WindowsAgentAIOInstall.ps1

    # Create linux install script
    wget https://raw.githubusercontent.com/o-leary/rustdeskinstall-docker/master/linuxclientinstall.sh
    sudo sed -i "s|secure-string|${string64rev}|g" linuxclientinstall.sh

    # Download and install gohttpserver
    # Make Folder /opt/gohttp/
    if [ ! -d "/opt/gohttp" ]; then
        echo "Creating /opt/gohttp"
        sudo mkdir -p /opt/gohttp/
        sudo mkdir -p /opt/gohttp/public
    fi
    sudo chown "${uname}" -R /opt/gohttp
    cd /opt/gohttp
    GOHTTPLATEST=$(curl https://api.github.com/repos/codeskyblue/gohttpserver/releases/latest -s | grep "tag_name"| awk '{print substr($2, 2, length($2)-3) }')

    echo "Installing Go HTTP Server"
    if [ "${ARCH}" = "x86_64" ] ; then
    wget "https://github.com/codeskyblue/gohttpserver/releases/download/${GOHTTPLATEST}/gohttpserver_${GOHTTPLATEST}_linux_amd64.tar.gz"
    tar -xf  gohttpserver_${GOHTTPLATEST}_linux_amd64.tar.gz 
    elif [ "${ARCH}" =  "aarch64" ] ; then
    wget "https://github.com/codeskyblue/gohttpserver/releases/download/${GOHTTPLATEST}/gohttpserver_${GOHTTPLATEST}_linux_arm64.tar.gz"
    tar -xf  gohttpserver_${GOHTTPLATEST}_linux_arm64.tar.gz
    elif [ "${ARCH}" = "armv7l" ] ; then
    echo "Go HTTP Server not supported on 32bit ARM devices"
    echo -e "Your IP/DNS Address is ${wanip}"
    echo -e "Your public key is ${key}"
    exit 1
    fi

    # Copy Rustdesk install scripts to folder
    mv /opt/rustdesk/WindowsAgentAIOInstall.ps1 /opt/gohttp/public/
    mv /opt/rustdesk/linuxclientinstall.sh /opt/gohttp/public/

    # Make gohttp log folders
    if [ ! -d "/var/log/gohttp" ]; then
        echo "Creating /var/log/gohttp"
        sudo mkdir -p /var/log/gohttp/
    fi
    sudo chown "${uname}" -R /var/log/gohttp/

    echo "Tidying up Go HTTP Server Install"
    if [ "${ARCH}" = "x86_64" ] ; then
    rm gohttpserver_"${GOHTTPLATEST}"_linux_amd64.tar.gz
    elif [ "${ARCH}" = "armv7l" ] || [ "${ARCH}" =  "aarch64" ]; then
    rm gohttpserver_"${GOHTTPLATEST}"_linux_arm64.tar.gz
    fi

    echo -e "Your IP/DNS Address is ${wanip}"
    echo -e "Your public key is ${key}"
    echo -e "Install Rustdesk on your machines and change your public key and IP/DNS name to the above"
    echo -e "You can access your install scripts for clients by going to http://${wanip}:8000"
    echo -e "Username is admin and password is ${admintoken}"
    if [[ -z "$http" ]]; then
        echo "Press any key to finish install"
        while [ true ] ; do
        read -t 3 -n 1
        if [ $? = 0 ] ; then
        exit ;
        else
        echo "waiting for the keypress"
        fi
        done
        break
    fi
}

# Choice for Extras installed
if [[ -z "$http" ]]; then
    PS3='Please choose if you want to download configs and install HTTP server:'
    EXTRA=("Yes" "No")
    select EXTRAOPT in "${EXTRA[@]}"; do
    case $EXTRAOPT in
    "Yes")
    setuphttp
    break
    ;;
    "No")
    echo -e "Your IP/DNS Address is ${wanip}"
    echo -e "Your public key is ${key}"
    echo -e "Install Rustdesk on your machines and change your public key and IP/DNS name to the above"

    echo - e "You can get a free API with Addressbook etc via https://github.com/infiniteremote/installer"

    echo "Press any key to finish install"
    while [ true ] ; do
    read -t 3 -n 1
    if [ $? = 0 ] ; then
    exit ;
    else
    echo "waiting for the keypress"
    fi
    done
    break
    ;;
    *) echo "invalid option $REPLY";;
    esac
    done
elif [ "$http" = "true" ]; then
    setuphttp
elif [ "$http" = "false" ]; then
    echo -e "Your IP/DNS Address is ${wanip}"
    echo -e "Your public key is ${key}"
    echo -e "Install Rustdesk on your machines and change your public key and IP/DNS name to the above"

    echo - e "You can get a free API with Addressbook etc via https://github.com/infiniteremote/installer"
fi
