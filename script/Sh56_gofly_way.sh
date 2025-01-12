#!/bin/bash
#copyright by hiboy
source /etc/storage/script/init.sh
goflyway_enable=`nvram get app_23`
[ -z $goflyway_enable ] && goflyway_enable=0 && nvram set app_23=0
#if [ "$goflyway_enable" != "0" ] ; then
#nvramshow=`nvram showall | grep '=' | grep goflyway | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow
#fi
mkdir -p /etc/storage/goflyway
keypem_s_path="/etc/storage/goflyway/key.pem"
capem_s_path="/etc/storage/goflyway/ca.pem"
keypem_path="/opt/bin/key.pem"
capem_path="/opt/bin/ca.pem"

goflyway_renum=`nvram get goflyway_renum`
goflyway_renum=${goflyway_renum:-"0"}
cmd_log_enable=`nvram get cmd_log_enable`
cmd_name="goflyway"
cmd_log=""
if [ "$cmd_log_enable" = "1" ] || [ "$goflyway_renum" -gt "0" ] ; then
	cmd_log="$cmd_log2"
fi
if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep gofly_way)" ]  && [ ! -s /tmp/script/_app7 ]; then
	mkdir -p /tmp/script
	{ echo '#!/bin/bash' ; echo $scriptfilepath '"$@"' '&' ; } > /tmp/script/_app7
	chmod 777 /tmp/script/_app7
fi

goflyway_restart () {

relock="/var/lock/goflyway_restart.lock"
if [ "$1" = "o" ] ; then
	nvram set goflyway_renum="0"
	[ -f $relock ] && rm -f $relock
	return 0
fi
if [ "$1" = "x" ] ; then
	if [ -f $relock ] ; then
		logger -t "【goflyway】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		exit 0
	fi
	goflyway_renum=${goflyway_renum:-"0"}
	goflyway_renum=`expr $goflyway_renum + 1`
	nvram set goflyway_renum="$goflyway_renum"
	if [ "$goflyway_renum" -gt "3" ] ; then
		I=19
		echo $I > $relock
		logger -t "【goflyway】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		while [ $I -gt 0 ]; do
			I=$(($I - 1))
			echo $I > $relock
			sleep 60
			[ "$(nvram get goflyway_renum)" = "0" ] && exit 0
			[ $I -lt 0 ] && break
		done
		nvram set goflyway_renum="1"
	fi
	[ -f $relock ] && rm -f $relock
fi
nvram set goflyway_status=0
eval "$scriptfilepath &"
exit 0
}

goflyway_get_status () {

A_restart=`nvram get goflyway_status`
B_restart="$goflyway_enable$(cat /etc/storage/app_7.sh | grep -v "^#" | grep -v "^$")"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
cut_B_re
if [ "$A_restart" != "$B_restart" ] ; then
	nvram set goflyway_status=$B_restart
	needed_restart=1
else
	needed_restart=0
fi
}

goflyway_check () {

goflyway_get_status
if [ "$goflyway_enable" != "1" ] && [ "$needed_restart" = "1" ] ; then
	[ ! -z "`pidof goflyway`" ] && logger -t "【goflyway】" "停止 goflyway" && goflyway_close
	{ kill_ps "$scriptname" exit0; exit 0; }
fi
if [ "$goflyway_enable" = "1" ] ; then
	if [ "$needed_restart" = "1" ] ; then
		goflyway_close
		goflyway_start
	else
		[ -z "`pidof goflyway`" ] && goflyway_restart
	fi
fi
}

goflyway_keep () {
logger -t "【goflyway】" "守护进程启动"
if [ -s /tmp/script/_opt_script_check ]; then
sed -Ei '/【goflyway】|^$/d' /tmp/script/_opt_script_check
cat >> "/tmp/script/_opt_script_check" <<-OSC
[ -z "\`pidof goflyway\`" ] && nvram set goflyway_status=00 && logger -t "【goflyway】" "重新启动" && eval "$scriptfilepath &" && sed -Ei '/【goflyway】|^$/d' /tmp/script/_opt_script_check # 【goflyway】
OSC
return
fi

while true; do
	if [ -z "`pidof goflyway`" ] ; then
		logger -t "【goflyway】" "重新启动"
		goflyway_restart
	fi
sleep 252
done
}

goflyway_close () {

kill_ps "$scriptname keep"
sed -Ei '/【goflyway】|^$/d' /tmp/script/_opt_script_check
killall goflyway
killall -9 goflyway
kill_ps "/tmp/script/_app7"
kill_ps "_gofly_way.sh"
kill_ps "$scriptname"
}

goflyway_start () {

check_webui_yes
SVC_PATH="$(which goflyway)"
[ ! -s "$SVC_PATH" ] && SVC_PATH="/opt/bin/goflyway"
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【goflyway】" "找不到 $SVC_PATH，安装 opt 程序"
	/etc/storage/script/Sh01_mountopt.sh start
fi
for h_i in $(seq 1 2) ; do
[[ "$($SVC_PATH -h 2>&1 | wc -l)" -lt 2 ]] && rm -rf $SVC_PATH
wgetcurl_file "$SVC_PATH" "$hiboyfile/goflyway" "$hiboyfile2/goflyway"
done
if [ -s "$SVC_PATH" ] ; then
if [ ! -s "$capem_s_path" ] && [ -s "$capem_path" ] ; then
cp -f "$keypem_path" "$keypem_s_path"
cp -f "$capem_path" "$capem_s_path"
fi
rm -f  "$keypem_path" "$capem_path"
ln -sf "$keypem_s_path" "$keypem_path"
ln -sf "$capem_s_path" "$capem_path"
if [ ! -s "$capem_path" ] && [[ "$(goflyway -h 2>&1 | grep gen-ca | wc -l)" -gt 0 ]] ; then
	logger -t "【goflyway】" "找不到 $capem_path 正在生成 ca.pem、key.pem 稍等几分钟"
	cd /opt/bin/
	./goflyway -gen-ca
fi
if [ ! -s "$capem_path" ] ; then
wgetcurl_checkmd5 "$capem_path" "$hiboyfile/ca.pem" "$hiboyfile2/ca.pem" N
fi
if [ -s "$capem_path" ] ; then
	chmod 755 "$capem_path" "$keypem_path"
fi
[ ! -f /opt/bin/chinalist.txt ] && update_chnlist

fi
[[ "$(goflyway -h 2>&1 | wc -l)" -lt 2 ]] && rm -rf /opt/bin/goflyway
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【goflyway】" "找不到 $SVC_PATH ，需要手动安装 $SVC_PATH"
	logger -t "【goflyway】" "启动失败, 10 秒后自动尝试重新启动" && sleep 10 && goflyway_restart x
fi
chmod 777 "$SVC_PATH"
goflyway_v=$(goflyway -version | grep goflyway | sed -n '1p')
nvram set goflyway_v="$goflyway_v"
logger -t "【goflyway】" "运行 goflyway"

#运行脚本启动/opt/bin/goflyway
chmod 777 /etc/storage/app_7.sh
cd $(dirname `which goflyway`)
eval "/etc/storage/app_7.sh $cmd_log" &

sleep 4
[ ! -z "$(ps -w | grep "goflyway" | grep -v grep )" ] && logger -t "【goflyway】" "启动成功" && goflyway_restart o
[ -z "$(ps -w | grep "goflyway" | grep -v grep )" ] && logger -t "【goflyway】" "启动失败, 注意检查端口是否有冲突,程序是否下载完整,10 秒后自动尝试重新启动" && sleep 10 && goflyway_restart x
initopt


#goflyway_get_status
eval "$scriptfilepath keep &"
exit 0
}

update_chnlist () {
nvram set app_111=4 && Sh99_ss_tproxy.sh
cat /opt/app/ss_tproxy/rule/chnlist.txt | grep -v '^#' | sed -e 's@^cn$@com.cn@g' | sort -u | grep -v "^$" > /opt/bin/chinalist.txt

}

initopt () {
optPath=`grep ' /opt ' /proc/mounts | grep tmpfs`
[ ! -z "$optPath" ] && return
if [ ! -z "$(echo $scriptfilepath | grep -v "/opt/etc/init")" ] && [ -s "/opt/etc/init.d/rc.func" ] ; then
	{ echo '#!/bin/bash' ; echo $scriptfilepath '"$@"' '&' ; } > /opt/etc/init.d/$scriptname && chmod 777  /opt/etc/init.d/$scriptname
fi

}

initconfig () {
	if [ ! -f "/etc/storage/app_7.sh" ] || [ ! -s "/etc/storage/app_7.sh" ] ; then
cat > "/etc/storage/app_7.sh" <<-\VVR
#!/bin/bash
# 启动运行的脚本
export PATH='/etc/storage/bin:/tmp/script:/etc/storage/script:/opt/usr/sbin:/opt/usr/bin:/opt/sbin:/opt/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin'
export LD_LIBRARY_PATH=/lib:/opt/lib
# https://github.com/coyove/goflyway/wiki/使用教程
cd $(dirname ` which goflyway`)
#在服务器执行下面命令即可启动服务端，KEY123为自定义密码，默认监听8100。本地执行
#./goflyway -t 0 -k=KEY123 -l="0.0.0.0:8100" 2>&1 &

#客户端命令（1.2.3.4要修改为服务器IP，默认监听8100）
goflyway -t 0 -k=KEY123 -up="1.2.3.4:8100" -l="0.0.0.0:8100" 2>&1 &

#可以配合 Proxifier、chrome(switchysharp、SwitchyOmega) 代理插件使用
#请设置以上软件的本地代理为 192.168.123.1:8100（协议为HTTP或SOCKS5代理，192.168.123.1为路由器IP）

VVR
	fi

}

initconfig

update_app () {
mkdir -p /opt/app/goflyway
if [ "$1" = "update_asp" ] ; then
	rm -rf /opt/app/goflyway/Advanced_Extensions_goflyway.asp
fi
if [ "$1" = "del" ] ; then
	rm -rf /opt/app/goflyway/Advanced_Extensions_goflyway.asp
	[ -f /opt/bin/goflyway ] && rm -f /opt/bin/goflyway /opt/bin/chinalist.txt /etc/storage/app_7.sh
	[ -f "$capem_s_path" ] && rm -f  "$keypem_s_path" "$capem_s_path" "$keypem_path" "$capem_path"
	rm -f /opt/opt_backup/bin/goflyway /opt/opt_backup/bin/key.pem /opt/opt_backup/bin/ca.pem

fi

initconfig

# 加载程序配置页面
if [ ! -f "/opt/app/goflyway/Advanced_Extensions_goflyway.asp" ] || [ ! -s "/opt/app/goflyway/Advanced_Extensions_goflyway.asp" ] ; then
	wgetcurl.sh /opt/app/goflyway/Advanced_Extensions_goflyway.asp "$hiboyfile/Advanced_Extensions_goflywayasp" "$hiboyfile2/Advanced_Extensions_goflywayasp"
fi
umount /www/Advanced_Extensions_app07.asp
mount --bind /opt/app/goflyway/Advanced_Extensions_goflyway.asp /www/Advanced_Extensions_app07.asp
# 更新程序启动脚本

[ "$1" = "del" ] && /etc/storage/www_sh/goflyway del &
}

case $ACTION in
start)
	goflyway_close
	goflyway_check
	;;
check)
	goflyway_check
	;;
stop)
	goflyway_close
	;;
updateapp7)
	goflyway_restart o
	[ "$goflyway_enable" = "1" ] && nvram set goflyway_status="updategoflyway" && logger -t "【goflyway】" "重启" && goflyway_restart
	[ "$goflyway_enable" != "1" ] && nvram set goflyway_v="" && logger -t "【goflyway】" "更新" && update_app del
	;;
update_app)
	update_app
	;;
update_asp)
	update_app update_asp
	;;
keep)
	#goflyway_check
	goflyway_keep
	;;
initconfig)
	initconfig
	;;
*)
	goflyway_check
	;;
esac

