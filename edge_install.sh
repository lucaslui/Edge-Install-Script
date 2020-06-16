#!/bin/bash
# ------------------------------------------------------------------------------ #
#
# Shell script para instalar o Azure IoT Edge no dispositivo HEMS
#
# ------------------------------------------------------------------------------ #
VERMELHO='\e[31m'
CYAN='\e[96m'
VERDE='\e[32m'
SEM_COR='\e[0m'
# ------------------------------------------------------------------------------ #
# Testando conexão com a internet

echo -e "${CYAN}[STEP] - Testando conexão com a internet...${SEM_COR}"
if ! ping -c 1 8.8.8.8 -q &> /dev/null; then
  echo -e "${VERMELHO}[INFO] - Dispositivo sem conexão com a internet.${SEM_COR}"
  exit 1
else
  echo -e "${VERDE}[INFO] - Conexão com a internet funcionando.${SEM_COR}"
fi

# ------------------------------------------------------------------------------ #
# Testando se já estão instalados alguns programas e depêndencias 

PROGRAMAS_PARA_INSTALAR_APT=(
  curl
  coreutils
  xxd
  openssl)

echo -e "${CYAN}[STEP] - Testando se já estão instalados os pacotes e dependências...${SEM_COR}"
for programa in ${PROGRAMAS_PARA_INSTALAR_APT[@]}; do
  if ! dpkg -l | grep -q $programa; then
    echo -e "${VERMELHO}[INFO] - Pacote '$programa' não está instalado.${SEM_COR}"
    echo -e "${VERDE}[INFO] - Instalando o pacote $programa...${SEM_COR}"
    sudo apt install $programa -y 
    if [ 0 -eq $? ]; then
    echo -e "${VERDE}[INFO] - Pacote '$programa' instalado com sucesso.${SEM_COR}"
    else
        echo -e "${VERMELHO}[INFO] - Falha na instalação do pacote. $programa.${SEM_COR}" && exit
    fi
  else
    echo -e "${VERDE}[INFO] - Pacote '$programa' já está instalado.${SEM_COR}"
  fi
done

# ------------------------------------------------------------------------------ #
# Instalando repositório de programas da Microsoft

echo -e "${CYAN}[STEP] - Instalando o repositório de programas da Microsoft...${SEM_COR}"
RESPONSE=$(curl --fail -s https://packages.microsoft.com/config/ubuntu/18.04/multiarch/prod.list)
if [ 0 -eq $? ]; then
    echo -e "$RESPONSE" > /etc/apt/sources.list.d/microsoft-prod.list
    echo -e "${VERDE}[INFO] - Repositório instalado com sucesso.${SEM_COR}"
else
    echo -e "${VERMELHO}[INFO] - Falha na instalação do repositório.${SEM_COR}" && exit
fi

# ------------------------------------------------------------------------------ #
# Registra a chave da Microsoft

echo -e "${CYAN}[STEP] - Registrando a chave de acesso da Microsoft...${SEM_COR}"
RESPONSE=$(curl --fail -s https://packages.microsoft.com/keys/microsoft.asc)
if [ 0 -eq $? ]; then
    echo -e "$RESPONSE" | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg 2> /dev/null
    sudo chmod 644 /etc/apt/trusted.gpg.d/microsoft.gpg
    echo -e "${VERDE}[INFO] - Chave registrada com sucesso.${SEM_COR}"
else
    echo -e "${VERMELHO}[INFO] - Falha na registração da chave.${SEM_COR}" && exit
fi

# ------------------------------------------------------------------------------ #
# Atualizando a lista de programas no repositório do sistema e da Microsoft

echo -e "${CYAN}[STEP] - Atualizando a lista pacotes nos repositórios...${SEM_COR}"
sudo apt-get update -qq
if [ 0 -eq $? ]; then
    echo -e "${VERDE}[INFO] - Repositórios atualizados com sucesso.${SEM_COR}"
else
    echo -e "${VERMELHO}[INFO] - Falha na atualização dos repositórios.${SEM_COR}" && exit
fi

# ------------------------------------------------------------------------------ #
# Instalando o tempo de execução da tecnologia de container Moby

echo -e "${CYAN}[STEP] - Instalando a tecnologia de container Moby-engine...${SEM_COR}"
sudo apt-get install moby-engine -qq -y
if [ 0 -eq $? ]; then
    echo -e "${VERDE}[INFO] - Moby-engine instalado com sucesso.${SEM_COR}"
else
    echo -e "${VERMELHO}[INFO] - Falha na instalação do Moby-engine.${SEM_COR}" && exit
fi

# ------------------------------------------------------------------------------ #
# Instalando a interface de linha de comando Moby (CLI)

echo -e "${CYAN}[STEP] - Instalando a interface de linha de comando Moby-CLI...${SEM_COR}" 
sudo apt-get install moby-cli -qq -y &> /dev/null
if [ 0 -eq $? ]; then
    echo -e "${VERDE}[INFO] - Moby-CLI instalado com sucesso.${SEM_COR}"
else
    echo -e "${VERMELHO}[INFO] - Falha na instalação do Moby-CLI.${SEM_COR}" && exit
fi

# ------------------------------------------------------------------------------ #
# Instalando o Daemon de Segurança do Azure IoT Edge 

echo -e "${CYAN}[STEP] - Instalando o Azure IoT Edge Security Daemon...${SEM_COR}"
sudo apt-get install iotedge -qq -y &> /dev/null
if [ 0 -eq $? ]; then
    echo -e "${VERDE}[INFO] - Azure IoT Edge Security Daemon instalado com sucesso.${SEM_COR}"
else
    echo -e "${VERMELHO}[INFO] - Falha na instalação do Azure IoT Edge Security Daemon.${SEM_COR}" && exit
fi

# ------------------------------------------------------------------------------ #
# Configurando o Daemon de Segurança do Azure IoT Edge para modo Automático de provisionamento
# utilizando recurso DSP e atestado com chave simétrica)

echo -e "${CYAN}[STEP] - Configurando o IoT Edge para modo automático de provisionamento...${SEM_COR}"

SCOPE_ID="0ne001170B8"
GRP_KEY="4Yut//CG0ndjK3FyxxxVyz5tQ2lKHmVVTkH4b83NWsqC+BPrpSnM/itxfsQYnfI98Vt2OlNBCop2XYFsWqn64w=="
echo -e "${VERDE}[INFO] - Identificador DPS e chave de grupo foram atribuídos.${SEM_COR}"

REG_ID=$(sudo cat /sys/class/net/enp0s3/address)
if [ 0 -eq $? ]; then
    keybytes=$(echo $GRP_KEY | base64 --decode | xxd -p -u -c 1000)
    SYM_KEY=$(echo -n $REG_ID | openssl sha256 -mac HMAC -macopt hexkey:$keybytes -binary | base64)
    echo -e "${VERDE}[INFO] - Chave do dispositivo gerada com sucesso.${SEM_COR}"
    sudo sed -i "s/<SCOPE_ID>/$SCOPE_ID/g" /etc/iotedge/config.yaml
    sudo sed -i "s/<REGISTRATION_ID>/$REG_ID/g" /etc/iotedge/config.yaml
    sudo sed -i 's|<SYMMETRIC_KEY>|'"$SYM_KEY"'|g' /etc/iotedge/config.yaml
    sudo sed -i "53,55 s/^/#/" /etc/iotedge/config.yaml
    sudo sed -i "67,74 s/#//" /etc/iotedge/config.yaml
    #sudo sed -i "67,74 s/^ *//1" /etc/iotedge/config.yaml
    echo -e "${VERDE}[INFO] - Arquivo de configuração ajustado para provisionamento automático.${SEM_COR}"
else
    echo -e "${VERMELHO}[INFO] - Problema com obtenção do endereço MAC e geração da chave do dispositivo.${SEM_COR}" && exit
fi

#sudo sed -e "s/<SCOPE_ID>/$SCOPE_ID/g" \
#         -e "s/<REGISTRATION_ID>/$REG_ID/g" \
#         -e "s/<SYMMETRIC_KEY>/$SYM_KEY/g" \
#         -e "53,55 s/^/#/" \
#         -e "67,74 s/#//" /etc/iotedge/config.yaml > /home/lucas/shared/config.yaml

# ------------------------------------------------------------------------------ #
# Reiniciando o Azure IoT Edge
echo -e "${CYAN}[STEP] - Reiniciando o Azure IoT Edge com novas configurações...${SEM_COR}"
sudo systemctl restart iotedge
echo -e "${VERDE}[INFO] - Processo de instalação finalizado.${SEM_COR}"

# ------------------------------------------------------------------------------ #
# Checando se o Azure IoT Edge está funcionando

#echo -e "${CYAN}[STEP] - Iniciando o processo de checagem de funcionamento...${SEM_COR}"

#sudo iotedge check --iothub-hostname "AZURE-IOT-HUB-1.azure-devices.net" --verbose
#sudo iotedge list
# ------------------------------------------------------------------------------ #
