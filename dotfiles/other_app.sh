sudo apt update
sudo apt upgrade
sudo apt install flatpak steam-installer qemu-system-x86 libvirt-daemon-system libvirt-clients bridge-utils virt-manager -y
curl -fsSL https://tailscale.com/install.sh | sh
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.google.Chrome
