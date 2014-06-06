#!/bin/bash

[[ $# != 2 && $# != 3 ]] && echo "Usage: $0 [master/slave] [master_name/slave_name] [num_cluster_node]" && exit 1
master=$2
num=$3
let len=${#master}-6
base_host_name=`expr substr $master 1 $len`

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

#yum --disablerepo=rhel-x86_64-server-6.3.z repolist

#yum --disablerepo=rhel-x86_64-server-6.3.z -y install java-1.7.0-openjdk-devel
#yum --disablerepo=rhel-x86_64-server-6.3.z -y install git
#apt-get -y install git

tar zxvf $BASE_DIR/hadoop-2.4.0.tar.gz -C /usr/local/ > /dev/null
cat >> ~/.bashrc <<EOF
export HADOOP_PREFIX=/usr/local/hadoop-2.4.0
export HADOOP_HOME=\$HADOOP_PREFIX
export HADOOP_COMMON_HOME=\$HADOOP_PREFIX
export HADOOP_CONF_DIR=\$HADOOP_PREFIX/etc/hadoop
export HADOOP_HDFS_HOME=\$HADOOP_PREFIX
export HADOOP_MAPRED_HOME=\$HADOOP_PREFIX
export HADOOP_YARN_HOME=\$HADOOP_PREFIX
export PATH=\$HADOOP_PREFIX/bin:\$PATH
export JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk-amd64
export NAMENODE=$master
EOF
source ~/.bashrc

cat > ~/hdfs-master <<EOF
<property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///usr/local/hadoop-2.4.0/hdfs/datanode</value>
    <description>Comma separated list of paths on the local filesystem of a DataNode where it should store its blocks.</description>
  </property>
 
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:///usr/local/hadoop-2.4.0/hdfs/namenode</value>
    <description>Path on the local filesystem where the NameNode stores the namespace and transaction logs persistently.</description>
  </property>
EOF

cat > ~/hdfs <<EOF
<property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///usr/local/hadoop-2.4.0/hdfs/datanode</value>
    <description>Comma separated list of paths on the local filesystem of a DataNode where it should store its blocks.</description>
  </property>
EOF

cat > ~/core <<EOF
<property>
    <name>fs.defaultFS</name>
    <value>hdfs://$master/</value>
    <description>NameNode URI</description>
  </property>
EOF

cat > ~/yarn <<EOF
  <property>
    <name>yarn.scheduler.minimum-allocation-mb</name>
    <value>128</value>
    <description>Minimum limit of memory to allocate to each container request at the Resource Manager.</description>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>2048</value>
    <description>Maximum limit of memory to allocate to each container request at the Resource Manager.</description>
  </property>
  <property>
    <name>yarn.scheduler.minimum-allocation-vcores</name>
    <value>1</value>
    <description>The minimum allocation for every container request at the RM, in terms of virtual CPU cores. Requests lower than this won't take effect, and the specified value will get allocated the minimum.</description>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-vcores</name>
    <value>2</value>
    <description>The maximum allocation for every container request at the RM, in terms of virtual CPU cores. Requests higher than this won't take effect, and will get capped to this value.</description>
  </property>
  <property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>4096</value>
    <description>Physical memory, in MB, to be made available to running containers</description>
  </property>
  <property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>4</value>
    <description>Number of CPU cores that can be allocated for containers.</description>
  </property>
<property>
                <name>yarn.resourcemanager.hostname</name>
                <value>$master</value>
                <description>The hostname of the RM.</description>
        </property>
EOF

sleep 3

export HADOOP_PREFIX=/usr/local/hadoop-2.4.0
sed -i '/<configuration>/r /root/core' $HADOOP_PREFIX/etc/hadoop/core-site.xml
sed -i '/<configuration>/r /root/yarn' $HADOOP_PREFIX/etc/hadoop/yarn-site.xml

if [[ $1 == "master" ]]; then
  sed -i '/<configuration>/r /root/hdfs-master' $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml
  export JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk-amd64
  sleep 3
  $HADOOP_PREFIX/bin/hdfs namenode -format
  cat > ~/startall.sh <<EOF
  export JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk-amd64
$HADOOP_PREFIX/sbin/hadoop-daemon.sh start namenode
$HADOOP_PREFIX/sbin/hadoop-daemon.sh start datanode
$HADOOP_PREFIX/sbin/yarn-daemon.sh start resourcemanager
$HADOOP_PREFIX/sbin/yarn-daemon.sh start nodemanager
jps
EOF
chmod +x ~/startall.sh
else
  sed -i '/<configuration>/r /root/hdfs' $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml
  cat > ~/startall.sh <<EOF
  export JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk-amd64
$HADOOP_PREFIX/sbin/hadoop-daemon.sh start datanode
$HADOOP_PREFIX/sbin/yarn-daemon.sh start nodemanager
jps
EOF
chmod +x ~/startall.sh
fi

sleep 3
~/startall.sh

cd $BASE_DIR
tar zxvf hbase-0.98.2-hadoop2-bin.tar.gz -C /root/

echo "export HBASE_SSH_OPTS=\"-o StrictHostKeyChecking=no -i $BASE_DIR/id_rsa\"" >> /root/hbase-0.98.2-hadoop2/conf/hbase-env.sh
echo 'export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/' >> /root/hbase-0.98.2-hadoop2/conf/hbase-env.sh 

cat $BASE_DIR/hbase-site-template.xml | sed "s/MASTER_NAME/`echo $master`/g" > /root/hbase-0.98.2-hadoop2/conf/hbase-site.xml

if [[ $1 == "master" ]]; then
	$HADOOP_PREFIX/bin/hadoop fs -mkdir /hbase
	$HADOOP_PREFIX/bin/hadoop fs -mkdir /zk_data

	let i=1
	while (( i < $num )); do
		slavename="$base_host_name"slave$i
		echo $slavename >> /root/hbase-0.98.2-hadoop2/conf/regionservers
		let i+=1
	done

	cd /root/hbase-0.98.2-hadoop2/
	#./bin/start-hbase.sh
fi
