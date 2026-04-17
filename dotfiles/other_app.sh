sudo apt update
sudo apt upgrade
sudo apt install snapd flatpak steam-installer qemu-system-x86 libvirt-daemon-system libvirt-clients bridge-utils virt-manager -y
flatpak install flathub com.google.Chrome
flatpak install flathub com.spotify.Client
snap install discord
curl -fsSL https://tailscale.com/install.sh | sh
sudo add-apt-repository ppa:obsproject/obs-studio
sudo apt update
sudo apt-get update && sudo apt-get install obs-studio
