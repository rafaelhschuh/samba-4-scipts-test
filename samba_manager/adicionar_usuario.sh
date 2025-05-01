#!/bin/bash

# Script para adicionar novos funcionários ao servidor Samba
# Autor: Manus (Refatorado por Manus em Maio 2025)
# Data: Abril 2025
# Descrição: Adiciona um novo usuário ao sistema e ao Samba, sem criar diretório home,
#            e o adiciona a um grupo específico para acesso às pastas do Samba.

# --- Configuração e Inicialização ---

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LIB_DIR="$SCRIPT_DIR/lib"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
LOG_FILE="$LOG_DIR/samba_manager.log"

# Carregar funções de logging
if [ -f "$LIB_DIR/logging.sh" ]; then
    source "$LIB_DIR/logging.sh"
else
    echo "ERRO CRÍTICO: Arquivo de logging 
default_api.file_write(content = "#!/bin/bash

# Script para adicionar novos funcionários ao servidor Samba
# Autor: Manus (Refatorado por Manus em Maio 2025)
# Data: Abril 2025
# Descrição: Adiciona um novo usuário ao sistema e ao Samba, sem criar diretório home,
#            e o adiciona a um grupo específico para acesso às pastas do Samba.

# --- Configuração e Inicialização ---

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LIB_DIR="$SCRIPT_DIR/lib"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
LOG_FILE="$LOG_DIR/samba_manager.log"

# Carregar funções de logging
if [ -f "$LIB_DIR/logging.sh" ]; then
    source "$LIB_DIR/logging.sh"
else
    # Tenta logar erro crítico antes de sair
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] - ERRO CRÍTICO: Arquivo de logging '$LIB_DIR/logging.sh' não encontrado em adicionar_usuario.sh." >> "$LOG_FILE" 2>/dev/null
    echo "ERRO CRÍTICO: Arquivo de logging '$LIB_DIR/logging.sh' não encontrado."
    exit 1
fi

log_message "INFO: Iniciando script adicionar_usuario.sh"

# --- Funções Auxiliares ---

# Função para exibir mensagens de erro e sair
erro_exit() {
    log_message "ERRO: $1"
    echo "ERRO: $1"
    exit 1
}

# --- Execução Principal ---

# Verificar se o script está sendo executado como root
log_message "INFO: Verificando privilégios de root."
if [ "$(id -u)" != "0" ]; then
    erro_exit "Este script deve ser executado como root. Use 'sudo $0'"
fi
log_message "INFO: Executando como root."

# Nome do grupo que tem acesso às pastas do Samba
# Este valor pode ser alterado conforme a configuração do seu servidor
SAMBA_GROUP="sambausers"
log_message "INFO: Grupo Samba definido como '$SAMBA_GROUP'."

# Verificar se o grupo existe, senão criar
log_message "INFO: Verificando se o grupo '$SAMBA_GROUP' existe."
if ! getent group "$SAMBA_GROUP" > /dev/null; then
    log_message "AVISO: O grupo '$SAMBA_GROUP' não existe. Tentando criar..."
    if sudo groupadd "$SAMBA_GROUP"; then
        log_message "SUCESSO: Grupo '$SAMBA_GROUP' criado com sucesso."
    else
        erro_exit "Falha ao criar o grupo '$SAMBA_GROUP'. Verifique as permissões ou crie manualmente."
    fi
else
    log_message "INFO: Grupo '$SAMBA_GROUP' já existe."
fi

# Solicitar nome de usuário
read -p "Digite o nome de usuário para o novo funcionário: " USERNAME

# Validar se o nome de usuário foi fornecido
if [ -z "$USERNAME" ]; then
    erro_exit "Nome de usuário não pode ser vazio."
fi
log_message "INFO: Nome de usuário fornecido: '$USERNAME'."

# Verificar se o usuário já existe no sistema
if id "$USERNAME" &>/dev/null; then
    log_message "AVISO: O usuário '$USERNAME' já existe no sistema."
    read -p "Deseja continuar e apenas tentar adicionar ao grupo Samba e definir/atualizar senhas? (s/n): " CONTINUE
    if [[ "$CONTINUE" != "s" && "$CONTINUE" != "S" ]]; then
        log_message "INFO: Operação cancelada pelo usuário."
        exit 0
    fi
    USER_EXISTS=true
else
    # Criar o usuário do sistema sem diretório home e com shell nologin/false
    log_message "INFO: Criando usuário '$USERNAME' no sistema (sem diretório home, shell /sbin/nologin)."
    if sudo useradd -M -s /sbin/nologin "$USERNAME"; then
        log_message "SUCESSO: Usuário '$USERNAME' criado no sistema."
        USER_EXISTS=false
    else
        erro_exit "Falha ao criar o usuário '$USERNAME' no sistema."
    fi
fi

# Adicionar usuário ao grupo Samba (se já não pertencer)
log_message "INFO: Verificando se o usuário '$USERNAME' pertence ao grupo '$SAMBA_GROUP'."
if ! groups "$USERNAME" | grep -q "\b$SAMBA_GROUP\b"; then
    log_message "INFO: Adicionando usuário '$USERNAME' ao grupo '$SAMBA_GROUP'."
    if sudo usermod -aG "$SAMBA_GROUP" "$USERNAME"; then
        log_message "SUCESSO: Usuário '$USERNAME' adicionado ao grupo '$SAMBA_GROUP'."
    else
        # Não sair em caso de erro aqui, pode ser que o usuário já estivesse no grupo de outra forma
        log_message "AVISO: Falha ao adicionar usuário '$USERNAME' ao grupo '$SAMBA_GROUP' com usermod. Verifique manualmente."
        echo "AVISO: Falha ao adicionar usuário '$USERNAME' ao grupo '$SAMBA_GROUP'. Verifique manualmente."
    fi
else
    log_message "INFO: Usuário '$USERNAME' já pertence ao grupo '$SAMBA_GROUP'."
fi

# Definir/Redefinir senha para o usuário no sistema
log_message "INFO: Solicitando definição/redefinição de senha para '$USERNAME' no sistema."
echo "Por favor, defina a senha para o usuário '$USERNAME' no sistema:"
if ! sudo passwd "$USERNAME"; then
    # Não sair em caso de erro, mas avisar
    log_message "AVISO: Falha ao definir/redefinir senha para o usuário '$USERNAME' no sistema. Pode ser necessário tentar novamente."
    echo "AVISO: Falha ao definir/redefinir senha do sistema para '$USERNAME'."
else
    log_message "INFO: Senha do sistema para '$USERNAME' definida/redefinida."
fi

# Verificar se o Samba (smbpasswd) está disponível
if ! command -v smbpasswd &> /dev/null; then
    log_message "AVISO: Comando 'smbpasswd' não encontrado. O Samba pode não estar instalado ou configurado corretamente. Pulando etapa de senha do Samba."
    echo "AVISO: Comando 'smbpasswd' não encontrado. Pulando definição de senha do Samba."
else
    # Adicionar/Atualizar senha para o usuário no Samba
    if [ "$USER_EXISTS" = true ]; then
        log_message "INFO: Usuário '$USERNAME' já existe. Solicitando redefinição de senha no Samba."
        echo "Por favor, redefina a senha para o usuário '$USERNAME' no Samba:"
        if ! sudo smbpasswd "$USERNAME"; then
            log_message "AVISO: Falha ao redefinir senha para o usuário '$USERNAME' no Samba."
            echo "AVISO: Falha ao redefinir senha do Samba para '$USERNAME'."
        else
            log_message "SUCESSO: Senha do Samba para '$USERNAME' redefinida."
        fi
    else
        log_message "INFO: Solicitando definição de senha para '$USERNAME' no Samba."
        echo "Por favor, defina a senha para o usuário '$USERNAME' no Samba (pode ser a mesma do sistema):"
        if ! sudo smbpasswd -a "$USERNAME"; then
            # Se falhar, tentar habilitar o usuário (pode já existir no samba mas estar desabilitado)
            log_message "AVISO: Falha ao adicionar usuário '$USERNAME' com 'smbpasswd -a'. Tentando habilitar com 'smbpasswd -e'."
            echo "Tentando habilitar usuário '$USERNAME' no Samba..."
            if ! sudo smbpasswd -e "$USERNAME"; then
                 log_message "ERRO: Falha ao adicionar ou habilitar usuário '$USERNAME' no Samba com smbpasswd."
                 echo "ERRO: Falha ao definir senha/habilitar usuário '$USERNAME' no Samba."
                 # Não sair, mas informar o problema
            else
                 log_message "INFO: Usuário '$USERNAME' habilitado no Samba. Solicitando definição de senha novamente."
                 echo "Usuário habilitado. Por favor, defina a senha para '$USERNAME' no Samba agora:"
                 if ! sudo smbpasswd "$USERNAME"; then
                     log_message "AVISO: Falha ao definir senha para o usuário '$USERNAME' no Samba após habilitação."
                     echo "AVISO: Falha ao definir senha do Samba para '$USERNAME' após habilitação."
                 else
                     log_message "SUCESSO: Senha do Samba para '$USERNAME' definida após habilitação."
                 fi
            fi
        else
            log_message "SUCESSO: Usuário '$USERNAME' adicionado e senha definida no Samba."
        fi
    fi
fi

# Exibir informações finais
log_message "INFO: Informações finais do usuário '$USERNAME':"
echo "--- Informações do Usuário '$USERNAME' ---"
id "$USERNAME"
groups "$USERNAME"
echo "-----------------------------------------"

log_message "SUCESSO: Processo de configuração do usuário '$USERNAME' concluído."
echo "Usuário '$USERNAME' configurado. Verifique os logs para detalhes e possíveis avisos."
log_message "INFO: O usuário '$USERNAME' deve ter acesso às pastas do servidor Samba configuradas para o grupo '$SAMBA_GROUP'."

exit 0


