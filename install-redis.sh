#linux redis自动安装程序 
#运行例子：mkdir -p /shell && cd /shell && rm -rf install-redis.sh && wget --no-cache https://raw.githubusercontent.com/share-group/shell/master/install-redis.sh && sh install-redis.sh 5.0.2 /usr/local

function cluster(){ 
	redis_install_path=$1;
	port=$2;
	mkdir -p $redis_install_path/redis/cluster/$port
	cd $redis_install_path/redis/cluster/$port
	echo "daemonize yes 	
pidfile "$redis_install_path"/redis/cluster/"$port"/redis-"$port".pid 
port "$port"
bind 0.0.0.0
timeout 0
databases 16
maxclients 1000
dir "$redis_install_path"/redis/cluster/"$port"/
#loglevel debug
#logfile "$redis_install_path"/redis/redis.log
syslog-enabled no
slowlog-log-slower-than -1
appendonly no
auto-aof-rewrite-percentage 0
cluster-enabled yes
cluster-config-file "$redis_install_path"/redis/cluster/"$port"/nodes_"$port".conf
cluster-node-timeout 15000" > redis.conf
	redis-server $redis_install_path/redis/cluster/$port/redis.conf
}

#定义本程序的当前目录
base_path=$(pwd)
ntpdate ntp.api.bz

#处理外部参数
redis_version=$1
redis_install_path=$2
if [ ! $redis_version ] || [ ! $redis_install_path ]; then
	echo 'error command!!! you must input redis version and install path...'
	echo 'for example: sh install-redis.sh 5.0.2 /usr/local'
	exit
fi

yum -y install gcc gcc-c++ ruby ruby-devel rubygems 

#建立临时安装目录
echo 'preparing working path...'
install_path='/install'
rm -rf $install_path
mkdir -p $install_path

#安装jemalloc
jemalloc='jemalloc-5.1.0'
if [ ! -d $install_path/$jemalloc ]; then
	echo 'installing '$jemalloc' ...'
	if [ ! -f $base_path/$jemalloc.tar.bz2 ]; then
		echo $jemalloc'.tar.bz2 is not exists, system will going to download it...'
		wget -O $base_path/$jemalloc.tar.bz2 http://install.ruanzhijun.cn/$jemalloc.tar.bz2 || exit
		echo 'download '$jemalloc' finished...'
	fi
	tar xvf $base_path/$jemalloc.tar.bz2 -C $install_path || exit
	mv $install_path/$jemalloc $install_path/jemalloc 
fi 

#安装redis 
if [ ! -d $redis_install_path/redis ]; then
	if [ ! -f $base_path/redis-$redis_version.tar.gz ]; then
		echo 'redis-'$redis_version'.tar.gz is not exists, system will going to download it...'
		wget -O $base_path/redis-$redis_version.tar.gz http://install.ruanzhijun.cn/redis-$redis_version.tar.gz || exit
		echo 'download redis-'$redis_version'.tar.gz finished...'
	fi
	tar zxvf $base_path/redis-$redis_version.tar.gz -C $redis_install_path || exit
	mv $redis_install_path/redis-$redis_version $redis_install_path/redis
	cd $redis_install_path/redis/deps
	rm -rf jemalloc
	cp -rf $install_path/jemalloc ./
	cd $redis_install_path/redis
	make
	echo "daemonize yes 	
pidfile "$redis_install_path"/redis/redis.pid 
port 6379
bind 0.0.0.0
timeout 0
databases 16
maxclients 1000
dir "$redis_install_path"/redis/
#loglevel debug
#logfile "$redis_install_path"/redis/redis.log
syslog-enabled no
slowlog-log-slower-than -1
appendonly no
auto-aof-rewrite-percentage 0
requirepass admin" > $redis_install_path/redis/redis.conf
fi

#设置ruby gem源为Ruby China
gem sources --add https://gems.ruby-china.org/
gem install redis

#关闭防火墙
systemctl stop firewalld
systemctl disable firewalld.service

#redis全局命令
yes|cp -rf $redis_install_path'/redis/src/redis-server' /usr/bin/
yes|cp -rf $redis_install_path'/redis/src/redis-cli' /usr/bin/
yes|cp -rf $redis_install_path'/redis/src/redis-trib.rb' /usr/bin/
source /etc/rc.local

#启动单点的redis
redis-server $redis_install_path/redis/redis.conf

#默认创建一个6个节点(3主3从)的集群
cluster $redis_install_path 7000
cluster $redis_install_path 7001
cluster $redis_install_path 7002
cluster $redis_install_path 7003
cluster $redis_install_path 7004
cluster $redis_install_path 7005
redis-trib.rb create --replicas 1 127.0.0.1:7000 127.0.0.1:7001 127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005
