#!/bin/bash

ip=`ifconfig|egrep 'inet (addr:){0,1}192\.168|inet (addr:){0,1}10|inet (addr:){0,1}172\.1[6-9]|inet (addr:){0,1}172\.2[0-9]|inet (addr:){0,1}172\.3[01]'| awk '{print $2}'| awk -F':' '{if ($1=="addr"){print $2} else {print $1}}' | head -n 1`
host_name=`hostname | awk -F'.localdomain' '{print $1}'`
cd /home/work/open-falcon/agent/
mkdir ../conf
sed -i "s/open-falcon/chyanwen/g" cfg.json
./control start
sleep 5
port=`netstat -ntulp | grep 1988 | awk -F ':::' '{print $2}'`
if [ ${port} = "1988" ];then
     echo "agent started!"
else
     echo "agent started failed!"
     exit 2
fi

echo "set crontab to auto-start agent."

cat <<EOF >/etc/cron.d/agent_cron
#crontab for auto restart agent 
*/5 * * * * root . /etc/profile;/usr/sbin/ss -nlt | grep 1988 || bash /home/work/open-falcon/agent/control start
#check plugin and agent version
*/30 * * * * root /usr/bin/flock -xn /tmp/check_version.lock -c ". /etc/profile;/usr/bin/env python /home/work/open-falcon/agent/plugin/check_version.py"
EOF
if [ $? -eq 0 ];then
	echo "set crontab for auto restart agent success!"
else
	echo "set crontab for auto restart agent failed!"
fi

echo "update the plugin scripts!"
curl http://127.0.0.1:1988/plugin/update &>/dev/null
if [ $? -eq 0 ];then
	echo "Update the plugin scritpts success!"
else
	echo "Update the plugin script failed,now update it again!"
        rm -rf plugin
        curl http://127.0.0.1:1988/plugin/update &>/dev/null
        if [ $? -eq 0 ];then
		echo "Update the plugin scritpts success!"
        else
		echo "Update the plugin script failed!"
		exit 1
        fi
fi

echo "change dir to /home/work/open-falcon/conf."
cd /home/work/open-falcon/conf
echo "create logfile logmonitor.conf."
if [ -e logmonitor.conf ];then
   echo "logmonitor.conf exists."
else
cat <<EOF >logmonitor.conf
[log1]
#日志文件的路径,以“/”结束
path=/var/log/
#日志文件名称
logfile=keepalived.log
#要匹配的关键字,列表的形式,支持python正则表达式，如果匹配字符串有元字符，请注意转义
keywords=["Transition to MASTER STATE|setting protocol VIPs|removing protocol VIPs"]
#与keywords的列表对应起来，必填,metric以log打头方便管理识别
metric=["log.redis.keepalive"]
#与keywords的列表对应起来，内容可为空
tags=[""]

[log2]
#日志文件的路径,以“/”结束
path=/usr/local/fountain/3rdparty/redis/
#日志文件名称
logfile=redis-sentinel_26379.log
#要匹配的关键字,列表的形式
keywords=["switch-master"]
#与keywords的列表对应起来，必填
metric=["log.redis.sentinel"]
#与keywords的列表对应起来，可以为空
tags=[""]
EOF
fi

echo "create argsfile args.conf."
if [ -e args.conf ];then
  echo "args.conf exists."
else
cat <<EOF >args.conf
#脚本名称对应，如：300_tcp_conn_status.py 取tcp_conn_status
[tcp_conn_status]
#参数一行一个
argv1=6602
argv2=9090

[NginxrpActiveConn]
argv1=192.168.6.107
EOF
fi
