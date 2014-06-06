#!/bin/bash

function launch_vm(){
   IMAGE_NAME=ubuntubase
   TEST_INSTANCE_NAME=$1
   KEY_NAME=bm_test_key
   LOCAL_IMAGE=ubuntuJDK.qcow2
   PUB_KEY_FOR_VM=$2
   FLAVOR=$3
   BASE=/root/
   
   CUR_DIR=$(cd "$(dirname "$0")"; pwd)

   img_list=$(glance image-list)
   if ! echo $img_list | grep $IMAGE_NAME ; then
        glance image-create --name=$IMAGE_NAME --disk-format=qcow2 --container-format=bare --is-public=true --file=$CUR_DIR/$LOCAL_IMAGE
   fi
   key_list=$(nova keypair-list)
   if ! echo $key_list | grep $KEY_NAME ; then
        nova keypair-add --pub-key $PUB_KEY_FOR_VM $KEY_NAME
   fi

   nova boot $TEST_INSTANCE_NAME --image $IMAGE_NAME --flavor $FLAVOR --key-name=$KEY_NAME
}

function wait_system_ready(){
    wait_count=0
    WAIT_MAX=$2
    set +e
    
    CUR_DIR=$(cd "$(dirname "$0")"; pwd)
    while (( $wait_count < $WAIT_MAX ))
    do
        ssh -o StrictHostKeyChecking=no -i $CUR_DIR/id_rsa root@$1 "exit"
        if (( $? == 0 )); then echo "$1 OS is ready";break;fi
        sleep $3
        ((wait_count++))        
   done
   if (( wait_count < $WAIT_MAX )); then
        echo "$1 OS installation done"
        return 0
   else
        return 1
   fi
}

function wait_all(){
    set $1
    for server in "$@"
    do
    	wait_system_ready $server 15 10
    	[[ $? != 0 ]] && echo "$server isn't up in reasonable time"
    done
}


if [[ $# != 2 && $# != 3 ]]; then
	echo "Usage: $0 [number_of_cluster_nodes] [base_hostname_for_nodes] [size(optional, default=small)(small,medium,large,xlarge)]"
	cat << EOF
         RAM(MB)  Disk(GB) VCPU    
small  | 2048      | 20   | 2
medium | 4096      | 40   | 2
large  | 8192      | 80   | 4
xlarge | 8192      | 120  | 4
EOF
	exit 1
fi

num=$1

echo "$num"|grep -E '[0-9]+' > /dev/null
[[ $? != 0 ]] && echo "Please specify a number for the first parameter!" && exit 1

flavor=${3:-small}
[[ $flavor != small && $flavor != medium && $flavor != large && $flavor != xlarge ]] && echo "Size parameter must be one of (small,medium,large,xlarge)" && exit 1

flavor=spark."$flavor"
master_name=$(echo "$2"master| tr '[:upper:]' '[:lower:]')
slave_name=$(echo "$2"slave| tr '[:upper:]' '[:lower:]')

CUR_DIR=$(cd "$(dirname "$0")"; pwd)
PDIR=`basename $CUR_DIR`
source $CUR_DIR/keystonerc 
nova list > /dev/null
[[ $? != 0 ]] && echo "OpenStack credentials ($CUR_DIR/keystonerc) are not correct or OpenStack installation is not working! " && exit 1

startt=`date`
nova show $master_name 2>&1 >/dev/null
[[ $? == 0 ]] && echo "VM with the same name exists. Please specify another name" && exit 1

nova show $slave_name 2>&1 >/dev/null
[[ $? == 0 ]] && echo "VM with the same name exists. Please specify another name" && exit 1


chmod 600 $CUR_DIR/id_rsa.pub
chmod 600 $CUR_DIR/id_rsa

launch_vm $master_name $CUR_DIR/id_rsa.pub $flavor

count=1
while (( $num > $count ))
do
    vmname="$slave_name""$count"
	launch_vm $vmname $CUR_DIR/id_rsa.pub $flavor
	let count+=1
done

echo "sleeping for 1 min..."
sleep 60
master_ip=`nova list|grep $master_name|cut -d '|' -f 7|cut -d '=' -f 2|sed 's/\s*//g'`
if [[ $num > 1 ]]; then
   slave_ips=`nova list|grep $slave_name|cut -d '|' -f 7|cut -d '=' -f 2|sed 's/\s*//g'`
   [[ -z $slave_ips ]] && echo "Slave VM launching failed...exiting..." && exit 1
fi
[[ -z $master_ip ]] && echo "Master VM launching failed...exiting..." && exit 1

wait_all $master_ip
wait_all `echo $slave_ips`

echo "VM launched successfully..."
echo "Master IP: $master_ip"
echo "Slave IP(s): $slave_ips"

rm -rf /root/.ssh/known_hosts

	scp -r -o StrictHostKeyChecking=no -i $CUR_DIR/id_rsa $CUR_DIR $master_ip:/root/
	ssh -o StrictHostKeyChecking=no -i $CUR_DIR/id_rsa $master_ip "/root/$PDIR/local-hadoop24-setup.sh master $master_name $num"
	ssh -o StrictHostKeyChecking=no -i $CUR_DIR/id_rsa $master_ip "/root/$PDIR/spark1.0-setup.sh"
        sleep 20

        if [[ $num > 1 ]]; then
	set $slave_ips
	for slave in $*
	do
	    scp -r -o StrictHostKeyChecking=no -i $CUR_DIR/id_rsa $CUR_DIR $slave:/root/
	    ssh -o StrictHostKeyChecking=no -i $CUR_DIR/id_rsa $slave "/root/$PDIR/local-hadoop24-setup.sh slave $master_name"
	    ssh -o StrictHostKeyChecking=no -i $CUR_DIR/id_rsa $slave "/root/$PDIR/spark1.0-setup.sh $master_name"
	done
        fi


echo "VM launched successfully..."
echo "Master IP: $master_ip"
echo "Slave IP(s): $slave_ips"
echo "Starting time: $startt"
echo "Finish time: `date`"
