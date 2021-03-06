#!/bin/sh

T="$(date +%s%N)"

if [ "$(rpm -qa createrepo)" == "" ] ; then
	yum install createrepo -q -y
fi

yum clean all

CURRPATH=${PWD}
cd ${CURRPATH}

CURRBASENAME=${CURRPATH##*/}

if [ "${CURRBASENAME}" != "mratwork" ] ; then
	echo
	echo "* Your current path is '${CURRPATH}'"
	echo "  - Need path as '/home/rpms/<domain>/repo/mratwork'"
	echo "    where 'rpms' as client in Kloxo-MR 7.0"
	echo
	exit
fi

if [ "$(yum list *yum*|grep '@')" == "" ] ; then
	OPTIONS=""
else
	OPTIONS="--no-database --checksum=sha"
fi

if [ ! -d ${CURRPATH}/SRPMS ] ; then
	mkdir -p ${CURRPATH}/SRPMS
fi

chmod -R o-w+r ${CURRPATH}

echo "*** Delete old repodata dirs..."
find ${CURRPATH}/ -type d -name "repodata" -exec rm -rf {} \; >/dev/null 2>&1

echo "*** Process for SRPMS..."
createrepo ${OPTIONS} ${CURRPATH}/SRPMS

for type in release testing ; do
	for ver in centos5 centos6 centos7 neutral ; do
		for item in i386 x86_64 noarch ; do
			if [ ! -d ${CURRPATH}/${type}/${ver}/${item} ] ; then
				mkdir -p ${CURRPATH}/${type}/${ver}/${item}
			fi
			echo "*** Process for '${type}-${ver}-${item}'..."
			createrepo ${OPTIONS} ${CURRPATH}/${type}/${ver}/${item}
		done
	done
done

find ${CURRPATH}/ -type d -name ".repodata" -exec rm -rf {} \; >/dev/null 2>&1

cd ${CURRPATH}

sh /script/fix-chownchmod --client=rpms

## get mirror list
'rm' -f mratwork-SRPMS-mirrors.txt
wget -N -nH -nd https://github.com/mustafaramadhan/rpms/raw/master/mratwork/mirror/mratwork-SRPMS-mirrors.txt

echo "*** Request mirror..."

for i in $(cat mratwork-SRPMS-mirrors.txt|awk -F"/" '{print $3}'|tr '\n' ' ') ; do
	if [ "${i}" != 'rpms.mratwork.com' ] ; then
		## send for running reposync process in each mirror
		echo "- To ${i}"
		curl --head http://${i}/repo/mratwork/reposync.php >/dev/null 2>&1
	fi
done

# Time interval in nanoseconds
T="$(($(date +%s%N)-T))"
# Seconds
S="$((T/1000000000))"
# Milliseconds
M="$((T/1000000))"

echo ""
printf "*** Process Time: %02d:%02d:%02d:%02d.%03d (dd:hh:mm:ss:xxxxxx) ***\n" \
	"$((S/86400))" "$((S/3600%24))" "$((S/60%60))" "$((S%60))" "${M}"
echo ""

