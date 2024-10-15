# 一键刷包脚本

# 截取文件名字符段获取版本名
function get_tarVersion(){
    local tarSocV
    local tarMcuV
    if [ $1 = "soc" ]; then
        tarSocV=${2##*_}
        tarSocV=${tarSocV%%.tar*}
        echo "$tarSocV"
    else
        tarMcuVtmp=${2%%-*}
        tarMcuV=$tarMcuVtmp"-"${2##*-}
        echo "$tarMcuV"
    fi
}

function filt_McuVersion(){
    local rc
    rc=${1#*:}
    array=(${rc//./ })
    for num in ${array[@]}
    do
        if [ $num == 0 ]; then
            :
        else
            rc=""$num
        fi
    done
    rc="rc"$rc
    echo $rc
}

SOC=$(ls |grep xpilot*.gz)
MCU=$(ls |grep Xpilot*.zip)
ipcTool=$(ls |grep ipc_tools*.gz)

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

echo "获取版本信息"
orinA_socI=$(sshpass -p "nvidia" ssh -tt nvidia@172.20.1.22 'cat /xpilot/version.txt')
orinB_socI=$(sshpass -p "nvidia" ssh -tt nvidia@172.20.1.30 'cat /xpilot/version.txt')
bspInfoA=$(sshpass -p "nvidia" ssh -tt nvidia@172.20.1.22 'cat /etc/version')
bspInfoB=$(sshpass -p "nvidia" ssh -tt nvidia@172.20.1.30 'cat /etc/version')
orinA_mcuI=$(sshpass -p "nvidia" ssh -tt nvidia@172.20.1.22 '/xpilot/aurix_utility/aurix_utility -v')
orinB_mcuI=$(sshpass -p "nvidia" ssh -tt nvidia@172.20.1.22 '/xpilot/aurix_utility/aurix_utility -v --m=1')
orinA_Vehicle=$(echo "$orinA_socI" | grep "Vehicle_model")
orinB_Vehicle=$(echo "$orinB_socI" | grep "Vehicle_model")

echo "过滤SOC版本信息"
orinA_socV=$(echo "$orinA_socI" | grep "Version")
orinA_socV=${orinA_socV#*v}
orinA_socV=${orinA_socV%-*}
orinB_socV=$(echo "$orinB_socI" | grep "Version")
orinB_socV=${orinB_socV#*v}
orinB_socV=${orinB_socV%-*}

echo "过滤MCU版本信息"
orinA_sw=$(echo "$orinA_mcuI" | grep "Aurix sw version")
orinA_sw=${orinA_sw#*:}
orinA_sw=$(echo "$orinA_sw" | tr -d '\r')
orinA_rc=$(echo "$orinA_mcuI" | grep "Aurix rc version")
orinA_rc=$(filt_McuVersion "$orinA_rc")
orinA_rc=$(echo "$orinA_rc" | tr -d '\r')
orinA_mcuV="$orinA_sw-$orinA_rc"

orinB_sw=$(echo "$orinB_mcuI" | grep "Aurix sw version")
orinB_sw=${orinB_sw#*:}
orinB_sw=$(echo "$orinB_sw" | tr -d '\r')
orinB_rc=$(echo "$orinB_mcuI" | grep "Aurix rc version")
orinB_rc=$(filt_McuVersion "$orinB_rc")
orinB_rc=$(echo "$orinB_rc" | tr -d '\r')
orinB_mcuV="$orinB_sw-$orinB_rc"

echo "--------------------------------------------------"

if [ "$orinA_socV" = "$orinB_socV" ]; then
    echo "orin_a的SOC版本为：$orinA_socV"
    echo "orin_b的SOC版本为：$orinB_socV"
    tarSocV=$(get_tarVersion soc "$SOC")
    if [ "$tarSocV" = "$orinA_socV" ]; then
        echo "SOC版本与目标版本一致"
    else
        echo "目标SOC版本为：$tarMcuV"
        echo "SOC版本与目标版本不一致,刷写失败,请重刷"
    fi
else
    echo "orin_a和orin_b的SOC版本不一致，请重刷"
fi

echo "--------------------------------------------------"

if [ orinA_mcuV=orinB_mcuV ]; then
    echo "orin_a的MCU版本为：$orinA_mcuV"
    echo "orin_b的MCU版本为：$orinB_mcuV"
    tarMcuV=$(get_tarVersion mcu "$tarSocV")
    if [ "$tarMcuV" = "$orinA_mcuV" ]; then
        echo "MCU版本与目标版本一致"
    else
        echo "目标MCU版本为：$tarMcuV"
        echo "MCU版本与目标版本不一致，刷写失败，请重刷"
    fi
else
    echo "orin_a和orin_b的MCU版本不一致，请重刷"
fi



