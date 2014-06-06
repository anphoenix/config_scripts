#!/bin/bash

BASE=$(cd "$(dirname "$0")"; pwd)
export SPARK_HOME=/root/spark-1.0.0-bin-hadoop2

cd $BASE
tar xvf spark-1.0.0-bin-hadoop2.tgz -C /root/ > /dev/null
#libraries for sbt 
tar zxvf ivy65.tar.gz -C /root/ > /dev/null

#install maven
tar zxvf apache-maven-3.2.1-bin.tar.gz -C /usr/local/ > /dev/null

echo "export M2_HOME=/usr/local/apache-maven-3.2.1" >> /root/.bashrc
echo "export M2=\$M2_HOME/bin" >> /root/.bashrc
echo "export PATH=\$M2:\$PATH" >> /root/.bashrc
echo "export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64" >> /root/.bashrc

source /root/.bashrc

tar zxvf mavenrepo.tar.gz -C /root/ > /dev/null
tar zxvf sbt-0.12.4.tar.gz -C /root/ > /dev/null
chmod +x /root/sbt/sbt

cat $BASE/envi >> /root/.bashrc

cp -r $BASE/sampleapps /root/


if [[ -n $1 ]]; then
	cd $SPARK_HOME
	#./bin/spark-class org.apache.spark.deploy.worker.Worker spark://$1:7077 &
        echo "export MASTER=spark://$1:7077" >> /root/.bashrc
else
	cd $SPARK_HOME
	#./sbin/start-master.sh &
        echo "export MASTER=spark://`hostname`:7077" >> /root/.bashrc
fi

#apt-get -y install libgfortran3


source /root/.bashrc

#set up data file for sample apps to run
#/usr/local/hadoop-2.4.0/bin/hadoop fs -put $BASE/misc/graph_test /
