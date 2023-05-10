#!/bin/bash

# 数据库主节点 IP，请修改
MYSQL_MASTER_IP=10.0.0.6

CPU=$(grep -c ^processor /proc/cpuinfo)
CPUS=$((CPU * 2))

DIR=$(pwd)

HOST_IP=$(hostname -I | awk '{print $1}' | awk -F '.' '{print $4}')

OS_VERSION=$(cat /etc/redhat-release | grep -Eo '[1-9]+' | head -n 1)

function color  {
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \E[0m"
    echo -n "$1" && $MOVE_TO_COL
    echo -n "["
    if [ $2 = "success" -o $2 = "0" ] ;then
        ${SETCOLOR_SUCCESS}
        echo -n $"    OK    "
    elif [ $2 = "failure" -o $2 = "1"  ] ;then
        ${SETCOLOR_FAILURE}
        echo -n $"  FAILED  "
    else
        ${SETCOLOR_WARNING}
        echo -n $"  WARNING  "
    fi
    ${SETCOLOR_NORMAL}
    echo -n "]"
    echo
}

# 初始配置
function init {
    if [ ${OS_VERSION} -eq 6 ]; then
        # 关闭防火墙
        service iptables stop
        chkconfig iptables off

        # 关闭 SELinux
        setenforce 0
        sed -Ei "/^SELINUX=enforcing/c SELINUX=disabled" /etc/selinux/config

        # 定制 vim
        echo -e 'set ts=4\nset et\nset t_Co=256\nset paste' >> /etc/vimrc

        # 定制命令提示符
        echo "PS1='\[\e[36m\][\u@\h \W]\\$ \[\e[0m\]'" >> .bashrc
        . .bashrc

        # 配置 yum 源
        sed -e "s|^mirrorlist=|#mirrorlist=|g" \
            -e "s|^#baseurl=http://mirror.centos.org/centos/\$releasever|baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos-vault/6.9|g" \
            -i.bak \
            /etc/yum.repos.d/CentOS-*.repo
        
        # 配置 EPEL 源
        yum install -y epel-release
        sed -e 's!^metalink=!#metalink=!g' \
    		-e 's!^#baseurl=!baseurl=!g' \
    		-e 's!http://download\.fedoraproject\.org/pub/epel!https://mirror.nju.edu.cn/epel!g' \
    		-e 's!http://download\.example/pub/epel!https://mirror.nju.edu.cn/epel!g' \
    		-i /etc/yum.repos.d/epel*.repo
    	sed -Ei "s#^gpgcheck=1#gpgcheck=0#g" /etc/yum.repos.d/epel*.repo
    	sed -Ei "/^gpgkey=/d" /etc/yum.repos.d/epel*.repo
    	rm -rf /etc/yum.repos.d/epel.repo

        # 安装初始软件包
        yum install -y gcc gcc-c++ make libtool m4 automake autoconf openssl-devel pam-devel mysql-devel readline-devel cmake ncurses-devel bison gmp-devel mpfr-devel libmpc-devel glibc.i686 glibc-devel.i686 flex bison lrzsz vim pcre-devel zlib-devel
    else
        # 关闭防火墙
        systemctl stop firewalld
        systemctl disable firewalld

        # 关闭 SELinux
        setenforce 0
        sed -Ei "/^SELINUX=enforcing/c SELINUX=disabled" /etc/selinux/config

        # 定制 vim
        echo -e 'set ts=4\nset et\nset t_Co=256\nset paste' >> /etc/vimrc

        # 定制命令提示符
        echo "PS1='\[\e[33m\][\u@\h \W]\\$ \[\e[0m\]'" >> .bashrc
        . .bashrc

        # 配置 yum 源
        sed -e 's|^mirrorlist=|#mirrorlist=|g' \
            -e 's|^#baseurl=http://mirror.centos.org/centos|baseurl=https://mirror.nju.edu.cn/centos|g' \
            -i.bak \
            /etc/yum.repos.d/CentOS-*.repo
        yum makecache

        # 安装初始软件包
        yum install -y gcc gcc-c++ make libtool m4 automake autoconf openssl-devel pam-devel mysql-devel readline-devel cmake ncurses-devel bison gmp-devel mpfr-devel libmpc-devel glibc.i686 glibc-devel.i686 flex bison lrzsz vim pcre-devel zlib-devel
    fi
}

# 配置 SSH
function  ssh_config {
        # 修改 SSH 服务配置文件，修改 SSH 端口号，禁止密码登陆
        sed -Ei "/^#Port 22/c Port 38972" /etc/ssh/sshd_config
        sed -Ei "/^PasswordAuthentication yes/c PasswordAuthentication no" /etc/ssh/sshd_config

        # 生成密钥对
        ssh-keygen -P "" -f /root/.ssh/id_rsa -t rsa

        # 将远程服务器公钥复制到本机
        cat >> /root/.ssh/authorized_keys <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAgEAveJ9rgW6yEni57mvm/4rKSWJL0EwY/TCHKou3U9jJouqOUPGlMqtPV2RffG1V/RLzF9ObF4X0+0ZJjXTvqZ1Xddz8Iq49vHGfpUBNfHG2FdJSw3ORL2XXub7KPn7aI12f9aUmI1GyyiQuF/NaDaGIupDZZ8LliONoOpeT2ZIE1eOezbKOehUDpxQkqxjPwJXTllWrjjPL8wQEDgGjoZ6013tvVL0qBuvq2/DO0btaBkFqJl4FJdAZGx2g4LnOdWcDZH4I+Wf5Eimcl1uubAC8m/o2gVJj7niTbjK8oJ6IFgvCHi87LOgOhWoyw3GDhluNECYGP0ojy4dHxbz6JSeskqvr5cFksz+HyELNXDEruyd/rE+ozdXDEhkCRXZDadx2u3bdjoiNc+qIlVUaPQp0Px6zvEIiF6tG7weAgI13qVfW3pj35QUhLF4pm21Je5i1BN23klH34TbH0A0l2oNn6k7rKNdpf1D3cxvWrsIpV2twC7X9I44mOSfXRkWGKchoiBgFB8s/UPihhxm+E2B13+sjgXJLFx0D+sgKTE0500IEXLTGpRAndCokkKRzwPfh4H4Kj0okljIbeCCghSYB/riVLZ9eUopx12U8HYRC9raj5j9Zh9NhHZ1VO74NXwX3TWAa0KqdfbTrFii6JjJVgvduDy4kWyV8bcY7sQRylE=
EOF

        # 修改服务器密码为随机 32 位加密字符串
        openssl rand -hex 16 | passwd --stdin root
        
        # 重启 SSH
        if [ ${OS_VERSION} -eq 6 ]; then
        	service sshd restart
        else
        	systemctl restart sshd
        fi
}

# 升级 sudo
SUDO_FILE=sudo-1.9.8b3
SUDO_SRC_DIR=/usr/local/src
SUDO_INSTALL_DIR=/usr/local/sudo

function update_sudo {
    if [ ${OS_VERSION} -eq 6 ]; then
        # 解压缩 sudo 软件包
        tar -zxvf ${DIR}/${SUDO_FILE}.tar.gz -C ${SUDO_SRC_DIR}
        cd ${SUDO_SRC_DIR}/${SUDO_FILE}

        # 编译安装
        ./configure --prefix=${SUDO_INSTALL_DIR}
        make -j${CPUS} && make install

        # 配置软链接
        mv /usr/bin/sudo /usr/bin/sudo.bak
        ln -s ${SUDO_INSTALL_DIR}/bin/sudo /usr/bin/sudo

        # 验证 sudo 版本
        sudo -V
    fi

    cd ${DIR}/
}

# 升级 Python
PYTHON_FILE=Python-2.7.14
PYTHON_SRC_DIR=/usr/local/src
PYTHON_INSTALL_DIR=/usr/local/python

function update_python {
    # 解压缩 Python 软件包
    tar -zxvf ${DIR}/${PYTHON_FILE}.tgz -C ${PYTHON_SRC_DIR}
    cd ${PYTHON_SRC_DIR}/${PYTHON_FILE}

    # 编译安装
    ./configure --prefix=${PYTHON_INSTALL_DIR} --enable-optimizations
    make -j${CPUS} && make install

    if [ ${OS_VERSION} -eq 6 ]; then
    	# 配置 Python 软链接
    	mv /usr/bin/python /usr/bin/python.bak
    	ln -s ${PYTHON_INSTALL_DIR}/bin/python /usr/bin/python

    	# 修改 yum 配置
    	sed -Ei "/^\#\!\/usr\/bin\/python/c \#\!\/usr\/bin\/python2.6" /usr/bin/yum
    else
    	# 配置 Python 软链接
    	ln -s --backup ${PYTHON_INSTALL_DIR}/bin/python /usr/bin/python

    	# 修改 yum 配置
    	sed -Ei "/^\#\!\/usr\/bin\/python/c \#\!\/usr\/bin\/python2" /usr/bin/yum
    	sed -Ei "/^\#\! \/usr\/bin\/python/c \#\! \/usr\/bin\/python2" /usr/libexec/urlgrabber-ext-down
    fi

        # 安装 pip
        yum install -y epel-release
        yum install -y python-pip

        # 修改 pip 指向新版本
        ${PYTHON_INSTALL_DIR}/bin/python2.7 -m ensurepip --default-pip

        # 配置 pip 软链接
        ln -s --backup ${PYTHON_INSTALL_DIR}/bin/pip /usr/bin/pip

        # pip 更改国内源
        cd ~
        mkdir .pip; cd .pip
        cat > pip.conf <<EOF
[global]
index-url=https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF

        # 使用 pip 安装库
        pip install amqp==2.2.2 ansi2html==1.2.0 asn1crypto==0.23.0 backports-abc==0.5 bcrypt==3.1.3 certifi==2017.7.27.1 cffi==1.11.1 chardet==3.0.4 cos-python-sdk-v5==1.7.7 cryptography==2.0.3 Cython==0.27 dicttoxml==1.7.4 enum34==1.1.6 idna==2.6 ipaddress==1.0.18 kazoo==2.6.0 kombu==4.1.0 mongoengine==0.15.0 msgpack-python==0.4.8 MySQL-python==1.2.5 paramiko==2.3.1 psutil==5.3.1 pyasn1==0.3.7 pycparser==2.18 pycrypto==2.6.1 pymongo==3.5.1 pymssql==2.1.4 PyNaCl==1.1.2 PyYAML==3.12 pyzmq==16.0.2 redis==2.10.6requests==2.18.4 simplejson==3.16.0 singledispatch==3.4.0.3 six==1.11.0 tornado==4.5.2 urllib3==1.22 vine==1.1.4 voluptuous==0.10.5

    cd ${DIR}/
}

# 升级 Gcc
GCC_FILE=gcc-4.8.2
GCC_SRC_DIR=/usr/local/src
GCC_INSTALL_DIR=/usr/local/gcc

function update_gcc {
    if [ ${OS_VERSION} -eq 6 ]; then
        # 解压缩 Gcc 软件包
        tar -zxvf ${DIR}/${GCC_FILE}.tar.gz -C ${GCC_SRC_DIR}
        cd ${GCC_SRC_DIR}/${GCC_FILE}

        # 下载相关依赖
        sed -Ei 's|ftp://gcc\.gnu\.org/pub/gcc/infrastructure/\$MPFR\.tar\.bz2|https://mirror.nju.edu.cn/gnu/mpfr/\$MPFR.tar.bz2|g' ${GCC_SRC_DIR}/${GCC_FILE}/contrib/download_prerequisites
        sed -Ei 's|ftp://gcc\.gnu\.org/pub/gcc/infrastructure/\$GMP\.tar\.bz2|https://mirror.nju.edu.cn/gnu/gmp/\$GMP.tar.bz2|g' ${GCC_SRC_DIR}/${GCC_FILE}/contrib/download_prerequisites
        sed -Ei "/^rm/c rm -f $MPFR.tar.bz2 $GMP.tar.bz2 $MPC.tar.gz || exit 1/"
        . ${GCC_SRC_DIR}/${GCC_FILE}/contrib/download_prerequisites

        # 编译安装
        ./configure --prefix=${GCC_INSTALL_DIR} --disable-checking
        make -j${CPUS} && make install

        # 配置环境变量
        echo "PATH=${GCC_INSTALL_DIR}/bin:$PATH" > /etc/profile.d/gcc.sh
        . /etc/profile.d/gcc.sh

        # 验证 gcc 版本
        gcc --version
    fi
    cd ${DIR}/
}

# 安装 MySQL 主节点
MYSQL_MASTER_GROUP=mysql
MYSQL_MASTER_USER=mysql
MYSQL_MASTER_FILE=mysql-5.6.39
MYSQL_MASTER_SRC_DIR=/usr/local/src
MYSQL_MASTER_INSTALL_DIR=/usr/local/mysql
MYSQL_MASTER_DATA=/usr/local/mysql/data

function install_master_mysql {
    # 安装编译工具与依赖库
    yum install -y cmake

    # 创建 MySQL 用户与用户组
    groupadd -r ${MYSQL_MASTER_USER}
    useradd -r -g ${MYSQL_MASTER_GROUP} ${MYSQL_MASTER_USER}

    # 解压缩 MySQL 软件包
    tar -zxvf ${DIR}/${MYSQL_MASTER_FILE}.tar.gz -C ${MYSQL_MASTER_SRC_DIR}
    cd ${MYSQL_MASTER_SRC_DIR}/${MYSQL_MASTER_FILE}

    # 生成 Makefile 文件
    cmake . -DCMAKE_INSTALL_PREFIX=${MYSQL_MASTER_INSTALL_DIR} \
-DMYSQL_DATADIR=${MYSQL_MASTER_DATA} \
-DMYSQL_UNIX_ADDR=${MYSQL_MASTER_DATA}/mysql.sock \
-DDEFAULT_CHARSET=utf8 \
-DDEFAULT_COLLATION=utf8_general_ci \
-DWITH_EXTRA_CHARSETS=all \
-DENABLED_LOCAL_INFILE=ON \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_FEDERATED_STORAGE_ENGINE=1 \
-DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
-DWITHOUT_EXAMPLE_STORAGE_ENGINE=1 \
-DWITH_ZLIB=bundled \
-DWITH_SSL=bundled \
-DENABLED_LOCAL_INFILE=1 \
-DWITH_EMBEDDED_SERVER=1 \
-DENABLE_DOWNLOADS=1 \
-DWITH_DEBUG=0

    # 编译安装
    make -j${CPUS} && make install

    # 配置目录权限
    chown -R ${MYSQL_MASTER_USER}.${MYSQL_MASTER_USER} ${MYSQL_MASTER_INSTALL_DIR}

    # 配置环境变量
    echo "PATH=${MYSQL_MASTER_INSTALL_DIR}/bin/:$PATH" > /etc/profile.d/mysql.sh
    . /etc/profile.d/mysql.sh

    # 初始化数据库
    ${MYSQL_MASTER_INSTALL_DIR}/scripts/mysql_install_db --user=${MYSQL_MASTER_USER} --basedir=${MYSQL_MASTER_INSTALL_DIR} --datadir=${MYSQL_MASTER_DATA}

    # 准备 MySQL 配置文件
    cat > /etc/my.cnf <<EOF
[mysqld]
datadir=${MYSQL_MASTER_DATA}
socket=${MYSQL_MASTER_DATA}/mysql.sock
log-error=${MYSQL_MASTER_DATA}/mysql.log
pid-file=${MYSQL_MASTER_DATA}/mysql.pid
skip_name_resolve=1
EOF

    # 准备服务脚本并自启
    cp ${MYSQL_MASTER_INSTALL_DIR}/support-files/mysql.server /etc/init.d/mysqld
    sed -Ei '/^basedir=/c basedir=${MYSQL_MASTER_INSTALL_DIR}' /etc/init.d/mysqld
    sed -Ei '/^datadir=/c datadir=${MYSQL_MASTER_DATA}' /etc/init.d/mysqld

    chmod +x /etc/init.d/mysqld
    chkconfig --add mysqld

    # 启动 MySQL 服务并修改 root 用户密码
    service mysqld start
    ${MYSQL_MASTER_INSTALL_DIR}/bin/mysqladmin -uroot password 123456

    cd ${DIR}/
}

# 安装 MySQL 从节点
MYSQL_SLAVE_GROUP=mysql
MYSQL_SLAVE_USER=mysql
MYSQL_SLAVE_PORT=3307
MYSQL_SLAVE_FILE=mysql-5.6.39
MYSQL_SLAVE_SRC_DIR=/usr/local/src
MYSQL_SLAVE_INSTALL_DIR=/usr/local/mysql
MYSQL_SLAVE_DATA=/usr/local/mysql/data

function install_slave_mysql {
    # 安装编译工具与依赖库
    yum install -y cmake ncurses-devel bison make gcc-c++

    # 创建 MySQL 用户与用户组
    groupadd -r ${MYSQL_SLAVE_USER}
    useradd -r -g ${MYSQL_SLAVE_GROUP} ${MYSQL_SLAVE_USER}

    # 解压缩 MySQL 软件包
    tar -zxvf ${DIR}/${MYSQL_SLAVE_FILE}.tar.gz -C ${MYSQL_SLAVE_SRC_DIR}
    cd ${MYSQL_SLAVE_SRC_DIR}/${MYSQL_SLAVE_FILE}

    # 生成 Makefile 文件
    cmake . -DCMAKE_INSTALL_PREFIX=${MYSQL_SLAVE_INSTALL_DIR} \
-DMYSQL_DATADIR=${MYSQL_SLAVE_DATA} \
-DMYSQL_UNIX_ADDR=${MYSQL_SLAVE_DATA}/mysql.sock \
-DDEFAULT_CHARSET=utf8 \
-DDEFAULT_COLLATION=utf8_general_ci \
-DWITH_EXTRA_CHARSETS=all \
-DENABLED_LOCAL_INFILE=ON \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_FEDERATED_STORAGE_ENGINE=1 \
-DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
-DWITHOUT_EXAMPLE_STORAGE_ENGINE=1 \
-DWITH_ZLIB=bundled \
-DWITH_SSL=bundled \
-DENABLED_LOCAL_INFILE=1 \
-DWITH_EMBEDDED_SERVER=1 \
-DENABLE_DOWNLOADS=1 \
-DWITH_DEBUG=0

    # 编译安装
    make -j${CPUS} && make install

    # 配置目录权限
    chown -R ${MYSQL_SLAVE_USER}.${MYSQL_SLAVE_USER} ${MYSQL_SLAVE_INSTALL_DIR}

    # 配置环境变量
    echo "PATH=${MYSQL_SLAVE_INSTALL_DIR}/bin/:$PATH" > /etc/profile.d/mysql.sh
    . /etc/profile.d/mysql.sh

    # 初始化数据库
    ${MYSQL_SLAVE_INSTALL_DIR}/scripts/mysql_install_db --user=${MYSQL_SLAVE_USER} --basedir=${MYSQL_SLAVE_INSTALL_DIR} --datadir=${MYSQL_SLAVE_DATA}

    # 准备 MySQL 配置文件
    cat > /etc/my.cnf <<EOF
[mysqld]
port=${MYSQL_SLAVE_PORT}
datadir=${MYSQL_SLAVE_DATA}
socket=${MYSQL_SLAVE_DATA}/mysql.sock
log-error=${MYSQL_SLAVE_DATA}/mysql.log
pid-file=${MYSQL_SLAVE_DATA}/mysql.pid
skip_name_resolve=1
EOF

    # 准备服务脚本并自启
    cp ${MYSQL_SLAVE_INSTALL_DIR}/support-files/mysql.server /etc/init.d/mysqld
    sed -Ei "/^basedir=/c basedir=\"${MYSQL_SLAVE_INSTALL_DIR}\"" /etc/init.d/mysqld
    sed -Ei "/^datadir=/c datadir=\"${MYSQL_SLAVE_DATA}\"" /etc/init.d/mysqld

    chmod +x /etc/init.d/mysqld
    chkconfig --add mysqld

    # 启动 MySQL 服务并修改 root 用户密码
    service mysqld start
    ${MYSQL_MASTER_INSTALL_DIR}/bin/mysqladmin -uroot password 123456

    cd ${DIR}/
}

# 主节点配置主从复制
MYSQL_ROOT_USER=root
MYSQL_ROOT_PASS=123456
MYSQL_REPL_USER=repluser
MYSQL_REPL_PASS=123456
MYSQL_REPL_DATA=/usr/local/mysql/data

function MySQL_Master_Replication {
    # 检测 MySQL 进程
    pgrep mysql > /dev/null

    if [ ! $? == 0 ]; then
        echo "请检查 MySQL 是否正常运行！！！"
        exit
    fi

    # 修改 MySQL 配置文件
    sed -Ei "/\[mysqld\]/a server-id=${HOST_IP}" /etc/my.cnf
    sed -Ei "/\[mysqld\]/a log-bin=${MYSQL_REPL_DATA}/binlog/mysql-bin" /etc/my.cnf

    # 创建二进制日志目录
    mkdir -p ${MYSQL_REPL_DATA}/binlog
    chown -R mysql.mysql /usr/local/mysql/

    # 重新启动 MySQL
    service mysqld restart

    # 创建有复制权限的数据库用户
    ${MYSQL_MASTER_INSTALL_DIR}/bin/mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASS} -e "GRANT REPLICATION SLAVE ON *.* TO 'repluser'@'%' IDENTIFIED BY '123456';" > /dev/null
    ${MYSQL_MASTER_INSTALL_DIR}/bin/mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASS} -e "FLUSH PRIVILEGES;" > /dev/null
}

# 从节点配置主从复制
function MySQL_Slave_Replication {
    # 检测 MySQL 进程
    pgrep mysql > /dev/null

    if [ ! $? == 0 ]; then
        echo "请检查 MySQL 是否正常运行！！！"
        exit
    fi

    # 修改 MySQL 配置文件
    sed -Ei "/\[mysqld\]/a server-id=${HOST_IP}" /etc/my.cnf
    sed -Ei "/\[mysqld\]/a log-bin=${MYSQL_REPL_DATA}/binlog/mysql-bin" /etc/my.cnf
    sed -Ei "/\[mysqld\]/a log-bin=${MYSQL_REPL_DATA}/relaylog/relay-log" /etc/my.cnf
    sed -Ei "/\[mysqld\]/a log-bin=${MYSQL_REPL_DATA}/relaylog/relay-log.index" /etc/my.cnf
    sed -Ei "/\[mysqld\]/a read_only=1" /etc/my.cnf

    # 创建日志目录
    mkdir -p ${MYSQL_REPL_DATA}/{binlog,relaylog}
    chown -R mysql.mysql /usr/local/mysql/

    # 重新启动 MySQL
    service mysqld restart

    # 连接主库
    ${MYSQL_SLAVE_INSTALL_DIR}/bin/mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASS} -e "CHANGE MASTER TO MASTER_HOST='${MYSQL_MASTER_IP}', MASTER_USER='${MYSQL_REPL_USER}',MASTER_PASSWORD='${MYSQL_REPL_PASS}',MASTER_PORT=3306;" > /dev/null

    # 启动复制线程
    ${MYSQL_SLAVE_INSTALL_DIR}/bin/mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASS} -e "START SLAVE;" > /dev/null

    # 查看主从复制状态
    ${MYSQL_SLAVE_INSTALL_DIR}/bin/mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASS} -e "SHOW SLAVE STATUS\G"
}

# 安装 Nginx
NGINX_FILE=nginx-1.13.9
NGINX_SRC_DIR=/usr/local/src
NGINX_INSTALL_DIR=/usr/local/nginx
NGINX_USER=www

function install_nginx {
    # 安装依赖包
    yum install -y make gcc pcre-devel openssl-devel zlib-devel

    # 创建 Nginx 用户
    useradd -s /sbin/nologin ${NGINX_USER}

    # 解压缩软件包
    tar -zxvf ${DIR}/${NGINX_FILE}.tar.gz -C ${NGINX_SRC_DIR}
    cd ${NGINX_SRC_DIR}/${NGINX_FILE}

    # 编译安装
    ./configure --prefix=${NGINX_INSTALL_DIR} --user=${NGINX_USER} --group=${NGINX_USER} --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_stub_status_module --with-http_gzip_static_module --with-pcre --with-stream --with-stream_ssl_module --with-stream_realip_module
    make -j${CPUS} && make install

    # 修改目录权限
    chown -R ${NGINX_USER}.${NGINX_USER} ${NGINX_INSTALL_DIR}

    # 配置软链接
    ln -s ${NGINX_INSTALL_DIR}/sbin/nginx /usr/sbin/

    if [ ${OS_VERSION} -eq 6 ]; then
        # 启动 Nginx 并加入开机自启
        ${INSTALL_DIR}/sbin/nginx
        echo "${NGINX_INSTALL_DIR}/sbin/nginx" >> /etc/rc.local
    else
        # 创建 service 文件
        cat > /lib/systemd/system/nginx.service << EOF
[Unit]
Description=nginx - high performance web server
Documentation=http://nginx.org/en/docs/
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=${NGINX_INSTALL_DIR}/run/nginx.pid
ExecStart=${NGINX_INSTALL_DIR}/sbin/nginx -c ${NGINX_INSTALL_DIR}/conf/nginx.conf
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s TERM \$MAINPID
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF

        # 准备相关目录和文件
        mkdir ${NGINX_INSTALL_DIR}/run
        sed -Ei "/^#pid/c pid ${NGINX_INSTALL_DIR}\/run\/nginx.pid;" ${NGINX_INSTALL_DIR}/conf/nginx.conf

        # 启动 Nginx 服务并配置开机自启
        systemctl daemon-reload
        systemctl enable --now nginx
    fi

    cd ${DIR}/
}

# 安装 Redis
REDIS_FILE=redis-4.0.8
REDIS_SRC_DIR=/usr/local/src
REDIS_INSTALL_DIR=/usr/local/redis

function install_redis {
    # 解压缩软件包
    tar -zxvf ${DIR}/${REDIS_FILE}.tar.gz -C ${REDIS_SRC_DIR}
    cd ${REDIS_SRC_DIR}/${REDIS_FILE}

    # 编译安装
    make USE_SYSTEMD=yes PREFIX=${REDIS_INSTALL_DIR} install

    # 配置环境变量
    echo 'PATH=${REDIS_INSTALL_DIR}/bin:$PATH' > /etc/profile.d/redis.sh
    . /etc/profile.d/redis.sh

    # 准备相关目录与配置文件
    mkdir -p ${REDIS_INSTALL_DIR}/{etc,log,data,run}
    cp ${REDIS_SRC_DIR}/${REDIS_FILE}/redis.conf ${REDIS_INSTALL_DIR}/etc/
    cp ${REDIS_SRC_DIR}/${REDIS_FILE}/sentinel.conf ${REDIS_INSTALL_DIR}/etc/

    # 修改配置文件
    sed -Ei 's/pidfile \/var\/run\/redis_6379.pid/pidfile \/usr\/local\/redis\/run\/redis_6379.pid/g' ${REDIS_INSTALL_DIR}/etc/redis.conf
    sed -Ei 's/logfile ""/logfile  \/usr\/local\/redis\/log\/redis_6379.log/g' ${REDIS_INSTALL_DIR}/etc/redis.conf
    sed -Ei 's/^bind 127.0.0.1.*/bind 0.0.0.0/g' ${REDIS_INSTALL_DIR}/etc/redis.conf
    sed -Ei 's/^dir .\//dir  \/usr\/local\/redis\/data\//' ${REDIS_INSTALL_DIR}/etc/redis.conf
    sed -Ei 's/# requirepass foobared/requirepass 123456/' ${REDIS_INSTALL_DIR}/etc/redis.conf
    sed -Ei 's/daemonize no/daemonize yes/' ${REDIS_INSTALL_DIR}/etc/redis.conf

    if [ ${OS_VERSION} -eq 6 ]; then
        # 启动 Redis 并加入开机自启
        ${REDIS_INSTALL_DIR}/bin/redis-server ${REDIS_INSTALL_DIR}/etc/redis.conf
        echo "${REDIS_INSTALL_DIR}/bin/redis-server ${REDIS_INSTALL_DIR}/etc/redis.conf" >> /etc/rc.local
    else
        # 创建 Redisn 用户
        useradd -r -s /sbin/nologin redis
        chown -R redis.redis ${REDIS_INSTALL_DIR}

        # 准备 service 文件
        cat > /lib/systemd/system/redis.service << EOF
[Unit]
Description=Redis persistent key-value database
After=network.target

[Service]
ExecStart=${REDIS_INSTALL_DIR}/bin/redis-server ${REDIS_INSTALL_DIR}/etc/redis.conf --supervised systemd
ExecStop=/bin/kill -s QUIT \$MAINPID
Type=notify
User=redis
Group=redis
RuntimeDirectory=redis
RuntimeDirectoryMode=0755
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

        # 启动 Redis 服务并配置开机自启
        systemctl daemon-reload
        systemctl enable --now redis
    fi

    cd ${DIR}/
}

echo "1) Master"
echo "2) Slave"
read -p "请选择你的节点类型（输入序号）：" OPTIONS

if [ ${OPTIONS} -eq 1 ]; then
    if [ ${OS_VERSION} -eq 6 ]; then
        if [ ! -f ${SUDO_FILE}.tar.gz ]; then
            color "未检测到 sudo 软件包，请重新上传！！！" 1
        fi

        if [ ! -f ${PYTHON_FILE}.tgz ]; then
            color "未检测到 Python 软件包，请重新上传！！！" 1
        fi

        if [ ! -f ${MYSQL_MASTER_FILE}.tar.gz ]; then
            color "未检测到 MySQL 软件包，请重新上传！！！" 1
        fi

        if [ ! -f ${GCC_FILE}.tar.gz ]; then
            color "未检测到 gcc 软件包，请重新上传！！！" 1
            exit
        fi

        init
        ssh_config
        update_gcc
        update_sudo
        update_python
        install_master_mysql
        MySQL_Master_Replication
    else
        if [ ! -f ${PYTHON_FILE}.tgz ]; then
            color "未检测到 Python 软件包，请重新上传！！！" 1
        fi

        if [ ! -f ${MYSQL_MASTER_FILE}.tar.gz ]; then
            color "未检测到 MySQL 软件包，请重新上传！！！" 1
            exit
        fi

        init
        ssh_config
        update_python
        install_master_mysql
        MySQL_Master_Replication
    fi
else
    if [ ${OS_VERSION} -eq 6 ]; then
        if [ ! -f ${SUDO_FILE}.tar.gz ]; then
            color "未检测到 sudo 软件包，请重新上传！！！" 1
        fi

        if [ ! -f ${PYTHON_FILE}.tgz ]; then
            color "未检测到 Python 软件包，请重新上传！！！" 1
        fi

        if [ ! -f ${MYSQL_SLAVE_FILE}.tar.gz ]; then
            color "未检测到 MySQL 软件包，请重新上传！！！" 1
        fi

        if [ ! -f ${NGINX_FILE}.tar.gz ]; then
            color "未检测到 Nginx 软件包，请重新上传！！！" 1
        fi

        if [ ! -f ${REDIS_FILE}.tar.gz ]; then
            color "未检测到 Redis 软件包，请重新上传！！！" 1
            exit
        fi

        init
        ssh_config
        update_sudo
        update_python
        install_slave_mysql
        MySQL_Slave_Replication
        install_nginx
        install_redis
    else
        if [ ! -f ${PYTHON_FILE}.tgz ]; then
            color "未检测到 Python 软件包，请重新上传！！！" 1
        fi

        if [ ! -f ${MYSQL_SLAVE_FILE}.tar.gz ]; then
            color "未检测到 MySQL 软件包，请重新上传！！！" 1
        fi

        if [ ! -f ${NGINX_FILE}.tar.gz ]; then
            color "未检测到 Nginx 软件包，请重新上传！！！" 1
        fi

        if [ ! -f ${REDIS_FILE}.tar.gz ]; then
            color "未检测到 Redis 软件包，请重新上传！！！" 1
            exit
        fi

        init
        ssh_config
        update_python
        install_slave_mysql
        MySQL_Slave_Replication
        install_nginx
        install_redis
    fi
fi