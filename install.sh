#!/bin/bash

# Script Instalador Automatizado para o Samba Manager 
# Autor: Rafael Schuh (github.com/rafaelhschuh) 
# Data: Maio 2025

# --- Configuração --- #
DOWNLOAD_URL="https://github.com/rafaelhschuh/samba-4-scipts-test/raw/refs/heads/main/samba_manager.zip"
INSTALL_BASE_DIR="/opt/samba-manager-app"
INSTALL_SCRIPT_DIR="$INSTALL_BASE_DIR/samba_manager"
INSTALL_LOG_DIR="$INSTALL_BASE_DIR/logs"
TMP_ZIP_FILE="/tmp/samba-manager.zip"
LAUNCHER_NAME="samba-manager"
LAUNCHER_PATH="/usr/local/bin/$LAUNCHER_NAME"
ZIP_ROOT_DIR="samba_manager"
# --- Fim da Configuração --- #

# Cores para mensagens
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[1;33m'
NC='\e[0m'

erro() {
    echo -e "${RED}[ERRO] $1${NC}"
    rm -f "$TMP_ZIP_FILE"
    exit 1
}

aviso() {
    echo -e "${YELLOW}[AVISO] $1${NC}"
}

sucesso() {
    echo -e "${GREEN}[SUCESSO] $1${NC}"
}

info() {
    echo -e "[INFO] $1"
}

info "Iniciando instalação automatizada do Samba Manager..."

if [ "$(id -u)" != "0" ]; then
    erro "Este script precisa ser executado como root. Use 'sudo bash -c \"\$(wget...)\"' ou 'sudo bash -c \"\$(curl...)\"'"
fi

info "Verificando dependências (wget/curl, unzip)..."
DOWNLOAD_CMD=""
if command -v wget > /dev/null; then
    DOWNLOAD_CMD="wget -q -O"
elif command -v curl > /dev/null; then
    DOWNLOAD_CMD="curl -fsSL -o"
else
    info "'wget' ou 'curl' não encontrado. Tentando instalar 'wget'..."
    apt-get update > /dev/null 2>&1 || aviso "Falha ao atualizar pacotes."
    apt-get install -y wget > /dev/null 2>&1 || erro "Falha ao instalar 'wget'. Instale manualmente e tente novamente."
    DOWNLOAD_CMD="wget -q -O"
fi

if ! command -v unzip > /dev/null; then
    info "'unzip' não encontrado. Tentando instalar..."
    apt-get update > /dev/null 2>&1 || aviso "Falha ao atualizar pacotes."
    apt-get install -y unzip > /dev/null 2>&1 || erro "Falha ao instalar 'unzip'. Instale manualmente e tente novamente."
fi
sucesso "Dependências verificadas."

info "Baixando de $DOWNLOAD_URL..."
rm -f "$TMP_ZIP_FILE"
if ! $DOWNLOAD_CMD "$TMP_ZIP_FILE" "$DOWNLOAD_URL"; then
    erro "Falha ao baixar de $DOWNLOAD_URL"
fi
[ -s "$TMP_ZIP_FILE" ] || erro "Arquivo baixado está vazio."

sucesso "Download concluído."

[ -d "$INSTALL_BASE_DIR" ] && {
    info "Removendo instalação anterior..."
    rm -rf "$INSTALL_BASE_DIR" || erro "Não foi possível remover $INSTALL_BASE_DIR"
    sucesso "Instalação anterior removida."
}

info "Criando diretório $INSTALL_BASE_DIR..."
mkdir -p "$INSTALL_BASE_DIR" || erro "Erro ao criar $INSTALL_BASE_DIR"

info "Extraindo $TMP_ZIP_FILE..."
unzip -o "$TMP_ZIP_FILE" "$ZIP_ROOT_DIR/*" -d "$INSTALL_BASE_DIR/" > /dev/null 2>&1 || {
    info "Tentando extração alternativa..."
    unzip -o "$TMP_ZIP_FILE" -d "$INSTALL_BASE_DIR/" > /dev/null 2>&1 || {
        rm -f "$TMP_ZIP_FILE"
        rm -rf "$INSTALL_BASE_DIR"
        erro "Falha ao extrair $TMP_ZIP_FILE"
    }
}

if [ -d "$INSTALL_BASE_DIR/$ZIP_ROOT_DIR" ]; then
    info "Movendo conteúdo para raiz..."
    shopt -s dotglob
    mv "$INSTALL_BASE_DIR/$ZIP_ROOT_DIR/"* "$INSTALL_BASE_DIR/"
    shopt -u dotglob
    rmdir "$INSTALL_BASE_DIR/$ZIP_ROOT_DIR" || aviso "Falha ao remover diretório temporário"
fi
sucesso "Extração concluída."

MAIN_SCRIPT_PATH="$INSTALL_SCRIPT_DIR/samba_manager.sh"
[ -f "$MAIN_SCRIPT_PATH" ] || {
    rm -f "$TMP_ZIP_FILE"
    rm -rf "$INSTALL_BASE_DIR"
    erro "Script principal não encontrado em $MAIN_SCRIPT_PATH"
}

info "Script principal localizado em: $MAIN_SCRIPT_PATH"

[ -d "$INSTALL_LOG_DIR" ] || {
    info "Criando diretório de logs..."
    mkdir -p "$INSTALL_LOG_DIR" || erro "Falha ao criar logs"
}
chown root:root "$INSTALL_LOG_DIR"
chmod 775 "$INSTALL_LOG_DIR"
chown -R root:root "$INSTALL_BASE_DIR"
chmod -R 755 "$INSTALL_BASE_DIR"

info "Tornando scripts executáveis..."
find "$INSTALL_SCRIPT_DIR" -name '*.sh' -exec chmod +x {} \; || aviso "Alguns scripts não foram alterados."

info "Criando lançador em $LAUNCHER_PATH..."
cat > "$LAUNCHER_PATH" << EOF
#!/bin/bash
INSTALL_DIR="$INSTALL_BASE_DIR"
SCRIPT_PATH="$MAIN_SCRIPT_PATH"

if [ ! -f "\$SCRIPT_PATH" ]; then
  echo "Erro: Script principal não encontrado em \$SCRIPT_PATH" >&2
  exit 1
fi

if [ "\$(id -u)" != "0" ]; then
    echo "Erro: Use 'sudo $LAUNCHER_NAME'" >&2
    exit 1
fi

cd "\$(dirname "\$SCRIPT_PATH")" || exit 1
LANGUAGE=\$LANGUAGE "./\$(basename "\$SCRIPT_PATH")" "\$@"
exit \$?
EOF

chmod +x "$LAUNCHER_PATH" || erro "Falha ao tornar lançador executável"
rm -f "$TMP_ZIP_FILE"

sucesso "Instalação concluída!"
info "Instalado em: $INSTALL_BASE_DIR"
info "Logs: $INSTALL_LOG_DIR"
info "Use com: sudo $LAUNCHER_NAME"

exit 0
