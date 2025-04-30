#!/bin/bash

# Script para Área Crítica - Remoção do Samba e/ou Manager
# Autor: Rafael Schuh (github.com/rafaelhschuh)
# Data: Abril 2025
# Descrição: Permite remover o Samba 4, o Samba Manager Script, ou ambos.
#            AVISO: Ações destrutivas e irreversíveis!

# Diretório dos scripts e locale
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOCALE_DIR="$SCRIPT_DIR/locale"
MANAGER_INSTALL_DIR="$HOME/.samba-scripts" # Diretório de instalação do Manager
LAUNCHER_PATH="/usr/local/bin/samba-script" # Caminho do lançador

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
OUTPUT="/tmp/samba_critical_output.$$"

# Função para limpar e sair (usada antes de iniciar a remoção do manager)
limpar_e_sair_parcial() {
    rm -f $OUTPUT
    exit 0
}

# Função para exibir mensagens de erro e sair
erro() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_ERROR" --msgbox "$1" 8 60
    rm -f $OUTPUT
    exit 1
}

# Função para exibir mensagens de sucesso (antes de sair)
sucesso_msg_final() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$MSG_SUCCESS" --msgbox "$1" 8 60
    rm -f $OUTPUT
    exit 0
}

# Verificar se dialog está instalado
verificar_dependencias() {
    if ! command -v dialog &> /dev/null; then
        echo "Instalando dialog... / Installing dialog..."
        apt-get update > /dev/null 2>&1 && apt-get install -y dialog > /dev/null 2>&1 || erro "Falha ao instalar dialog / Failed to install dialog"
    fi
}

# Verificar se o script está sendo executado como root
if [ "$(id -u)" != "0" ]; then
    dialog --title "Erro / Error" --msgbox "Este script deve ser executado como root para remover pacotes e arquivos do sistema. Use \'sudo $0\'\n\nThis script must be run as root to remove packages and system files. Use \'sudo $0\'" 8 70
    exit 1
fi

# Verificar dependências
verificar_dependencias

# Função para remover o Samba 4
remover_samba() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$CRITICAL_AREA_REMOVE_SAMBA" --infobox "$CRITICAL_AREA_REMOVING_SAMBA" 5 60
    
    # Parar serviços
    echo "[INFO] Parando serviços Samba..."
    systemctl stop samba-ad-dc smbd nmbd winbind > /dev/null 2>&1
    systemctl disable samba-ad-dc smbd nmbd winbind > /dev/null 2>&1
    
    # Remover pacotes e configurações
    echo "[INFO] Removendo pacotes Samba (purge)..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y samba samba-* winbind libpam-winbind libnss-winbind krb5-config krb5-user > /tmp/samba_remove.log 2>&1
    apt-get autoremove -y >> /tmp/samba_remove.log 2>&1
    apt-get autoclean >> /tmp/samba_remove.log 2>&1
    unset DEBIAN_FRONTEND
    
    # Remover arquivos/diretórios residuais (cuidado!)
    echo "[INFO] Removendo diretórios e arquivos residuais..."
    rm -rf /etc/samba /var/lib/samba /var/log/samba /var/cache/samba /run/samba
    # Remover configuração kerberos se existir
    rm -f /etc/krb5.conf
    # Restaurar nsswitch.conf (remover menção a winbind)
    if [ -f /etc/nsswitch.conf ]; then
        sed -i 	'/winbind/d' /etc/nsswitch.conf
    fi
    # Restaurar resolv.conf (remover imutabilidade)
    chattr -i /etc/resolv.conf 2>/dev/null
    # (Opcional: restaurar para DHCP ou configuração padrão)
    
    echo "[INFO] Remoção do Samba concluída."
    sleep 1
}

# Função para remover o Samba Manager Script (com auto-remoção)
remover_manager() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$CRITICAL_AREA_REMOVE_MANAGER" --infobox "$CRITICAL_AREA_REMOVING_MANAGER" 5 60
    
    # Remover lançador
    echo "[INFO] Removendo lançador $LAUNCHER_PATH..."
    rm -f "$LAUNCHER_PATH"
    
    # Agendar remoção do diretório de instalação e sair
    echo "[INFO] Agendando remoção de $MANAGER_INSTALL_DIR e saindo..."
    
    # Criar script temporário para remoção
    cat > /tmp/remove_manager.sh << EOF
#!/bin/bash
sleep 2 # Espera o script principal terminar
rm -rf "$MANAGER_INSTALL_DIR"
rm -f /tmp/remove_manager.sh # Auto-remove o script temporário
EOF
    chmod +x /tmp/remove_manager.sh
    
    # Executar script temporário em background e desassociar
    nohup /tmp/remove_manager.sh > /dev/null 2>&1 &
    disown
    
    # Mensagem final antes de sair (o dialog pode não aparecer se sair muito rápido)
    echo "$CRITICAL_AREA_MANAGER_REMOVED"
    sleep 1 # Pequena pausa
    limpar_e_sair_parcial # Sair para permitir a auto-remoção
}

# Função para remover tudo
remover_tudo() {
    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$CRITICAL_AREA_REMOVE_ALL" --infobox "$CRITICAL_AREA_REMOVING_ALL" 5 60
    
    # Remover Samba primeiro
    remover_samba
    
    # Remover Manager (que também sairá do script)
    remover_manager
}

# Menu Principal da Área Crítica
menu_area_critica() {
    dialog --clear --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" \
           --title "$CRITICAL_AREA_TITLE" \
           --msgbox "$CRITICAL_AREA_WARNING" 8 70

    dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" \
           --title "$CRITICAL_AREA_TITLE" \
           --menu "$CRITICAL_AREA_CHOOSE" 15 70 4 \
           1 "$CRITICAL_AREA_REMOVE_SAMBA" \
           2 "$CRITICAL_AREA_REMOVE_MANAGER" \
           3 "$CRITICAL_AREA_REMOVE_ALL" \
           4 "$MSG_EXIT" 2> $OUTPUT
    
    exit_status=$?
    choice=$(cat $OUTPUT)
    rm -f $OUTPUT
    
    if [ $exit_status -ne 0 ] || [ "$choice" == "4" ]; then
        limpar_e_sair_parcial # Voltar ao menu principal
    fi
    
    case $choice in
        1)
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$CRITICAL_AREA_REMOVE_SAMBA" --yesno "$CRITICAL_AREA_CONFIRM_SAMBA" 10 70
            if [ $? -eq 0 ]; then
                remover_samba
                sucesso_msg_final "$CRITICAL_AREA_SAMBA_REMOVED"
            else
                dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "$MSG_CANCELED" 5 40
            fi
            ;;
        2)
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$CRITICAL_AREA_REMOVE_MANAGER" --yesno "$CRITICAL_AREA_CONFIRM_MANAGER" 10 70
            if [ $? -eq 0 ]; then
                remover_manager # Esta função sairá do script
            else
                dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "$MSG_CANCELED" 5 40
            fi
            ;;
        3)
            dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --title "$CRITICAL_AREA_REMOVE_ALL" --yesno "$CRITICAL_AREA_CONFIRM_ALL" 10 70
            if [ $? -eq 0 ]; then
                remover_tudo # Esta função sairá do script
            else
                dialog --backtitle "Samba Manager - Rafael Schuh (github.com/rafaelhschuh)" --msgbox "$MSG_CANCELED" 5 40
            fi
            ;;
    esac
}

# Iniciar menu da área crítica
menu_area_critica

# Limpar e sair (se o menu retornar por algum motivo inesperado)
limpar_e_sair_parcial

