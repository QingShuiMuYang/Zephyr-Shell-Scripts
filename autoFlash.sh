# 一键刷包脚本

# 截取文件名字符段获取版本名
function get_Version(){
    local packV
    packV=${1##*_}
    packV=${packV%%.tar*}
    echo "$packV"
}

SOC=$(ls |grep xpilot*.gz)
MCU=$(ls |grep Xpilot*.zip)
ipcTool=$(ls |grep ipc_tools*.gz)

packVersion=get_Version $SOC
if [ -e $SOC -a $MCU -a $ipcTool ]; then
    :
else
    echo "刷包文件准备不全，请将刷包文件存放在当前文件夹中"
fi

echo ----删除旧包----
sudo rm -rf soc mcu ipcTools
mkdir soc mcu ipcTools

echo "解压$SOC "
tar -xvf xpilot*.gz -C ./soc

echo "解压$ipcTool "
tar -xvf ipc_tools*.gz -C ./ipcTools

echo "解压$MCU "
unzip -d ./mcu XPilot*.zip

echo "开始刷写SOC..."
cd soc
echo "刷写orin_a"
./deploy_xpilot.sh orin_a
echo "刷写orin_b"
./deploy_xpilot.sh orin_b

fileName=$(ls $HOME/autoFlash/mcu/XPF)
cp /home/$USER/autoFlash/mcu/XPF/$fileName/*APPA.hex ../aurix
cp /home/$USER/autoFlash/mcu/XPF/$fileName/*APPB.hex ../aurix

echo "开始刷写MCU..."
cd ../aurix
echo "刷写Master MCU"
./aurix_v7.sh
echo "刷写Slave MCU"
./aurix_v7.sh S

rm *.hex
rm -rf ~/aeb_xviz ~/ap_xviz ~/hil_dds_forwarder ~/hil_xdds_replayer ~/idlPlugins ~/ipc_timesync ~/xdds_tools/release ~/xviz
cd ..
cp -r ./ipcTools/* ~/

rm $SOC $MCU $ipcTool
echo "刷写完成"

echo "检查版本"

orinA_socI=$(sshpass -p "nvidia" ssh -tt nvidia@172.20.1.22 'cat /xpilot/version.txt')
orinB_socI=$(sshpass -p "nvidia" ssh -tt nvidia@172.20.1.30 'cat /xpilot/version.txt')
bspInfoA=$(sshpass -p "nvidia" ssh -tt nvidia@172.20.1.22 'cat /etc/version')
bspInfoB=$(sshpass -p "nvidia" ssh -tt nvidia@172.20.1.30 'cat /etc/version')
orinA_mcuI=$(sshpass -p "nvidia" ssh -tt nvidia@172.20.1.22 '/xpilot/aurix_utility/aurix_utility -v')
orinB_mcuI=$(sshpass -p "nvidia" ssh -tt nvidia@172.20.1.22 '/xpilot/aurix_utility/aurix_utility -v --m=1')
orinA_Vehicle=$(echo "$orinA_socI" | grep "Vehicle_model")
orinB_Vehicle=$(echo "$orinB_socI" | grep "Vehicle_model")

orinA_socV=$(echo "$orinA_socI" | grep "Version")
orinA_socV=${orinA_socV#*v}
orinA_socV=${orinA_socV%-*}

orinB_socV=$(echo "$orinB_socI" | grep "Version")
orinB_socV=${orinB_socV#*v}
orinB_socV=${orinB_socV%-*}
orinA_mcuV=$(echo "$orinA_mcuI" | grep "Aurix rc version")
orinB_mcuV=$(echo "$orinB_mcuI" | grep "Aurix rc version")
echo $orinA_socV
echo $orinB_socV
echo $(get_Version "$SOC")

if [ "$orinA_socV" = "$orinB_socV" ]; then
    echo "orin_a的SOC版本为：$orinA_socV"
    echo "orin_b的SOC版本为：$orinB_socV"
    if [ $(get_Version "$SOC") = "$orinA_socV" ]; then
        echo "SOC刷写正确"
    else
        echo "SOC版本与目标版本不一致,刷写失败,请重刷"
    fi
else
    echo "orin_a和orin_b的SOC版本不一致，请重刷"
fi


