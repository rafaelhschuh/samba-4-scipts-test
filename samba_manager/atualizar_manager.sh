#!/bin/bash

# Script para Atualizar o Samba Manager
# Autor: Rafael Schuh (github.com/rafaelhschuh)
# Data: Abril 2025
# Descrição: Verifica a versão mais recente do Samba Manager no GitHub
#            e atualiza se necessário.

# Diretório dos scripts e locale
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOCALE_DIR="$SCRIPT_DIR/locale"
INSTALL_DIR="$HOME/.samba-scripts" # Diretório onde os scripts estão instalados
LOCAL_VERSION_FILE="$INSTALL_DIR/version.txt"

# URLs (Substituir pelos URLs reais)
VERSION_JSON_URL="https://raw.githubusercontent.com/rafaelhschuh/samba-4-scipts/main/version.json"

# Carregar idioma (passado como variável de ambiente ou padrão para en_US)
LANGUAGE=${LANGUAGE:-en_US}
if [ -f "$LOCALE_DIR/${LANGUAGE}.sh" ]; then
    source "$LOCALE_DIR/${LANGUAGE}.sh"
else
    # Fallback para inglês se o arquivo de idioma não for encontrado
    echo "Warning: Language file $LOCALE_DIR/${LANGUAGE}.sh not found. Falling back to English."
    source "$LOCALE_DIR/en_US.sh"
fi

# Arquivo temporário para capturar saída do dialog
OUTPUT="/tmp/samba_update_manager_output.$$"

# Função para exibir mensagens de erro e sair
erro() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$1" 8 60
    rm -f $OUTPUT
    exit 1
}

# Função para exibir mensagens de sucesso
sucesso_msg() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_SUCCESS" --msgbox "$1" 8 60
}

# Verificar se dialog e jq estão instalados
verificar_dependencias() {
    if ! command -v dialog &> /dev/null; then
        echo "Instalando dialog... / Installing dialog..."
        apt-get update > /dev/null 2>&1 && apt-get install -y dialog > /dev/null 2>&1 || erro "Falha ao instalar dialog / Failed to install dialog"
    fi
    if ! command -v jq &> /dev/null; then
        echo "Instalando jq... / Installing jq..."
        apt-get update > /dev/null 2>&1 && apt-get install -y jq > /dev/null 2>&1 || erro "Falha ao instalar jq / Failed to install jq"
    fi
    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
         echo "Instalando wget... / Installing wget..."
         apt-get update > /dev/null 2>&1 && apt-get install -y wget > /dev/null 2>&1 || erro "Falha ao instalar wget. Instale wget ou curl. / Failed to install wget. Install wget or curl."
    fi
    if ! command -v unzip &> /dev/null; then
        echo "Instalando unzip... / Installing unzip..."
        apt-get update > /dev/null 2>&1 && apt-get install -y unzip > /dev/null 2>&1 || erro "Falha ao instalar unzip / Failed to install unzip"
    fi
}

# Verificar se o script está sendo executado como root (necessário para instalar dependências)
if [ "$(id -u)" != "0" ]; then
    dialog --title "Erro / Error" --msgbox "Este script deve ser executado como root para instalar dependências, se necessário. Use \'sudo $0\'\n\nThis script must be run as root to install dependencies if needed. Use \'sudo $0\'" 8 70
    exit 1
fi

# Verificar dependências
verificar_dependencias

# Iniciar verificação
dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$UPDATE_MANAGER_TITLE" --infobox "$UPDATE_CHECKING" 5 60

# Obter versão local
if [ -f "$LOCAL_VERSION_FILE" ]; then
    LOCAL_VERSION=$(cat "$LOCAL_VERSION_FILE")
else
    LOCAL_VERSION="0.0.0" # Considerar como versão inicial se o arquivo não existir
fi

# Obter versão remota e URL de download
REMOTE_INFO=$(curl -fsSL "$VERSION_JSON_URL" 2>/dev/null || wget -qO- "$VERSION_JSON_URL" 2>/dev/null)

if [ -z "$REMOTE_INFO" ]; then
    erro "$UPDATE_FAILED Não foi possível obter informações da versão remota. Verifique a conexão e o URL: $VERSION_JSON_URL"
fi

REMOTE_VERSION=$(echo "$REMOTE_INFO" | jq -r ".version" 2>/dev/null)
ZIP_URL=$(echo "$REMOTE_INFO" | jq -r ".zip_url" 2>/dev/null)

if [ -z "$REMOTE_VERSION" ] || [ "$REMOTE_VERSION" == "null" ] || [ -z "$ZIP_URL" ] || [ "$ZIP_URL" == "null" ]; then
    erro "$UPDATE_FAILED Formato inválido do arquivo version.json remoto."
fi

# Comparar versões (usando sort -V para comparação semântica)
if printf '%s\n' "$REMOTE_VERSION" "$LOCAL_VERSION" | sort -V -C; then
    # Versão local é igual ou mais recente
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$UPDATE_MANAGER_TITLE" --msgbox "$(printf "$UPDATE_UP_TO_DATE\n$UPDATE_LOCAL_VERSION: %s\n$UPDATE_REMOTE_VERSION: %s" "$LOCAL_VERSION" "$REMOTE_VERSION")" 8 60
    rm -f $OUTPUT
    exit 0
fi

# Nova versão encontrada, confirmar atualização
CONFIRM_MSG=$(printf "$UPDATE_CONFIRM" "$REMOTE_VERSION")
dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$UPDATE_MANAGER_TITLE" --yesno "$CONFIRM_MSG\n\n$UPDATE_LOCAL_VERSION: $LOCAL_VERSION\n$UPDATE_REMOTE_VERSION: $REMOTE_VERSION" 10 70

if [ $? -ne 0 ]; then
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "$MSG_CANCELED" 5 40
    rm -f $OUTPUT
    exit 0
fi

# Prosseguir com a atualização
TEMP_ZIP="/tmp/samba_manager_update.zip"

( 
    echo 0
    echo "XXX"
    echo "$UPDATE_DOWNLOADING"
    echo "XXX"
    # Baixar usando wget ou curl
    if command -v wget > /dev/null; then
        wget -q -O "$TEMP_ZIP" "$ZIP_URL" --progress=bar:force 2>&1 | stdbuf -oL tr '\r' '\n' | grep -o '[0-9]\+%' | sed -u 's/%//g'
    elif command -v curl > /dev/null; then
        # Curl progress é mais complexo de capturar para dialog, usar infobox
        curl -L -o "$TEMP_ZIP" "$ZIP_URL" # Sem progresso no dialog com curl facilmente
        echo 50 # Simular progresso
    fi
    echo 100
    echo "XXX"
    echo "$UPDATE_EXTRACTING"
    echo "XXX"
    sleep 1
    
    # Verificar se o download foi bem-sucedido
    if [ ! -f "$TEMP_ZIP" ] || [ $(stat -c%s "$TEMP_ZIP") -lt 100 ]; then # Verificar se o arquivo existe e tem tamanho razoável
        echo "ERRO_DOWNLOAD" # Sinalizar erro para o final
        exit 1
    fi
    
    # Criar diretório se não existir
    mkdir -p "$INSTALL_DIR"
    
    # Extrair sobreescrevendo
    unzip -o "$TEMP_ZIP" -d "$INSTALL_DIR/" > /tmp/unzip.log 2>&1
    EXTRACT_STATUS=$?
    
    # Limpar zip temporário
    rm -f "$TEMP_ZIP"
    
    if [ $EXTRACT_STATUS -ne 0 ]; then
        echo "ERRO_EXTRACT" # Sinalizar erro para o final
        exit 1
    fi
    
    # Atualizar arquivo de versão local
    echo "$REMOTE_VERSION" > "$LOCAL_VERSION_FILE"
    
    # Tornar scripts executáveis (importante após extrair)
    find "$INSTALL_DIR" -name '*.sh' -exec chmod +x {} \;
    
    echo 100
    
) | dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$UPDATE_MANAGER_TITLE" --gauge "Iniciando..." 10 70 0

# Verificar se houve erro sinalizado
GAUGE_OUTPUT=$(cat $OUTPUT 2>/dev/null)
rm -f $OUTPUT

if [[ "$GAUGE_OUTPUT" == *"ERRO_DOWNLOAD"* ]]; then
    erro "$UPDATE_FAILED Falha ao baixar o arquivo de atualização de $ZIP_URL."
elif [[ "$GAUGE_OUTPUT" == *"ERRO_EXTRACT"* ]]; then
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --textbox /tmp/unzip.log 20 70
    erro "$UPDATE_FAILED Falha ao extrair o arquivo de atualização. Verifique o log."
else
    SUCCESS_MSG=$(printf "$UPDATE_SUCCESS" "$REMOTE_VERSION")
    sucesso_msg "$SUCCESS_MSG"
fi

exit 0
