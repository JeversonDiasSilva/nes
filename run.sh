#!/bin/bash

# URL do arquivo a ser baixado
url="https://github.com/JeversonDiasSilva/nes/releases/download/1.0/NES"

# Baixa o arquivo
wget $url

# Obtém o nome do arquivo baixado
squash=$(basename $url)

# Extrai o conteúdo do arquivo squashfs para o diretório temporário
unsquashfs $squash -d /userdata/system/.dev/.tmp

# Dá permissão total para os arquivos extraídos
chmod -R 777 /userdata/system/.dev/.tmp

# Cria o diretório .dev se não existir
mkdir -p /userdata/system/.dev

# Cria os arquivos de contador
echo "0" > /userdata/system/.dev/.contador.txt
echo "0" > /userdata/system/.dev/contador.txt

# Move os arquivos para os locais adequados
cd /userdata/system/.dev/.tmp
mv dep/* /usr/bin
mv efeitos_sonoros /userdata/system/.dev/
mv emulationstation-standalone /usr/bin
mv emulatorlauncher /usr/bin
mv five /usr/bin
mv for /usr/bin
mv load /usr/bin
mv one /usr/bin
mv tree /usr/bin
mv two /usr/bin
mv /userdata/system/.dev/.tmp/es_systems.cfg /userdata/system/configs/emulationstation

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
