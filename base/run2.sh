#!/bin/bash

# Caminho para o arquivo de configuração do Batocera
CONF="/userdata/system/batocera.conf"

# Obtenha o caminho absoluto do arquivo de jogo
CAMINHO_GAME=$(readlink -f "$1")
SISTEMA=$(dirname "$CAMINHO_GAME")

# Nome do jogo (extraímos o nome do arquivo do jogo)
JOGO=$(basename "$1")

# Função para obter o core específico do batocera.conf para um jogo
get_core_from_config() {
    # Procurar por uma entrada específica para o jogo no batocera.conf
    local core=$(grep "$JOGO" "$CONF" | grep 'core=' | cut -d'=' -f2)
    echo "$core"
}

# Exibe o caminho absoluto do jogo e o caminho do sistema para depuração
echo "Caminho absoluto do jogo: $CAMINHO_GAME"
echo "Caminho do sistema: $SISTEMA"
echo "Jogo: $JOGO"

# Recupera o core do batocera.conf
core=$(get_core_from_config)

# Verifica se foi encontrado um core
if [ -z "$core" ]; then
    echo "Core não encontrado no batocera.conf. Usando o core padrão."
    # Defina um core padrão se não encontrado no batocera.conf
    if [[ "$SISTEMA" == "/userdata/roms/atomiswave"* ]]; then
        core="flycast"
    elif [[ "$SISTEMA" == "/userdata/roms/fba_libretro"* ]]; then
        core="fbalpha2012"
    elif [[ "$SISTEMA" == "/userdata/roms/fbneo"* ]]; then
        core="fbneo"
    elif [[ "$SISTEMA" == "/userdata/roms/mame"* ]]; then
        core="mame"
    elif [[ "$SISTEMA" == "/userdata/roms/naomi"* ]]; then
        core="flycast"
    fi
else
    echo "Core encontrado no batocera.conf: $core"
fi

# Adiciona o sufixo "_libretro.so" ao core
core_path="/usr/lib/libretro/${core}_libretro.so"

# Exibe o core que será usado
echo "Core a ser usado: $core_path"

# Se o core foi encontrado, execute o RetroArch com o core
if [ -n "$core" ]; then
    echo "Abrindo o jogo com o core $core_path..."
    retroarch -L "$core_path" "$1"
else
    echo "O jogo não está em nenhum diretório de sistema suportado, nada será feito."
fi