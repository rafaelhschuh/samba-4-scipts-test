#!/bin/bash

# Script Instalador Automatizado para o Samba Manager (Refatorado)
# Autor: Rafael Schuh (github.com/rafaelhschuh) (Adaptado por Manus em Maio 2025)
# Data: Maio 2025
# Descrição: Este script baixa o pacote zip do Samba Manager de um URL,
#            extrai para /opt/samba-manager-app e cria um lançador
#            em /usr/local/bin/samba-manager.
#            Pode ser executado via wget ou curl.

# --- Configuração --- #
# !!! IMPORTANTE: Substitua pelo URL real do seu arquivo zip !!!
DOWNLOAD_URL="https://raw.githubusercontent.com/rafaelhschuh/samba-4-scipts-test/refs/heads/main/samba_manager.zip"
# Diretório de instalação
INSTALL_BASE_DIR="/opt/samba-manager-app"
INSTALL_SCRIPT_DIR="$INSTALL_BASE_DIR/samba_manager"
INSTALL_LOG_DIR="$INSTALL_BASE_DIR/logs"
# Nome do arquivo zip temporário
TMP_ZIP_FILE="/tmp/samba-manager-refatorado.zip"
# Nome do script lançador
LAUNCHER_NAME="samba-manager"
# Caminho completo do lançador
LAUNCHER_PATH="/usr/local/bin/$LAUNCHER_NAME"
# Nome do diretório raiz esperado dentro do zip (ajuste se o zip for criado diferente)
ZIP_ROOT_DIR="samba_manager_teste"
# --- Fim da Configuração --- #

# Cores para mensagens
RED=\'\e[0;31m\'
GREEN=\'\e[0;32m\'
YELLOW=\'\e[1;33m\'
NC=\'\e[0m\' # Sem Cor

# Função para exibir mensagens de erro e sair
erro() {
    echo -e "${RED}[ERRO] $1${NC}"
    # Limpeza de arquivo temporário em caso de erro
    rm -f "$TMP_ZIP_FILE"
    exit 1
}

# Função para exibir mensagens de aviso
aviso() {
    echo -e "${YELLOW}[AVISO] $1${NC}"
}

# Função para exibir mensagens de sucesso
sucesso() {
    echo -e "${GREEN}[SUCESSO] $1${NC}"
}

# Função para exibir mensagens de informação
info() {
    echo -e "[INFO] $1"
}

# --- Início do Script --- #

info "Iniciando instalação automatizada do Samba Manager..."

# Verificar se o script está sendo executado como root
if [ "$(id -u)" != "0" ]; then
    erro "Este script precisa ser executado como root. Use \'sudo bash -c \"\$(wget...)\"\' ou \'sudo bash -c \"\$(curl...)\"\'"
fi

# Verificar dependências (wget/curl e unzip)
info "Verificando dependências (wget/curl, unzip)..."
DOWNLOAD_CMD=""
if command -v wget > /dev/null; then
    DOWNLOAD_CMD="wget -q -O"
elif command -v curl > /dev/null; then
    DOWNLOAD_CMD="curl -fsSL -o"
else
    info "\'wget\' ou \'curl\' não encontrado. Tentando instalar \'wget\'..."
    if ! apt-get update > /dev/null 2>&1; then
        aviso "Falha ao executar apt-get update. Tentando continuar..."
    fi
    if ! apt-get install -y wget > /dev/null 2>&1; then
        erro "Falha ao instalar \'wget\'. Instale \'wget\' ou \'curl\' manualmente e tente novamente."
    fi
    DOWNLOAD_CMD="wget -q -O"
fi

if ! command -v unzip > /dev/null; then
    info "\'unzip\' não encontrado. Tentando instalar \'unzip\'..."
    if ! apt-get update > /dev/null 2>&1; then
        aviso "Falha ao executar apt-get update novamente. Tentando continuar..."
    fi
    if ! apt-get install -y unzip > /dev/null 2>&1; then
        erro "Falha ao instalar \'unzip\'. Instale \'unzip\' manualmente e tente novamente."
    fi
fi
sucesso "Dependências verificadas."

# Baixar o arquivo zip
info "Baixando Samba Manager de $DOWNLOAD_URL..."
rm -f "$TMP_ZIP_FILE" # Remove zip temporário antigo se existir
if ! $DOWNLOAD_CMD "$TMP_ZIP_FILE" "$DOWNLOAD_URL"; then
    erro "Falha ao baixar o arquivo de $DOWNLOAD_URL. Verifique o URL e sua conexão."
fi
# Verificar se o download foi bem-sucedido (arquivo existe e não está vazio)
if [ ! -s "$TMP_ZIP_FILE" ]; then
    erro "Download falhou ou o arquivo baixado está vazio: $TMP_ZIP_FILE"
fi
sucesso "Download concluído para $TMP_ZIP_FILE."

# Remover instalação antiga, se existir
if [ -d "$INSTALL_BASE_DIR" ]; then
    info "Removendo instalação anterior em $INSTALL_BASE_DIR..."
    rm -rf "$INSTALL_BASE_DIR" || erro "Falha ao remover o diretório de instalação anterior $INSTALL_BASE_DIR. Verifique as permissões."
    sucesso "Instalação anterior removida."
fi

# Criar diretório de instalação base
info "Criando diretório de instalação $INSTALL_BASE_DIR..."
mkdir -p "$INSTALL_BASE_DIR" || erro "Falha ao criar o diretório $INSTALL_BASE_DIR"

# Extrair o arquivo zip para o diretório de instalação
info "Extraindo $TMP_ZIP_FILE para $INSTALL_BASE_DIR..."
# -o: sobrescrever arquivos existentes sem perguntar
# Extrai o conteúdo do diretório raiz do zip para o diretório de instalação
unzip -o "$TMP_ZIP_FILE" "$ZIP_ROOT_DIR/*" -d "$INSTALL_BASE_DIR/" > /dev/null 2>&1
EXTRACT_STATUS=$?

# Verificar se a extração foi bem-sucedida
if [ $EXTRACT_STATUS -ne 0 ]; then
    # Tentar extrair sem o diretório raiz, caso o zip não o contenha
    info "Primeira tentativa de extração falhou (status $EXTRACT_STATUS). Tentando extrair diretamente..."
    unzip -o "$TMP_ZIP_FILE" -d "$INSTALL_BASE_DIR/" > /dev/null 2>&1
    EXTRACT_STATUS=$?
    if [ $EXTRACT_STATUS -ne 0 ]; then
        rm -f "$TMP_ZIP_FILE"
        rm -rf "$INSTALL_BASE_DIR" # Limpa diretório de instalação em caso de falha
        erro "Falha ao extrair o arquivo $TMP_ZIP_FILE (status $EXTRACT_STATUS). Verifique o arquivo zip."
    fi
    # Se a segunda tentativa funcionou, não precisamos mover nada
else
    # Se a primeira tentativa funcionou (com ZIP_ROOT_DIR), mover conteúdo para a raiz de INSTALL_BASE_DIR
    info "Movendo conteúdo extraído para a raiz de $INSTALL_BASE_DIR..."
    # Shopt -s dotglob inclui arquivos ocultos no * (exceto . e ..)
    shopt -s dotglob
    mv "$INSTALL_BASE_DIR/$ZIP_ROOT_DIR/"* "$INSTALL_BASE_DIR/"
    shopt -u dotglob
    # Remover o diretório raiz vazio que ficou após mover
    rmdir "$INSTALL_BASE_DIR/$ZIP_ROOT_DIR" || aviso "Não foi possível remover o diretório temporário $INSTALL_BASE_DIR/$ZIP_ROOT_DIR"
fi
sucesso "Arquivos extraídos para $INSTALL_BASE_DIR."

# Verificar se o script principal existe após extração
MAIN_SCRIPT_PATH="$INSTALL_SCRIPT_DIR/samba_manager.sh"
if [ ! -f "$MAIN_SCRIPT_PATH" ]; then
    rm -f "$TMP_ZIP_FILE"
    rm -rf "$INSTALL_BASE_DIR"
    erro "Não foi possível encontrar o script principal \'$MAIN_SCRIPT_PATH\' após a extração. Instalação abortada."
fi
info "Script principal encontrado em: $MAIN_SCRIPT_PATH"

# Garantir que o diretório de logs existe e tem permissões corretas
if [ ! -d "$INSTALL_LOG_DIR" ]; then
    info "Criando diretório de logs $INSTALL_LOG_DIR..."
    mkdir -p "$INSTALL_LOG_DIR" || erro "Falha ao criar diretório de logs $INSTALL_LOG_DIR"
fi
# Definir permissões para o diretório de logs (permitir escrita por grupo)
chown root:root "$INSTALL_LOG_DIR"
chmod 775 "$INSTALL_LOG_DIR"

# Definir permissões gerais para a instalação
chown -R root:root "$INSTALL_BASE_DIR"
chmod -R 755 "$INSTALL_BASE_DIR"

# Tornar scripts copiados executáveis
info "Tornando scripts em $INSTALL_SCRIPT_DIR executáveis..."
find "$INSTALL_SCRIPT_DIR" -name '*.sh' -exec chmod +x {} \; || aviso "Falha ao tornar alguns scripts executáveis. Verifique as permissões."

# Criar o script lançador em /usr/local/bin
info "Criando lançador em $LAUNCHER_PATH..."
cat > "$LAUNCHER_PATH" << EOF
#!/bin/bash
# Lançador para o Samba Manager
# Gerado por install.sh (Automatizado)
# Autor: Rafael Schuh (github.com/rafaelhschuh) (Adaptado por Manus)

# Define o diretório base da instalação
INSTALL_DIR="$INSTALL_BASE_DIR"
SCRIPT_PATH="$MAIN_SCRIPT_PATH"

# Verifica se o script principal existe
if [ ! -f "\$SCRIPT_PATH" ]; then
  echo "Erro: Script principal do Samba Manager não encontrado em \$SCRIPT_PATH" >&2
  exit 1
fi

# Garante que está executando como root
if [ "\$(id -u)" != "0" ]; then
    echo "Erro: Samba Manager precisa ser executado como root. Use 'sudo $LAUNCHER_NAME'" >&2
    exit 1
fi

# Navega para o diretório do script para que caminhos relativos (como locale, lib) funcionem
cd "\$(dirname "\$SCRIPT_PATH")" || exit 1

# Executa o script principal, passando quaisquer argumentos
# LANGUAGE é passado para permitir que o script principal detecte o idioma
LANGUAGE=\$LANGUAGE "./\$(basename "\$SCRIPT_PATH")" "\$@"

exit \$?
EOF

# Dar permissão de execução ao lançador
chmod +x "$LAUNCHER_PATH" || erro "Falha ao definir permissões de execução para $LAUNCHER_PATH"

# Limpar o arquivo zip baixado
info "Limpando arquivo zip temporário..."
rm -f "$TMP_ZIP_FILE"

sucesso "Instalação/Atualização automatizada do Samba Manager concluída!"
info "O Samba Manager foi instalado em: $INSTALL_BASE_DIR"
info "O diretório de logs está em: $INSTALL_LOG_DIR"
info "Execute o gerenciador com o comando: sudo $LAUNCHER_NAME"

exit 0
