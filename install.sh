#!/bin/bash
root="$(cd $(dirname $BASH_SOURCE) && pwd)"
cd "$root"

user=${SUDO_USER:-$(whoami)}
home=$(eval echo ~$user)

check(){
    if (($EUID==0));then
        echo "Don't run as root"
        exit 1
    fi
}
usage(){
    cat<<-EOF
	Usage: $(basename $0) CMD
	CMD:
		install
		uninstall
	EOF
    exit 1
}

install(){
    check
    cp config.json.example config.json
    editor=vi
    if command -v vim >/dev/null 2>&1;then
        editor=vim
    fi
    case $(uname) in
        Linux)
            cmds=$(cat<<-EOF
			sed -e "s|ROOT|$root|g" Linux/sslocal.service >/etc/systemd/system/sslocal.service
			ln -sf "$root/sslocal" /usr/local/bin
			$editor config.json
			systemctl daemon-reload
			systemctl start sslocal.service
			systemctl enable sslocal.service
			EOF
            )
            sudo -- sh -c "$cmds"
            ;;
        Darwin)
            sed -e "s|ROOT|$root|g" Darwin/sslocal.plist "$home/Library/LaunchAgents/sslocal.plist"
            ln -sf "$root/sslocal" /usr/local/bin
            $editor config.json
            launchctl load -w $home/Library/LaunchAgents/sslocal.plist

            export ALL_PROXY=socks5://localhost:1080
            if ! command -v brew >/dev/null 2>&1;then
                echo "Install homebrew..."
                /usr/bin/ruby -e "$(curl --max-time 60 -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
            fi
            if ! command -v brew >/dev/null 2>&1;then
                echo "Install homebrew failed."
                exit 1
            fi
            if ! brew list coreutils >/dev/null 2>&1;then
                echo "install coreutils"
                brew install coreutils
            fi
            ;;
    esac
}

uninstall(){
    check
    case $(uname) in
        Linux)
            cmds=$(cat<<-EOF
			systemctl stop sslocal
			systemctl disable sslocal
			rm /etc/systemd/system/sslocal.service
			rm /usr/local/bin/sslocal
			EOF
            )
            sudo -- sh -c "$cmds"
            ;;
        Darwin)
            launchctl unload $home/Library/LaunchAgents/sslocal.plist
            rm $home/Library/LaunchAgents/sslocal.plist
            rm /usr/local/bin/sslocal
            ;;
    esac

}

cmd=$1
case $cmd in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    *)
        usage
        ;;
esac
