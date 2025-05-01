#!/bin/bash

# Script para adicionar novos funcionários ao servidor Samba com Interface Dialog e Suporte a Idiomas
# Autor: Rafael Schuh (github.com/rafaelhschuh) (Refatorado por Manus em Maio 2025)
# Data: Abril 2025
# Descrição: Adiciona um novo usuário ao sistema e ao Samba usando dialog, sem criar home,
#            e o adiciona a um grupo específico. Suporta PT-BR/EN-US.

# --- Configuração e Inicialização ---

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LIB_DIR="$SCRIPT_DIR/lib"
LOCALE_DIR="$SCRIPT_DIR/locale"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
LOG_FILE="$LOG_DIR/samba_manager.log"

# Carregar funções de logging
if [ -f "$LIB_DIR/logging.sh" ]; then
    source "$LIB_DIR/logging.sh"
else
    # Tenta logar erro crítico antes de sair
    echo "[$(date 
default_api.file_write(content = "#!/bin/bash

# Script para adicionar novos funcionários ao servidor Samba com Interface Dialog e Suporte a Idiomas
# Autor: Rafael Schuh (github.com/rafaelhschuh) (Refatorado por Manus em Maio 2025)
# Data: Abril 2025
# Descrição: Adiciona um novo usuário ao sistema e ao Samba usando dialog, sem criar home,
#            e o adiciona a um grupo específico. Suporta PT-BR/EN-US.

# --- Configuração e Inicialização ---

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LIB_DIR="$SCRIPT_DIR/lib"
LOCALE_DIR="$SCRIPT_DIR/locale"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
LOG_FILE="$LOG_DIR/samba_manager.log"

# Carregar funções de logging
if [ -f "$LIB_DIR/logging.sh" ]; then
    source "$LIB_DIR/logging.sh"
else
    # Tenta logar erro crítico antes de sair
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] - ERRO CRÍTICO: Arquivo de logging 
default_api.file_write(content = "#!/bin/bash

# Script para adicionar novos funcionários ao servidor Samba com Interface Dialog e Suporte a Idiomas
# Autor: Rafael Schuh (github.com/rafaelhschuh) (Refatorado por Manus em Maio 2025)
# Data: Abril 2025
# Descrição: Adiciona um novo usuário ao sistema e ao Samba usando dialog, sem criar home,
#            e o adiciona a um grupo específico. Suporta PT-BR/EN-US.

# --- Configuração e Inicialização ---

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LIB_DIR="$SCRIPT_DIR/lib"
LOCALE_DIR="$SCRIPT_DIR/locale"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
LOG_FILE="$LOG_DIR/samba_manager.log"

# Carregar funções de logging
if [ -f "$LIB_DIR/logging.sh" ]; then
    source "$LIB_DIR/logging.sh"
else
    # Tenta logar erro crítico antes de sair
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] - ERRO CRÍTICO: Arquivo de logging 
default_api.file_write(content = "#!/bin/bash

# Script para adicionar novos funcionários ao servidor Samba com Interface Dialog e Suporte a Idiomas
# Autor: Rafael Schuh (github.com/rafaelhschuh) (Refatorado por Manus em Maio 2025)
# Data: Abril 2025
# Descrição: Adiciona um novo usuário ao sistema e ao Samba usando dialog, sem criar home,
#            e o adiciona a um grupo específico. Suporta PT-BR/EN-US.

# --- Configuração e Inicialização ---

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LIB_DIR="$SCRIPT_DIR/lib"
LOCALE_DIR="$SCRIPT_DIR/locale"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
LOG_FILE="$LOG_DIR/samba_manager.log"

# Carregar funções de logging
if [ -f "$LIB_DIR/logging.sh" ]; then
    source "$LIB_DIR/logging.sh"
else
    # Tenta logar erro crítico antes de sair
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] - ERRO CRÍTICO: Arquivo de logging '$LIB_DIR/logging.sh' não encontrado em adicionar_usuario_dialog.sh." >> "$LOG_FILE" 2>/dev/null
    echo "ERRO CRÍTICO: Arquivo de logging '$LIB_DIR/logging.sh' não encontrado."
    exit 1
fi

log_message "INFO: Iniciando script adicionar_usuario_dialog.sh"

# Carregar idioma (passado como variável de ambiente ou padrão para en_US)
LANGUAGE=${LANGUAGE:-en_US}
log_message "INFO: Verificando arquivo de idioma: $LANGUAGE"
if [ -f "$LOCALE_DIR/${LANGUAGE}.sh" ]; then
    source "$LOCALE_DIR/${LANGUAGE}.sh"
    log_message "INFO: Arquivo de idioma '$LANGUAGE' carregado."
else
    log_message "AVISO: Arquivo de idioma '$LOCALE_DIR/${LANGUAGE}.sh' não encontrado. Usando en_US como padrão."
    echo "Warning: Language file $LOCALE_DIR/${LANGUAGE}.sh not found. Falling back to English."
    if [ -f "$LOCALE_DIR/en_US.sh" ]; then
        source "$LOCALE_DIR/en_US.sh"
        LANGUAGE="en_US"
    else
        log_message "ERRO CRÍTICO: Arquivo de idioma padrão 'en_US.sh' não encontrado."
        echo "CRITICAL ERROR: Default language file en_US.sh not found."
        exit 1
    fi
fi

# Arquivo temporário para capturar saída do dialog
OUTPUT="/tmp/samba_adduser_output.$$"

# --- Funções Auxiliares ---

# Função para exibir mensagens de erro, logar e sair
erro_exit() {
    local msg="$1"
    log_message "ERRO: $msg"
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$msg" 8 60
    rm -f $OUTPUT
    exit 1
}

# Função para exibir mensagens de aviso e logar
aviso_msg() {
    local msg="$1"
    log_message "AVISO: $msg"
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_WARNING" --msgbox "$msg" 8 60
}

# Função para exibir mensagens de sucesso e logar
sucesso_msg() {
    local msg="$1"
    log_message "SUCESSO: $msg"
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_SUCCESS" --msgbox "$msg" 8 60
}

# Função para cancelar e sair
cancelar_exit() {
    log_message "INFO: Operação cancelada pelo usuário."
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "$MSG_CANCELED" 5 40
    rm -f $OUTPUT
    exit 0
}

# --- Execução Principal ---

# Verificar se o script está sendo executado como root
log_message "INFO: Verificando privilégios de root."
if [ "$(id -u)" != "0" ]; then
    erro_exit "Este script deve ser executado como root. Use 'sudo $0'\n\nThis script must be run as root. Use 'sudo $0'"
fi
log_message "INFO: Executando como root."

# Verificar se dialog está instalado (já deve estar pelo script principal, mas por segurança)
log_message "INFO: Verificando se o comando 'dialog' está disponível."
if ! command -v dialog &> /dev/null; then
    log_message "ERRO: Comando 'dialog' não encontrado."
    echo "Comando 'dialog' não encontrado. Instale-o manualmente.\n\nCommand 'dialog' not found. Please install it manually."
    exit 1
fi
log_message "INFO: Comando 'dialog' encontrado."

# Exibir tela de boas-vindas
log_message "INFO: Exibindo tela de boas-vindas para adicionar usuário."
dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_TITLE" --msgbox "$ADD_USER_DESC" 8 70

# Solicitar nome do grupo Samba
log_message "INFO: Solicitando nome do grupo Samba."
dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_GROUP" --inputbox "$ADD_USER_GROUP_PROMPT" 8 60 "sambausers" 2> $OUTPUT
exit_status=$?
SAMBA_GROUP=$(cat $OUTPUT)
rm -f $OUTPUT

if [ $exit_status -ne 0 ]; then
    cancelar_exit
fi

# Usar sambausers como padrão se nenhum grupo for especificado
if [ -z "$SAMBA_GROUP" ]; then
    log_message "INFO: Nenhum grupo especificado, usando 'sambausers' como padrão."
    SAMBA_GROUP="sambausers"
fi
log_message "INFO: Grupo Samba definido como '$SAMBA_GROUP'."

# Verificar se o grupo existe, senão perguntar se deseja criar
log_message "INFO: Verificando se o grupo '$SAMBA_GROUP' existe."
if ! getent group "$SAMBA_GROUP" > /dev/null; then
    log_message "AVISO: Grupo '$SAMBA_GROUP' não encontrado."
    GROUP_CREATE_PROMPT=$(printf "$ADD_USER_GROUP_CREATE" "$SAMBA_GROUP")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_GROUP_NOT_FOUND" --yesno "$GROUP_CREATE_PROMPT" 6 60
    if [ $? -eq 0 ]; then
        log_message "INFO: Usuário optou por criar o grupo '$SAMBA_GROUP'."
        if sudo groupadd "$SAMBA_GROUP"; then
            log_message "SUCESSO: Grupo '$SAMBA_GROUP' criado."
            GROUP_SUCCESS_MSG=$(printf "$ADD_USER_GROUP_SUCCESS" "$SAMBA_GROUP")
            sucesso_msg "$GROUP_SUCCESS_MSG"
        else
            erro_exit "Falha ao criar o grupo $SAMBA_GROUP / Failed to create group $SAMBA_GROUP"
        fi
    else
        log_message "INFO: Usuário optou por não criar o grupo '$SAMBA_GROUP'. Saindo."
        GROUP_REQUIRED_MSG=$(printf "$ADD_USER_GROUP_REQUIRED" "$SAMBA_GROUP")
        erro_exit "$GROUP_REQUIRED_MSG"
    fi
else
    log_message "INFO: Grupo '$SAMBA_GROUP' já existe."
fi

# Solicitar nome de usuário
log_message "INFO: Solicitando nome de usuário."
dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_NAME" --inputbox "$ADD_USER_NAME_PROMPT" 8 50 2> $OUTPUT
exit_status=$?
USERNAME=$(cat $OUTPUT)
rm -f $OUTPUT

if [ $exit_status -ne 0 ]; then
    cancelar_exit
fi

if [ -z "$USERNAME" ]; then
    erro_exit "$ADD_USER_EMPTY_NAME"
fi
log_message "INFO: Nome de usuário fornecido: '$USERNAME'."

# Verificar se o usuário já existe no sistema
log_message "INFO: Verificando se o usuário '$USERNAME' já existe no sistema."
if id "$USERNAME" &>/dev/null; then
    log_message "AVISO: Usuário '$USERNAME' já existe no sistema."
    USER_EXISTS_PROMPT=$(printf "$ADD_USER_EXISTS_PROMPT" "$USERNAME")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_EXISTS" --yesno "$USER_EXISTS_PROMPT" 8 60
    if [ $? -ne 0 ]; then
        cancelar_exit
    fi
    log_message "INFO: Usuário optou por continuar mesmo com usuário existente."
    USER_EXISTS_SYSTEM=true
else
    # Criar o usuário do sistema sem diretório home e com shell nologin/false
    log_message "INFO: Criando usuário '$USERNAME' no sistema (sem diretório home, shell /sbin/nologin)."
    USER_CREATING_INFO=$(printf "$ADD_USER_CREATING_INFO" "$USERNAME")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_CREATING" --infobox "$USER_CREATING_INFO" 5 50
    sleep 1 # Pequena pausa para o infobox ser visível
    if sudo useradd -M -s /sbin/nologin "$USERNAME"; then
        log_message "SUCESSO: Usuário '$USERNAME' criado no sistema."
        USER_SUCCESS_MSG=$(printf "$ADD_USER_SUCCESS" "$USERNAME")
        sucesso_msg "$USER_SUCCESS_MSG"
        USER_EXISTS_SYSTEM=false
    else
        erro_exit "Falha ao criar o usuário $USERNAME / Failed to create user $USERNAME"
    fi
fi

# Adicionar usuário ao grupo Samba (se já não pertencer)
log_message "INFO: Verificando se o usuário '$USERNAME' pertence ao grupo '$SAMBA_GROUP'."
if ! groups "$USERNAME" | grep -q "\b$SAMBA_GROUP\b"; then
    log_message "INFO: Adicionando usuário '$USERNAME' ao grupo '$SAMBA_GROUP'."
    ADDING_GROUP_INFO=$(printf "$ADD_USER_ADDING_GROUP_INFO" "$USERNAME" "$SAMBA_GROUP")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_ADDING_GROUP" --infobox "$ADDING_GROUP_INFO" 5 60
    sleep 1
    if sudo usermod -aG "$SAMBA_GROUP" "$USERNAME"; then
        log_message "SUCESSO: Usuário '$USERNAME' adicionado ao grupo '$SAMBA_GROUP'."
        ADDING_GROUP_SUCCESS_MSG=$(printf "$ADD_USER_ADDING_GROUP_SUCCESS" "$USERNAME" "$SAMBA_GROUP")
        sucesso_msg "$ADDING_GROUP_SUCCESS_MSG"
    else
        # Não sair em caso de erro aqui, mas avisar
        log_message "AVISO: Falha ao adicionar usuário '$USERNAME' ao grupo '$SAMBA_GROUP' com usermod. Verifique manualmente."
        aviso_msg "Falha ao adicionar usuário ao grupo $SAMBA_GROUP / Failed to add user to group $SAMBA_GROUP"
    fi
else
    log_message "INFO: Usuário '$USERNAME' já pertence ao grupo '$SAMBA_GROUP'."
fi

# Definir/Redefinir senha para o usuário no sistema
log_message "INFO: Solicitando definição/redefinição de senha para '$USERNAME' no sistema."
SYS_PASS_INFO=$(printf "$ADD_USER_SYS_PASS_INFO" "$USERNAME")
dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_SYS_PASS" --msgbox "$SYS_PASS_INFO" 6 60

PASS1=""
PASS2=""
while true; do
    SYS_PASS_PROMPT=$(printf "$ADD_USER_SYS_PASS_PROMPT" "$USERNAME")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_SYS_PASS" --passwordbox "$SYS_PASS_PROMPT" 8 60 2> $OUTPUT
    exit_status=$?
    PASS1=$(cat $OUTPUT)
    rm -f $OUTPUT
    [ $exit_status -ne 0 ] && cancelar_exit
    
    SYS_PASS_CONFIRM=$(printf "$ADD_USER_SYS_PASS_CONFIRM" "$USERNAME")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_SYS_PASS" --passwordbox "$SYS_PASS_CONFIRM" 8 60 2> $OUTPUT
    exit_status=$?
    PASS2=$(cat $OUTPUT)
    rm -f $OUTPUT
    [ $exit_status -ne 0 ] && cancelar_exit
    
    if [ "$PASS1" == "$PASS2" ] && [ -n "$PASS1" ]; then
        log_message "INFO: Senhas do sistema para '$USERNAME' coincidem."
        break
    else
        log_message "AVISO: Senhas do sistema para '$USERNAME' não coincidem ou estão vazias."
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$ADD_USER_PASS_MISMATCH" 5 60
    fi
done

# Definir senha do sistema
log_message "INFO: Definindo senha do sistema para '$USERNAME'."
if echo -e "$PASS1\n$PASS1" | sudo passwd "$USERNAME" > /dev/null 2>&1; then
    log_message "SUCESSO: Senha do sistema para '$USERNAME' definida."
    SYS_PASS_SUCCESS_MSG=$(printf "$ADD_USER_SYS_PASS_SUCCESS" "$USERNAME")
    sucesso_msg "$SYS_PASS_SUCCESS_MSG"
else
    # Não sair, mas avisar
    log_message "AVISO: Falha ao definir senha do sistema para '$USERNAME'."
    aviso_msg "Falha ao definir senha para o usuário $USERNAME no sistema / Failed to set system password for user $USERNAME"
fi

# Verificar se o Samba (smbpasswd) está disponível
log_message "INFO: Verificando se o comando 'smbpasswd' está disponível."
if ! command -v smbpasswd &> /dev/null; then
    log_message "AVISO: Comando 'smbpasswd' não encontrado. Pulando etapa de senha do Samba."
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_SAMBA_NOT_FOUND" --yesno "$ADD_USER_SAMBA_NOT_FOUND_PROMPT" 8 60
    if [ $? -ne 0 ]; then
        cancelar_exit
    fi
else
    log_message "INFO: Comando 'smbpasswd' encontrado."
    # Definir/Atualizar senha para o usuário no Samba
    SAMBA_PASS_INFO=$(printf "$ADD_USER_SAMBA_PASS_INFO" "$USERNAME")
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_SAMBA_PASS" --msgbox "$SAMBA_PASS_INFO" 6 70
    
    SAMBA_PASS1=""
    SAMBA_PASS2=""
    while true; do
        SAMBA_PASS_PROMPT=$(printf "$ADD_USER_SAMBA_PASS_PROMPT" "$USERNAME")
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_SAMBA_PASS" --passwordbox "$SAMBA_PASS_PROMPT" 8 60 2> $OUTPUT
        exit_status=$?
        SAMBA_PASS1=$(cat $OUTPUT)
        rm -f $OUTPUT
        [ $exit_status -ne 0 ] && cancelar_exit
        
        SAMBA_PASS_CONFIRM=$(printf "$ADD_USER_SAMBA_PASS_CONFIRM" "$USERNAME")
        dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_SAMBA_PASS" --passwordbox "$SAMBA_PASS_CONFIRM" 8 60 2> $OUTPUT
        exit_status=$?
        SAMBA_PASS2=$(cat $OUTPUT)
        rm -f $OUTPUT
        [ $exit_status -ne 0 ] && cancelar_exit
        
        if [ "$SAMBA_PASS1" == "$SAMBA_PASS2" ] && [ -n "$SAMBA_PASS1" ]; then
            log_message "INFO: Senhas do Samba para '$USERNAME' coincidem."
            break
        else
            log_message "AVISO: Senhas do Samba para '$USERNAME' não coincidem ou estão vazias."
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$ADD_USER_PASS_MISMATCH" 5 60
        fi
    done
    
    # Adicionar/Atualizar senha do Samba
    # Se o usuário do sistema foi criado agora, usar 'smbpasswd -a'
    # Se o usuário do sistema já existia, tentar 'smbpasswd -a' e se falhar (já existe no samba), usar 'smbpasswd'
    if [ "$USER_EXISTS_SYSTEM" = false ]; then
        log_message "INFO: Adicionando usuário '$USERNAME' ao Samba com 'smbpasswd -a'."
        if echo -e "$SAMBA_PASS1\n$SAMBA_PASS1" | sudo smbpasswd -a "$USERNAME" > /dev/null 2>&1; then
            log_message "SUCESSO: Usuário '$USERNAME' adicionado e senha definida no Samba."
            SAMBA_PASS_SUCCESS_MSG=$(printf "$ADD_USER_SAMBA_PASS_SUCCESS" "$USERNAME")
            sucesso_msg "$SAMBA_PASS_SUCCESS_MSG"
        else
            # Tentar habilitar caso 'smbpasswd -a' falhe (cenário incomum aqui, mas por segurança)
            log_message "AVISO: Falha ao adicionar usuário '$USERNAME' com 'smbpasswd -a'. Tentando habilitar com 'smbpasswd -e'."
            if sudo smbpasswd -e "$USERNAME" > /dev/null 2>&1; then
                 log_message "INFO: Usuário '$USERNAME' habilitado no Samba. Tentando definir senha novamente."
                 if echo -e "$SAMBA_PASS1\n$SAMBA_PASS1" | sudo smbpasswd "$USERNAME" > /dev/null 2>&1; then
                     log_message "SUCESSO: Senha do Samba para '$USERNAME' definida após habilitação."
                     SAMBA_PASS_SUCCESS_MSG=$(printf "$ADD_USER_SAMBA_PASS_SUCCESS" "$USERNAME")
                     sucesso_msg "$SAMBA_PASS_SUCCESS_MSG"
                 else
                     log_message "AVISO: Falha ao definir senha do Samba para '$USERNAME' após habilitação."
                     aviso_msg "Falha ao definir senha para o usuário $USERNAME no Samba após habilitação / Failed to set Samba password for user $USERNAME after enabling"
                 fi
            else
                 log_message "ERRO: Falha ao adicionar ou habilitar usuário '$USERNAME' no Samba."
                 erro_exit "Falha ao adicionar/habilitar usuário $USERNAME no Samba / Failed to add/enable user $USERNAME in Samba"
            fi
        fi
    else # USER_EXISTS_SYSTEM = true
        log_message "INFO: Usuário '$USERNAME' já existia no sistema. Tentando adicionar/atualizar no Samba."
        # Tentar adicionar primeiro, pode não existir no Samba ainda
        if echo -e "$SAMBA_PASS1\n$SAMBA_PASS1" | sudo smbpasswd -a "$USERNAME" > /dev/null 2>&1; then
             log_message "SUCESSO: Usuário '$USERNAME' adicionado ao Samba (não existia antes) e senha definida."
             SAMBA_PASS_SUCCESS_MSG=$(printf "$ADD_USER_SAMBA_PASS_SUCCESS" "$USERNAME")
             sucesso_msg "$SAMBA_PASS_SUCCESS_MSG"
        else
            # Se falhou, provavelmente já existe, então tentar redefinir a senha
            log_message "INFO: Falha ao adicionar com 'smbpasswd -a' (provavelmente já existe). Tentando redefinir senha com 'smbpasswd'."
            if echo -e "$SAMBA_PASS1\n$SAMBA_PASS1" | sudo smbpasswd "$USERNAME" > /dev/null 2>&1; then
                log_message "SUCESSO: Senha do Samba para '$USERNAME' redefinida."
                SAMBA_PASS_SUCCESS_MSG=$(printf "$ADD_USER_SAMBA_PASS_SUCCESS" "$USERNAME")
                sucesso_msg "$SAMBA_PASS_SUCCESS_MSG"
            else
                log_message "AVISO: Falha ao redefinir senha do Samba para '$USERNAME'."
                aviso_msg "Falha ao redefinir senha para o usuário $USERNAME no Samba / Failed to reset Samba password for user $USERNAME"
            fi
        fi
    fi
fi

# Exibir informações finais do usuário
log_message "INFO: Exibindo informações finais do usuário '$USERNAME'."
USER_INFO_RAW=$(id "$USERNAME" 2>&1; groups "$USERNAME" 2>&1)
USER_INFO_SUCCESS_MSG=$(printf "$ADD_USER_INFO_SUCCESS" "$USERNAME" "$SAMBA_GROUP" "$USER_INFO_RAW")
dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$ADD_USER_INFO" --msgbox "$USER_INFO_SUCCESS_MSG" 15 70

log_message "INFO: Script adicionar_usuario_dialog.sh concluído com sucesso para '$USERNAME'."
# Limpar arquivo temporário na saída normal
rm -f $OUTPUT
exit 0

