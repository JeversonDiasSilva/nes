#!/bin/bash


# Cria o diretório .dev e .tmp se não existir
mkdir -p /userdata/system/.dev	
cd /userdata/system/.dev
mkdir -p /userdata/system/.dev/.tmp
	
# URL do arquivo a ser baixado
url="https://github.com/JeversonDiasSilva/nes/releases/download/1.0/NES"
url_switch="https://github.com/JeversonDiasSilva/nes/releases/download/1.0/SWITCH"

# Baixa o arquivo
wget $url
wget $url_switch

# Obtém o nome do arquivo baixado
squash=$(basename $url)
squash_switch=$(basename $url_switch)

# Extrai o conteúdo do arquivo squashfs para o diretório temporário
unsquashfs -d /userdata/system/.dev/.tmp $squash 
rm -f $squash
unsquashfs -d /userdata/system/switch $squash_switch
rm -f $squash_switch

# Dá permissão total para os arquivos extraídos
chmod -R 777 /userdata/system/.dev/.tmp
chmod -R 777 /userdata/system/switch

dir=/userdata/system/.dev/.tmp

# Cria os arquivos de contador
echo "0" > /userdata/system/.dev/.contador.txt
echo "0" > /userdata/system/.dev/contador.txt

# Move os arquivos para os locais adequados
cd /userdata/system/.dev/.tmp
mv $dir/dep/* /usr/bin
mv $dir/efeitos_sonoros /userdata/system/.dev/
mv $dir/emulationstation-standalone /usr/bin
mv $dir/emulatorlauncher /usr/bin
mv $dir/five /usr/bin
mv $dir/for /usr/bin
mv $dir/load /usr/bin
mv $dir/one /usr/bin
mv $dir/tree /usr/bin
mv $dir/two /usr/bin
mv $dir/xdotool /usr/bin
mv $dir/wmctrl /usr/bin
mv $dir/python3.14 /usr/bin
mv $dir/es_systems.cfg /userdata/system/configs/emulationstation
mv -f /userdata/system/switch/es_systems_switch.cfg /userdata/system/configs/emulationstation
wget https://github.com/JeversonDiasSilva/nes/raw/refs/heads/main/extras/sudachi -O /usr/bin/sudachi > /dev/null 2>&1
chmod +x /usr/bin/sudachi

# Instala pacotes Python necessários
python3.14 -m pip install customtkinter requests 

# Salva as mudanças no overlay do sistema
batocera-save-overlay

# Mata o processo do EmulationStation
killall emulationstation

# Mata outros processos que podem interferir
killall -9 pcmanfm xterm &

# Remove os arquivos temporários
rm -rf /userdata/system/.dev/.tmp

one &
two &
tree &
for &
five &
