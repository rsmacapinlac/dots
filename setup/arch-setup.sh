#/bin/bash

mkdir ~/.ssh
cp ./ssh/* ~/.ssh

chmod 600 ~/.ssh/id_rsa

sudo pacman -Sy --noconfirm firefox openssh git pass

gpg --import gpg/public.pgp
gpg --allow-secret-key-import --import gpg/private.pgp

mkdir ~/workspace && cd ~/workspace
git clone git@github.com:rsmacapinlac/workstation-builder.git
git clone git@github.com:rsmacapinlac/cautious-dollop.git ~/.password-store

git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay
makepkg -si --noconfirm

cd ~/workspace/workstation-builder
bin/ansible-init.sh
cd arch

echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/temp-nopasswd

eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa
export SUDO_ASKPASS=~/newcomputer/askpass.sh && ansible-playbook core.yml --ssh-extra-args="-o ForwardAgent=yes" -K

# All of the above, really like Pixel Sakura
sh -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"

# remove no password
sudo rm /etc/sudoers.d/temp-nopasswd
