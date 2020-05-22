#!/bin/bash
# ------------------------------------------------------------------------------ #
#
# Shell script para instalar o Azure IoT Edge no dispositivo HEMS
#
# ------------------------------------------------------------------------------ #
VERMELHO='\e[1;91m'
CYAN='\e[36m'
VERDE='\e[1;92m'
SEM_COR='\e[0m'
PROGRAMAS_PARA_INSTALAR_APT=(
  curl
)
# -------------------------------TESTES----------------------------------------- #
echo -e "${CYAN}[STEP] - Testando a conexão com a internet...${SEM_COR}"
if ! ping -c 1 8.8.8.8 -q &> /dev/null; then
  echo -e "${VERMELHO}[ERROR] - HEMS sem conexão com a Internet. Verifique os cabos e o modem.${SEM_COR}"
  exit 1
else
  echo -e "${VERDE}[INFO] - Conexão com a internet funcionando normalmente.${SEM_COR}"
fi
echo -e "${CYAN}[STEP] - Testando se os pacotes e programas de depêndencia já estão instalados...${SEM_COR}"
for programa in ${PROGRAMAS_PARA_INSTALAR_APT[@]}; do
  if ! dpkg -l | grep -q $programa; then
    echo -e "${VERMELHO}[ERRO] - O pacote $programa não está instalado.${SEM_COR}"
    echo -e "${VERDE}[INFO] - Instalando o pacote $programa...${SEM_COR}"
    sudo apt install $programa -y || echo -e "${VERMELHO}[ERRO] - Falha na instalação do programa $programa.${SEM_COR}" && exit
  else
    echo -e "${VERDE}[INFO] - O pacote $programa já está instalado.${SEM_COR}"
  fi
done
# ------------------------------------------------------------------------------ #
# Registra a chave da Microsoft e o repositório de programas
echo -e "${CYAN}[STEP] - Instalando o repositório dos programas da Microsoft...${SEM_COR}"
curl https://packages.microsoft.com/config/ubuntu/18.04/multiarch/prod.list > /tmp/microsoft-prod.list &> /dev/null
echo -e "${VERDE}[INFO] - Copiando a lista de repositórios gerada...${SEM_COR}"
sudo cp /tmp//microsoft-prod.list /etc/apt/sources.list.d/
echo -e "${VERDE}[INFO] - Instalando a chave pública Microsoft GPG (GNU Privacy Guard)...${SEM_COR}"
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg &> /dev/null
echo -e "${VERDE}[INFO] - Copiando a chave gerada para o diretório de referência do GPG...${SEM_COR}"
echo -e "${VERDE}[INFO] - Teste nova linha de comentário...${SEM_COR}"
echo -e "${VERDE}[INFO] - Teste nova linha de comentário...${SEM_COR}"
echo -e "${VERDE}[INFO] - Teste nova linha de comentário...${SEM_COR}"
echo -e "${VERDE}[INFO] - Teste nova linha de comentário...${SEM_COR}"
sudo cp /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/ &> /dev/null
# ------------------------------------------------------------------------------ #
# Instala o tempo de execução de Conteiner (moby-engine)
echo -e "${VERDE}[INFO] - Atualizando a lista de pacotes nos repositórios da Microsoft...${SEM_COR}"
sudo apt-get update
echo -e "${VERDE}[INFO] - Instalando o tempo de execução da tecnologia de container Moby...${SEM_COR}"
sudo apt-get install moby-engine || echo -e "${VERMELHO}[ERRO] - Falha na instalação do moby-engine.${SEM_COR}" && exit
echo -e "${VERDE}[INFO] - Instalando a interface de linha de comando Moby (CLI)...${SEM_COR}" 
# essa interface é útil para o desenvolvimento, mas opcional para implantações de produção.
sudo apt-get install moby-cli || echo -e "${VERMELHO}[ERRO] - Falha na instalação do moby-cli.${SEM_COR}" && exit 
# ------------------------------------------------------------------------------ #
# Instala o Daemon de Segurança do Azure IoT Edge 
echo -e "${VERDE}[INFO] - Atualizando a lista de pacotes nos repositórios...${SEM_COR}"
sudo apt-get update
echo -e "${VERDE}[INFO] - Instalando o Azure IoT Edge Security Daemon...${SEM_COR}"
sudo apt-get install iotedge
# ------------------------------------------------------------------------------ #
# Configurando o Daemon de Segurança do Azure IoT Edge para modo Automático de provisionamento
# utilizando recurso DSP e atestado com chave simétrica)
echo -e "${VERDE}[INFO] - Atribuindo a chave de grupo do provisionamento simétrico...${SEM_COR}"
KEY="C0UfSJ/Ngpd+8MhvVuQsnaD0KJ04Hf99cLBJiDNSfq/EkRXJLqOWsDYQ3Qv/GvNBtLdRMteEaUjFyBxvtKbQKg=="
echo -e "${VERDE}[INFO] - Atribuindo o endereço MAC como ID de registro do dispositivo...${SEM_COR}"
REG_ID=$(sudo cat /sys/class/net/enp0s3/address)
echo -e "${VERDE}[INFO] - Derivando a chave do dispositivo (a partir da chave de grupo e ID de registro)...${SEM_COR}"
keybytes=$(echo $KEY | base64 --decode | xxd -p -u -c 1000)
SYM_KEY=$(echo -n $REG_ID | openssl sha256 -mac HMAC -macopt hexkey:$keybytes -binary | base64)
echo -e "${VERDE}[INFO] - Configurando o arquivo de configuração do Daemon...${SEM_COR}"
sudo nano /etc/iotedge/config.yaml
#echo -e "provisioning:
#  source: "dps"
#  global_endpoint: "https://global.azure-devices-provisioning.net"
#  scope_id: "0ne00101C66"
#  attestation:
#    method: "symmetric_key"
#    registration_id: $REG_ID
#    symmetric_key: $SYM_KEY"
# ------------------------------------------------------------------------------ #
# Verificando o sucesso da instalação
echo -e "${VERDE}[INFO] - Checando os status do IoT Edge Daemon...${SEM_COR}"
systemctl status iotedge
echo -e "${VERDE}[INFO] - Examinando os logs do Daemon...${SEM_COR}"
journalctl -u iotedge --no-pager --no-full
echo -e "${VERDE}[INFO] - Executando a ferramenta de solução de problemas para verificar os erros mais comuns de configuração e rede...${SEM_COR}"
sudo iotedge check
echo -e "${VERDE}[INFO] - Listando todos módulos...${SEM_COR}"
sudo iotedge list
