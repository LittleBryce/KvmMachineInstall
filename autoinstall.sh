#!/usr/bin/env bash
function installguestmount {
command -v guestmount
if [[ $? -ne 0 ]]; then
    yum install libguestfs libguestfs-tools -y
    if [[ $? -ne 0 ]]; then
        echo "fail to install guestmount!"
        exit 1
    fi
fi
}

function installbc {
command -v bc
if [[ $? -ne 0 ]];then
    yum -y install bc
    if [[ $? -ne 0 ]]; then
        echo "fail to install bc!"
        exit 1
    fi
fi
}

function installpip {
command -v pip
if [[ $? -ne 0 ]];then
    yum -y install epel-release && yum -y install python-pip
    if [[ $? -ne 0 ]]; then
        echo "fail to install pip!"
        exit 1
    fi
fi

}

function installshyaml {
command -v shyaml
if [[ $? -ne 0 ]];then
    pip install shyaml -i http://pypi.douban.com/simple --trusted-host pypi.douban.com
    if [[ $? -ne 0 ]]; then
        echo "fail to install shyaml!"
        exit 1
    fi
fi
}


function envinit {
installpip
installshyaml
installguestmount
installbc
}

envinit


WORKSPACE=$(cd `dirname $0`; pwd)

##################################################Owncloud Params###############################################################
OWNCLOUD_HTTP_PROTOCAL="http"
OWNCLOUD_HOST="172.16.1.97"
OWNCLOUD_API_PORT="8080"
OWNCLOUD_SERVICE_ADDRESS="${OWNCLOUD_HTTP_PROTOCAL}://${OWNCLOUD_HOST}:${OWNCLOUD_API_PORT}"
OWNCLOUD_FILE_API="${OWNCLOUD_HTTP_PROTOCAL}://${OWNCLOUD_HOST}:${OWNCLOUD_API_PORT}/remote.php/dav/files/transwarp"
OWNCLOUD_USERNAME="transwarp"
OWNCLOUD_PASSWORD="warp@123"
################################################################################################################################


############################################Check the Configuration File Exsit##################################################
CONF_FILE=$WORKSPACE/conf.yml
[ ! -f $CONF_FILE ] && echo "Check the Necessary Configuration File!" && exit 1
################################################################################################################################

###########################################Get the Configuration Params#########################################################
HOST_NUM=`cat $CONF_FILE | shyaml get-length nodes`
for i in `seq 1 $HOST_NUM`;do HOSTS_IP[`expr $i - 1`]=`cat $CONF_FILE | shyaml get-value nodes.node0$i.ip`; done
for i in `seq 1 $HOST_NUM`;do HOSTS_NETMASK[`expr $i - 1`]=`cat $CONF_FILE | shyaml get-value nodes.node0$i.netmask`; done
for i in `seq 1 $HOST_NUM`;do HOSTS_GATEWAY[`expr $i - 1`]=`cat $CONF_FILE | shyaml get-value nodes.node0$i.gateway`; done
for i in `seq 1 $HOST_NUM`;do HOSTS_HOSTNAME[`expr $i - 1`]=`cat $CONF_FILE | shyaml get-value nodes.node0$i.hostname`; done
for i in `seq 1 $HOST_NUM`;do HOSTS_OS[`expr $i - 1`]=`cat $CONF_FILE | shyaml get-value nodes.node0$i.os`; done
for i in `seq 1 $HOST_NUM`;do HOSTS_MEM[`expr $i - 1`]=`cat $CONF_FILE | shyaml get-value nodes.node0$i.memory`; done
for i in `seq 1 $HOST_NUM`;do HOSTS_CPU[`expr $i - 1`]=`cat $CONF_FILE | shyaml get-value nodes.node0$i.vcpu`; done
for i in `seq 1 $HOST_NUM`;do HOSTS_SNAPSHOT[`expr $i - 1`]=`cat $CONF_FILE | shyaml get-value nodes.node0$i.snapshot`; done
for i in `seq 1 $HOST_NUM`;do HOSTS_DISKPATH[`expr $i - 1`]=`cat $CONF_FILE | shyaml get-value nodes.node0$i.diskpath`; done
for i in `seq 1 $HOST_NUM`;do HOSTS_DISKLIST[`expr $i - 1`]=`cat $CONF_FILE | shyaml keys nodes.node0${i}.datadisks`;done
for i in `seq 1 $HOST_NUM`;do HOSTS_CAPACITYLIST[`expr $i - 1`]=`cat $CONF_FILE | shyaml values nodes.node0${i}.datadisks`;done
################################################################################################################################

for((i=1;i<=HOST_NUM;i++));
do
HOST_DISK_NUM=`cat $CONF_FILE | shyaml get-length nodes.node0${i}.datadisks`
HOST_IP=${HOSTS_IP[`expr $i - 1`]}
HOST_NETMASK=${HOSTS_NETMASK[`expr $i - 1`]}
HOST_GATEWAY=${HOSTS_GATEWAY[`expr $i - 1`]}
HOST_HOSTNAME=${HOSTS_HOSTNAME[`expr $i - 1`]}
HOST_OS=${HOSTS_OS[`expr $i - 1`]}
HOST_MEM=${HOSTS_MEM[`expr $i - 1`]}
HOST_CPU=${HOSTS_CPU[`expr $i - 1`]}
HOST_SNAPSHOT=${HOSTS_SNAPSHOT[`expr $i - 1`]}
HOST_DISKPATH=${HOSTS_DISKPATH[`expr $i - 1`]}
HOST_DISKLIST=${HOSTS_DISKLIST[`expr $i - 1`]}
HOST_DISKARR=(${HOST_DISKLIST// /})
HOST_CAPACITYLIST=${HOSTS_CAPACITYLIST[`expr $i - 1`]}
HOST_CAPACITYARR=(${HOST_CAPACITYLIST// /})
VM_NAME=${HOST_OS}_${HOST_IP//./_}
HOST_TOTAL_SPACE=0
for((m=0;m<${#HOST_CAPACITYARR[*]};m++))
do
HOST_TOTAL_SPACE=`echo "$HOST_TOTAL_SPACE + ${HOST_CAPACITYARR[$m]%G}"|bc`
done


:<<!
STEP 1
Select One Available Data Disk=======>DISKPATH
!
if [[ -z "$HOST_DISKPATH" ]];then
    MOUNTPOINT=`df -h|cat -n|awk -F ' ' '{print $7}'`
    declare -A dic
    index=0
    for line in ${MOUNTPOINT}
    do
      let index++
      if [[ "$line" =~ "/mnt/disk" ]];then
          printrow=${index}"p"
          avail_volume=`df -h | sed -n ${printrow}|awk -F ' ' '{print $4}'`
          if [[ "$avail_volume" =~ "T" ]];then
              avail_volume_value=`echo ${avail_volume%T}`
              dic[$line]=`echo "${avail_volume_value} * 1000" | bc `
          else
              avail_volume_value=`echo ${avail_volume%G}`
              dic[$line]=${avail_volume_value}
          fi
      fi
    done
    for key in $(echo ${!dic[*]})
    do
      value=${dic[$key]}
      if [[ ${value%.*} -gt $HOST_TOTAL_SPACE ]];then
          HOST_DISKPATH=${key}
          break
      else
          echo "NO ENOUGH SPACE!!"
          exit 1
      fi
    done
fi

:<<!
STEP 2
Check Image Path
!
[[ ! -d $HOST_DISKPATH/image ]] && mkdir -p $HOST_DISKPATH/image

:<<!
STEP 3
Download OS Model File & Create Data Disks
!
if [[ ! -f /root/${HOST_OS}_model.qcow2 ]];then
   curl -u ${OWNCLOUD_USERNAME}:${OWNCLOUD_PASSWORD} ${OWNCLOUD_FILE_API}/TEMPLATE/${HOST_OS}/${HOST_OS}_model.qcow2 --output /root/${HOST_OS}_model.qcow2
   cp /root/${HOST_OS}_model.qcow2  ${HOST_DISKPATH}/image/${VM_NAME}.qcow2
else
   cp /root/${HOST_OS}_model.qcow2  ${HOST_DISKPATH}/image/${VM_NAME}.qcow2
fi

for((n=1;n<=${HOST_DISK_NUM};n++))
do
qemu-img  create -f qcow2 ${HOST_DISKPATH}/image/${VM_NAME}_100g_${n}.qcow2 ${HOST_CAPACITYARR[`expr $n - 1`]} || exit 1
source_file[`expr $n - 1`]=`echo ${HOST_DISKPATH}/image/${VM_NAME}_100g_${n}.qcow2`
done

:<<!
STEP 4
Create VM Host
!
virt-install --name ${VM_NAME} --ram ${HOST_MEM} --vcpu ${HOST_CPU} --os-variant Generic --disk path=${HOST_DISKPATH}/image/${VM_NAME}.qcow2,bus=virtio --vnc --network bridge=br0,model=virtio --wait=0 --boot hd || exit 1
if [[ ! -d /media/virtimage ]];then
    mkdir -p /media/virtimage
else
    rm -rf /media/virtimage && mkdir -p /media/virtimage
fi
sleep 30s && virsh destroy ${VM_NAME} || exit 1

case ${HOST_OS} in
    "centos72")
               guestmount -d ${VM_NAME} -m /dev/sda3 --rw /media/virtimage || exit 1
               echo "${HOST_HOSTNAME}" > /media/virtimage/etc/hostname || exit 1
               ;;
    "centos76")
               guestmount -d ${VM_NAME} -m /dev/centos/root --rw /media/virtimage || exit 1
               echo "${HOST_HOSTNAME}" > /media/virtimage/etc/hostname || exit 1
               ;;
    "centos74" | "centos77")
               guestmount -d ${VM_NAME} -m /dev/sda3 --rw /media/virtimage || exit 1
               echo "${HOST_HOSTNAME}" > /media/virtimage/etc/hostname || exit 1
               ;;
    "centos67")
               guestmount -d ${VM_NAME} -m /dev/mapper/VolGroup-lv_root --rw /media/virtimage || exit 1
               eval sed -i 's/localhost.localdomain/${HOST_HOSTNAME}/g' /media/virtimage/etc/sysconfig/network || exit 1
               ;;
    *)
               echo "Not Support OS" && exit 1
               ;;
esac

cat > /media/virtimage/etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
TYPE=Ethernet
BOOTPROTO=static
DEFROUTE=yes
PEERDNS=yes
PEERROUTES=yes
NAME=eth0
DEVICE=eth0
ONBOOT=yes
IPADDR=${HOST_IP}
GATEWAY=${HOST_GATEWAY}
NETMASK=${HOST_NETMASK}
EOF
sleep 5s
umount /media/virtimage && rm -rf /media/virtimage || exit 1

VM_XML_PATH=/etc/libvirt/qemu
DiskRow=`cat -n ${VM_XML_PATH}/${VM_NAME}.xml|grep "</disk>"|awk -F ' ' '{print $1}'`
InsertRow=`expr ${DiskRow} + 1`
[[ -f ${WORKSPACE}/tmp.txt ]] && rm -rf ${WORKSPACE}/tmp.txt

for((k=0;k<${HOST_DISK_NUM};k++))
do
i_tmp=`expr ${k} + 16`
slot=`echo "obase=16;${i_tmp}"|bc|tr '[A-Z]' '[a-z]'`
cat >> ${WORKSPACE}/tmp.txt << EOF
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='${source_file[$k]}'/>
      <target dev='${HOST_DISKARR[$k]}' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x`echo ${slot}`' function='0x0'/>
    </disk>
EOF
done


cat ${WORKSPACE}/tmp.txt | while read line
do
echo ${line} | sed -i "${InsertRow}i\\${line}" ${VM_XML_PATH}/${VM_NAME}.xml
InsertRow=$((${InsertRow} + 1))
done
virsh define ${VM_XML_PATH}/${VM_NAME}.xml
virsh start ${VM_NAME}
sleep 30
:<<!
STEP 5
Create VM Snapshot
!
if [[ -n ${HOST_SNAPSHOT} ]];then
    virsh snapshot-create-as ${VM_NAME} ${HOST_SNAPSHOT} || exit 1
fi
done
