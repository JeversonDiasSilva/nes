#!/bin/bash

############################################
############################################
############################################
#                                          #
#             AUTENTICAÇÂO AQUI            #
#                                          #
############################################
############################################
############################################

###



###




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
mv $dir/Launcher_off.sh /usr/bin
mv $dir/one /usr/bin
mv $dir/tree /usr/bin
mv $dir/two /usr/bin
mv $dir/xdotool /usr/bin
mv $dir/wmctrl /usr/bin
mv $dir/python3.14 /usr/bin
# mv $dir/es_systems.cfg /userdata/system/configs/emulationstation
mv -f /userdata/system/switch/es_systems_switch.cfg /userdata/system/configs/emulationstation
mv -f /userdata/system/switch/launcher_switch /usr/bin/
wget https://github.com/JeversonDiasSilva/nes/raw/refs/heads/main/extras/sudachi -O /usr/bin/sudachi > /dev/null 2>&1
chmod +x /usr/bin/sudachi
mkdir -p /userdata/bios/switch
mv -f /userdata/system/switch/Firmware /userdata/bios/switch/firmware
mv -f /userdata/system/switch/prod.keys /userdata/bios/switch
mv -f /userdata/system/switch/title.keys /userdata/bios/switch

# Instala pacotes Python necessários
python3.14 -m pip install customtkinter requests 


######



# Define o caminho do arquivo alvo
# Caminhos dos arquivos
ARQUIVO_CONFIG="/usr/lib/python3.11/site-packages/configgen/generators/libretro/libretroConfig.py"
ARQUIVO_CUSTOM="/usr/lib/python3.11/site-packages/configgen/generators/libretro/libretroRetroarchCustom.py"

echo "--- Script V5: Bloqueio Total de Notificações ---"

# 1. Permite escrita
mount -o remount,rw /

# 2. Backups (Se não existirem)
[ ! -f "$ARQUIVO_CONFIG.bak" ] && cp "$ARQUIVO_CONFIG" "$ARQUIVO_CONFIG.bak"
[ ! -f "$ARQUIVO_CUSTOM.bak" ] && cp "$ARQUIVO_CUSTOM" "$ARQUIVO_CUSTOM.bak"

# ---------------------------------------------------------
# PARTE A: libretroConfig.py (Lógica do Sistema)
# ---------------------------------------------------------
echo "[Config] Aplicando SaveState forçado e Input Driver..."
sed -i "s/retroarchConfig\['savestate_auto_load'\] = 'false'/retroarchConfig['savestate_auto_load'] = 'true'/g" "$ARQUIVO_CONFIG"
sed -i "s/retroarchConfig\['input_joypad_driver'\] = 'udev'/retroarchConfig['input_joypad_driver'] = '\"x\"'/g" "$ARQUIVO_CONFIG"
sed -i "s/retroarchConfig\['input_driver'\] = 'udev'/retroarchConfig['input_driver'] = '\"x\"'/g" "$ARQUIVO_CONFIG"

# ---------------------------------------------------------
# PARTE B: libretroRetroarchCustom.py (O Arquivo Gerador)
# ---------------------------------------------------------
echo "[Custom] Aplicando Hotkey e removendo Fonte..."
# Hotkey null
sed -i "/'input_enable_hotkey'/ s/\"shift\"/\"null\"/" "$ARQUIVO_CUSTOM"
# Fonte de video false (Texto OSD)
sed -i "/'video_font_enable'/ s/\"true\"/\"false\"/" "$ARQUIVO_CUSTOM"

# ---------------------------------------------------------
# PARTE C: INJEÇÃO DE NOVAS CONFIGURAÇÕES (WIDGETS)
# ---------------------------------------------------------
echo "[Custom] Injetando bloqueio de Widgets..."

# Função para inserir linha se ela não existir
inserir_se_nao_existir() {
    FILE=$1
    SEARCH=$2  # Texto âncora (onde inserir depois)
    CHECK=$3   # Texto para verificar se já existe
    INSERT=$4  # A linha exata a ser inserida

    if grep -q "$CHECK" "$FILE"; then
        echo "  -> Configuração '$CHECK' já existe. Pulando injeção."
        # Se já existe, garante que está como false
        sed -i "/'$CHECK'/ s/\"true\"/\"false\"/" "$FILE"
    else
        echo "  -> Injetando '$CHECK'..."
        # Insere APÓS a linha do texto âncora
        sed -i "/$SEARCH/a \    $INSERT" "$FILE"
    fi
}

# 1. Desligar Widgets (As notificações gráficas/bolhas)
inserir_se_nao_existir "$ARQUIVO_CUSTOM" \
    "'video_font_enable'" \
    "menu_enable_widgets" \
    "retroarchSettings.save('menu_enable_widgets', '\"false\"')"

# 2. Desligar especificamente notificação de SAVE state
inserir_se_nao_existir "$ARQUIVO_CUSTOM" \
    "'video_font_enable'" \
    "notification_show_save_state" \
    "retroarchSettings.save('notification_show_save_state', '\"false\"')"

# 3. Desligar especificamente notificação de LOAD state
inserir_se_nao_existir "$ARQUIVO_CUSTOM" \
    "'video_font_enable'" \
    "notification_show_load_state" \
    "retroarchSettings.save('notification_show_load_state', '\"false\"')"

# 4. Desligar notificação de Config Loaded (mensagem chata de início)
inserir_se_nao_existir "$ARQUIVO_CUSTOM" \
    "'video_font_enable'" \
    "notification_show_config_override_load" \
    "retroarchSettings.save('notification_show_config_override_load', '\"false\"')"

echo "--- Verificação Final ---"
grep "menu_enable_widgets" "$ARQUIVO_CUSTOM"
grep "notification_show_save_state" "$ARQUIVO_CUSTOM"

echo "--- Concluído! Reinicie o jogo. ---"


######






# Curitiba 24 de Novembro de 2025.
# Editor: Jeverson D. Silva   ///@JCGAMESCLASSICOS...

# Criando gatilho para comandos de inicialização com as personalizações do usuário.

cat << 'EOF' > /userdata/system/custom.sh
#!/bin/bash
# Curitiba 24 de Novembro de 2025.
# Editor: Jeverson D Silva   ///@JCGAMESCLASSICOS...

# Comandos a serem carregados juntamente com o sistema.

EOF


chmod +x /userdata/system/custom.sh

# Teclado nunmérico e navegador

######




#!/bin/bash

# Caminho do arquivo xinitrc
XINITRC="/etc/X11/xinit/xinitrc"

# Usando sed com bloco delimitado para inserir o conteúdo corretamente
sed -i '/# ulimit -c unlimited/a \
# Comandos a serem carregados juntamente com o sistema.\n\
if [ ! -d /userdata/system/.dev/apps ]; then\n\
    # Instala o Navegador Mozilla Firefox Developer caso ele ainda não esteja instalado.\n\
    curl -sL bit.ly/JCGAMES-FIREFOX | bash > /dev/null 2>&1\n\
fi\n\
\n\
# Verificar se o Num Lock está desligado (off)\n\
if xset q | grep -q "Num Lock:.*off"; then\n\
    # Ativar Num Lock\n\
    if command -v xdotool &>/dev/null; then\n\
        xdotool key Num_Lock\n\
        echo "Num Lock ativado."\n\
    else\n\
        echo "xdotool não encontrado, não foi possível ativar o Num Lock."\n\
    fi\n\
else\n\
    echo "Num Lock já está ativado."\n\
fi\n' "$XINITRC"






######


# Funções para configurações iniciais
configs_iniciais() {
    # Configurações de idioma e fuso horário
    if grep -q '^#system.language=en_US' /userdata/system/batocera.conf; then
        sed -i 's|#system.language=en_US|system.language=pt_BR|' /userdata/system/batocera.conf
    fi

    if grep -q '#system.timezone=Europe/Paris' /userdata/system/batocera.conf; then
        sed -i 's|#system.timezone=Europe/Paris|system.timezone=America/Sao_Paulo|' /userdata/system/batocera.conf
    fi

    # Baixar wmctrl se não estiver instalado
    if [ ! -f /usr/bin/wmctrl ]; then
        wget https://github.com/JeversonDiasSilva/configs/releases/download/v.1.0/wmctrl -O /usr/bin/wmctrl
        chmod +x /usr/bin/wmctrl
    fi

    # Baixar xdotool se não estiver instalado
    if [ ! -f /usr/bin/xdotool ]; then
        wget https://github.com/JeversonDiasSilva/configs/releases/download/v.1.0/xdotool -O /usr/bin/xdotool
        chmod +x /usr/bin/xdotool
    fi
}

# Chama as configurações iniciais
configs_iniciais
echo "reiniciando"
sleep 5
reboot


cp -f /usr/share/batocera/datainit/system/configs/emulationstation/es_input.cfg /userdata/system/.dev/



######

batocera-save-overlay 150

# Limpeza
rm -rf /userdata/system/.dev/.tmp

# Mata o processo do EmulationStation
killall emulationstation

# Mata outros processos que podem interferir
killall -9 pcmanfm xterm &

# Remove os arquivos temporários

startx
######

