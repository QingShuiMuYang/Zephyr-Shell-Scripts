# 一键刷包脚本
# code by zehan
set -x
SOC=$(ls |grep xpilot*.gz)
MCU=$(ls |grep XPilot*.zip)
ipcTool=$(ls |grep ipc_tools*.gz)
xpuAddress="nvidia@172.20.1.22"
xpusAddress="nvidia@172.20.1.30"
function check_file(){
    if [ "$1" = "x" ]; then
            if [ "$SOC" != "" -a "$MCU" != "" ]; then
                echo "XLIDC文件准备齐全"
            else
                echo "XLIDC刷包文件准备不全，请将刷包文件存放在当前文件夹中"
                exit
            fi
        else
            if [ "$SOC" != "" -a "$MCU" != "" -a "$ipcTool" != "" ]; then
                echo "IPC文件准备齐全"
            else
                echo "IPC刷包文件准备不全，请将刷包文件存放在当前文件夹中"
                exit
            fi
        fi
}

# 截取文件名字符段获取目标版本名
function get_tarVersion(){
    local tarSocV
    local tarMcuV
    local tarVehM
    case $1 in
        "soc")
            tarSocV=${2##*_}
            tarSocV=${tarSocV%%.tar*}
            echo "$tarSocV"
            ;;
        "mcu")
            tarMcuVtmp=${2%%-*}
            tarMcuV="$tarMcuVtmp-${2##*-}"
            if [[ "$tarMcuV" = *"rc"* ]]; then
                :
            else
                tarMcuV="${tarMcuV%-*}-release"
            fi
            echo "$tarMcuV"
            ;;
        "veh")
            tarVehM=${SOC#*-}
            tarVehM=${tarVehM%%-*}
            tarVehM=$(echo "$tarVehM" | tr a-z A-Z)
            echo "$tarVehM"
            ;;
    esac
}

# 处理获取到的MCU版本
function filt_mcuVersion(){
    local rc
    rc=${1#*:}
    rc=$(echo "$rc" | tr -d "\r")
    array=(${rc//./ })
    for num in ${array[@]}
    do
        if [ $num == 0 ]; then
            :
        else
            rc=""$num
        fi
    done
    if [ ${#rc} -le 3 ]; then  
        rc="rc"$rc
    else
        rc="release"
    fi
    echo $rc
}

# 获取SOC版本
function get_socVersion(){
    socV=$(sshpass -p "nvidia" ssh -tt -o StrictHostKeyChecking=no $1 "cat /xpilot/version.txt")
    socV=$(echo "$socV" | grep "Version")
    socV=${socV#*v}
    socV=${socV%-*}
    echo $socV
}

# 获取MCU版本
function get_mcuVersion(){
    local mcuI
    local mcuV
    if [ $1 = "a" ]; then
        mcuI=$(sshpass -p "nvidia" ssh -tt -o StrictHostKeyChecking=no $2 "/xpilot/aurix_utility/aurix_utility -v")
    else
        mcuI=$(sshpass -p "nvidia" ssh -tt -o StrictHostKeyChecking=no $1 "/xpilot/aurix_utility/aurix_utility -v --m=1")
    fi
    sw=$(echo "$mcuI" | grep "Aurix sw version")
    sw=${sw#*:}
    sw=$(echo "$sw" | tr -d '\r')
    rc=$(echo "$mcuI" | grep "Aurix rc version")
    rc=$(filt_mcuVersion "$rc")
    mcuV="$sw-$rc"
    echo "$mcuV"
}

# 获取车型编号
function get_vehicleModel(){
    local socI
    local vehiM
    socI=$(sshpass -p "nvidia" ssh -tt -o StrictHostKeyChecking=no $1 "cat /xpilot/version.txt")
    vehiM=$(echo "$socI" | grep "Vehicle_model")
    vehiM=${vehiM#*:}
    vehiM=$(echo "$vehiM" | tr -d "\r")
    vehiM=$(echo "$vehiM" | tr -d " ")
    echo "$vehiM"
}

function flash_Software(){
    local soc_CountA
    local soc_CountB
    local mcu_CountA
    local mcu_CountB
    local soc_FlashStatus
    local mcu_FlashStatus

    case $1 in
        "socA")
            soc_CountA=0
            cd $HOME/autoFlash/soc
            while [ $soc_CountA -lt 2 ]; do
                ./deploy_xpilot.sh orin_a
                soc_FlashStatus=$(grep -c "Reset XPU apps Done" $HOME/autoFlash/soc/deploy_log.txt)
                if [ $soc_FlashStatus -ne 0 ]; then
                    echo -e "\033[1;44m刷写A区SOC成功\033[0m"
                    break
                else
                    echo -e "\033[1;30;43m刷写A区SOC失败，即将重刷\033[0m"
                    soc_CountA=$((soc_CountA+1))
                    if [ soc_CountA -eq 2 ]; then
                        echo -e "\033[1;41m刷写两次A区SOC失败，请检查\033[0m"
                        exit
                    fi
                fi
            done
            ;;
        "socB")
            soc_CountB=0
            cd $HOME/autoFlash/soc
            while [ $soc_CountB -lt 2 ]; do
                ./deploy_xpilot.sh orin_b
                soc_FlashStatus=$(grep -c "Reset XPU apps Done" $HOME/autoFlash/soc/deploy_log.txt)
                if [ $soc_FlashStatus -ne 0 ]; then
                    echo -e "\033[1;44m刷写B区SOC成功\033[0m"
                    break
                else
                    echo -e "\033[1;30;43m刷写B区SOC失败，即将重刷\033[0m"
                    soc_CountB=$((soc_CountB+1))
                    if [ soc_CountB -eq 2 ]; then
                        echo -e "\033[1;41m刷写两次B区SOC失败，请检查\033[0m"
                        exit
                    fi
                fi
            done
            ;;
        "mcuA")
            if [ -e ./flashMCUa.log ]; then
                rm ./flashMCUa.log
            fi
            mcu_CountA=0
            while [ $mcu_CountA -lt 2 ]; do
                cd $HOME/autoFlash
                echo "开始刷写mcuA..."
                echo "$(pwd)"
                ./aurix_v7.sh | tee ./flashMCUa.log
                mcu_FlashStatus=$(grep -c "Both partition flashed successfully!" ./flashMCUa.log)
                if [ $mcu_FlashStatus -ne 0 ]; then
                    echo -e "\033[1;44m刷写A区MCU成功\033[0m"
                    rm ./flashMCUa.log
                    break
                else
                    echo -e "\033[1;30;43m刷写A区MCU失败，即将重刷\033[0m"
                    mcu_CountA=$((mcu_CountA+1))
                    if [ $mcu_CountA -eq 2 ]; then
                        echo -e "\033[1;41m刷写两次A区MCU失败，请检查\033[0m"
                        rm $HOME/autoFlash/*APPA.hex
                        rm $HOME/autoFlash/*APPB.hex
                        exit
                    fi
                fi
            done
            ;;
        "mcuB")
            if [ -e ./flashMCUb.log ]; then
                rm ./flashMCUb.log
            fi
            mcu_CountB=0
            while [ $mcu_CountB -lt 2 ]; do
                cd $HOME/autoFlash
                echo "开始刷写mcuB..."
                echo "$(pwd)"
                ./aurix_v7.sh S | tee ./flashMCUb.log
                mcu_FlashStatus=$(grep -c "Both partition flashed successfully!" ./flashMCUb.log)
                if [ $mcu_FlashStatus -ne 0 ]; then
                    echo -e "\033[1;44m刷写B区MCU成功\033[0m"
                    rm $HOME/autoFlash/*APPA.hex
                    rm $HOME/autoFlash/*APPB.hex
                    rm ./flashMCUb.log
                    rm ./curr_aurix_zone
                    break
                else
                    echo -e "\033[1;30;43m刷写B区MCU失败，即将重刷\033[0m"
                    mcu_CountB=$((mcu_CountB+1))
                    if [ $mcu_CountB -eq 2 ]; then
                        echo -e "\033[1;41m刷写两次B区MCU失败，请检查\033[0m"
                        rm $HOME/autoFlash/*APPA.hex
                        rm $HOME/autoFlash/*APPB.hex
                        exit
                    fi
                fi
            done
            ;;
    esac
}

check_file

echo "删除旧包..."
sudo rm -rf $HOME/autoFlash/soc $HOME/autoFlash/mcu $HOME/autoFlash/ipcTools
mkdir $HOME/autoFlash/soc $HOME/autoFlash/mcu $HOME/autoFlash/ipcTools

echo "解压$SOC..."
tar -xvf $SOC -C $HOME/autoFlash/soc

echo "解压$ipcTool..."
tar -xvf $ipcTool -C $HOME/autoFlash/ipcTools

echo "解压$MCU..."
unzip -d $HOME/autoFlash/mcu $MCU

fileTmp=$(ls $HOME/autoFlash/mcu/XPF)
cp $HOME/autoFlash/mcu/XPF/$fileTmp/*APPA.hex $HOME/autoFlash
cp $HOME/autoFlash/mcu/XPF/$fileTmp/*APPB.hex $HOME/autoFlash

if [ "$1" != "x" ]; then
    rm -rf $HOME/aeb_xviz $HOME/ap_xviz $HOME/hil_dds_forwarder $HOME/hil_xdds_replayer $HOME/idlPlugins $HOME/ipc_timesync $HOME/xdds_tools/release $HOME/xviz
    cp -r $HOME/autoFlash/ipcTools/* $HOME/
fi


#获取历史版本
pre_orinA_socV=$(get_socVersion $xpuAddress)
pre_orinB_socV=$(get_socVersion $xpusAddress)
pre_orinA_mcuV=$(get_mcuVersion a $xpuAddress)
pre_orinB_mcuV=$(get_mcuVersion $xpuAddress)
vehModel=$(get_vehicleModel $xpuAddress)    #历史车型
tarVehM=$(get_tarVersion veh)               #当前包中车型


if [ "$tarVehM" != "$vehModel" ]; then
    echo -e "\033[1;41m目标车型与历史车型不一致，请检查包是否下载错误，是否继续？(yes/no)\033[0m"
    read -r response
    case "$response" in
        "yes")
            flash_Software socA
            flash_Software socB
            flash_Software mcuA
            flash_Software mcuB
            echo -e "\033[1;44mSOC及MCU刷写完成\033[0m"
            ;;
        "no")
            exit 1
            ;;
    esac
else
    flash_Software socA
    flash_Software socB
    flash_Software mcuA
    flash_Software mcuB
    echo -e "\033[1;44mSOC及MCU刷写完成\033[0m"
fi

echo "检查版本..."

orinA_socV=$(get_socVersion $xpuAddress)
orinB_socV=$(get_socVersion $xpusAddress)
orinA_mcuV=$(get_mcuVersion a $xpuAddress)
orinB_mcuV=$(get_mcuVersion $xpuAddress)

echo "-------------------------------------------------------"
echo "-------------------------------------------------------"

echo "orin_a的历史SOC版本：$pre_orinA_socV"
echo "orin_b的历史SOC版本：$pre_orinB_socV"

echo "-------------------------------------------------------"
if [ "$orinA_socV" = "$orinB_socV" ]; then
    echo "orin_a的当前SOC版本为：$orinA_socV"
    echo "orin_b的当前SOC版本为：$orinB_socV"
    tarSocV=$(get_tarVersion soc "$SOC")
    if [ "$tarSocV" = "$orinA_socV" ]; then
        echo "SOC版本与目标版本一致"
    else
        echo "目标SOC版本为：$tarSocV"
        echo "orin_a的当前SOC版本为：$orinA_socV"
        echo "orin_b的当前SOC版本为：$orinB_socV"
        echo -e "\033[1;41mSOC版本与目标版本不一致,刷写失败,请重刷\033[0m"
    fi
else
    echo "orin_a的当前SOC版本为：$orinA_socV"
    echo "orin_b的当前SOC版本为：$orinB_socV"
    echo -e "\033[1;41morin_a和orin_b的SOC版本不一致，请重刷\033[0m"
fi

echo "-------------------------------------------------------"
echo "-------------------------------------------------------"

echo "orin_a的历史MCU版本：$pre_orinA_mcuV"
echo "orin_b的历史MCU版本：$pre_orinB_mcuV"
echo "-------------------------------------------------------"
if [ "$orinA_mcuV" = "$orinB_mcuV" ]; then
    echo "orin_a的当前MCU版本为：$orinA_mcuV"
    echo "orin_b的当前MCU版本为：$orinB_mcuV"
    tarMcuV=$(get_tarVersion mcu "$tarSocV")
    if [ "$tarMcuV" = "$orinA_mcuV" ]; then
        echo "MCU版本与目标版本一致"
        rm $HOME/autoFlash/$SOC $HOME/autoFlash/$MCU $HOME/autoFlash/$ipcTool
    else
        echo "目标MCU版本为：$tarMcuV"
        echo "orin_a的当前MCU版本为：$orinA_mcuV"
        echo "orin_b的当前MCU版本为：$orinB_mcuV"
        echo -e "\033[1;41mMCU版本与目标版本不一致，刷写失败，请重刷\033[0m"
    fi
else
    echo "orin_a的当前MCU版本为：$orinA_mcuV"
    echo "orin_b的当前MCU版本为：$orinB_mcuV"
    echo -e "\033[1;41morin_a和orin_b的MCU版本不一致，请重刷\033[0m"
fi
echo "-------------------------------------------------------"



