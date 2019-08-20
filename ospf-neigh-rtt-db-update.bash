#!/usr/bin/env bash

# Title               : ospf-neigh-rtt-db-update
# Last modified date  : 23.03.2019
# Author              : jumation.com
# Description         : Script pulls the latest revision of list of Juniper
#                       routers from the git server, queries OSPF neighbors
#                       RTT measurements from each router via SNMP and creates,
#                       updates or removes the RRDtool databases and graphs.
# Options             :
# Notes               : Requires JUNIPER-UTIL-MIB.
#                       As transport protocol for git server is SSH, then
#                       git server host key needs to be added to known_hosts
#                       file. Otherwise, the host key verification fails and
#                       thus git commands fail.
#                       Script expects the instance name to follow a similar
#                       format: "rtt_<neigh_ip>_<local_IFL>_<local_IFL_descr>".
#                       Script is meant to be run using cron with at least
#                       five minute intervals on modern Linux distribution.


# Discard the stdout and send stderr to syslog.
exec >/dev/null 2> >(logger -p "user.err" -i -t "${0##*/}")

exit_f() {
	logger -p "user.err" -i -t "${0##*/}" -- "$1"
	exit 1
}


dir=$HOME/ospf_neigh_rtt
jrouters=$dir/routerslists/jrouters.txt


if [[ ! -d $dir ]]; then
	mkdir -p "$dir" || exit_f "Unable to create $dir directory"
fi

if [[ -d $dir/routerslists ]]; then

	# Fetch and merge routerslists repository from git server
	# where respective Gitolite user has a read-only access for this
	# repo. Transport protocol is SSH.
	git -C "$dir/routerslists" pull --ff-only || \
	exit_f "Git pull failed"
else

	git clone git@git-server:routerslists.git "$dir/routerslists" || \
	exit_f "Git clone failed"
fi

[[ -f $jrouters ]] || exit_f "${jrouters##*/} file missing"


# As IFS has its default value, then read strips all possible leading and
# trailing whitespace(tab or space character).
while read -r rtr; do

	# Ignore comments and empty lines.
	if [[ $rtr =~ ^# ]] || [[ $rtr =~ ^$ ]]; then
		continue
	fi

	while IFS=\'\" read -r _ instance _ value; do

		# Sanity check that instance name starts with "rtt_" prefix.
		if [[ $instance =~ ^rtt_ ]]; then

			IFS=_ read -r _ n_ip int_name int_descr <<< "$instance"
			rrd=$dir/${rtr}_${int_name//\//-}_$n_ip.rrd

			if [[ ! -f $rrd ]]; then
				# Stores RTT readings for one week.
				# As RRA steps is 1, then XFF doesn't matter.
				rrdtool create "$rrd" \
					--start "N" --step "300" "DS:rtt:GAUGE:600:0:1000" \
					"RRA:AVERAGE:0:1:2016"
			fi

			# Sanity check that value is a number. If it isn't, then
			# update the database with "unknown".
			if [[ $value =~ ^[0-9\.]+$ ]]; then
				rrdtool update "$rrd" N:"$value"
			else
				rrdtool update "$rrd" N:U
			fi

			# Timestamp to use in the graph watermark string.
			# Make sure, that time zone is correct.
			time=$(date "+on %F at %T UTC")

			# Depending on the interface naming convention, it might
			# be more suitable to use the hostname in the title of
			# the graph, e.g:
			#
			#   read -r ip name < <(getent hosts "$n_ip")
			#   name=${name%%.*}
			#   [[ x$name == x ]] && name="$n_ip"

			# Pattern substitution is used to escape colons because rrdtool
			# uses colons as field separators.
			rrdtool graph "${rrd%.rrd}".png \
				--title "$int_name $rtr <-> $int_descr RTT" \
				--vertical-label "RTT(ms)" \
				--width "500" \
				--height "200" \
				--start end-2d \
				--watermark ":: Graph generated $time / noc@example.net ::" \
				--slope-mode \
				--lower-limit 0 \
				--units-exponent 0 \
				--font "DEFAULT:7:" \
				"DEF:rtt_def=${rrd//:/\\:}:rtt:AVERAGE" \
				"CDEF:shading2=rtt_def,0.98,*" "AREA:shading2#0287ca:RTT" \
				"GPRINT:rtt_def:AVERAGE:Avg\: %5.2lf ms" \
				"GPRINT:rtt_def:MAX:Max\: %5.2lf ms" \
				"GPRINT:rtt_def:MIN:Min\: %5.2lf ms" \
				"GPRINT:rtt_def:LAST:Last\: %5.2lf ms\t\n" \
				"CDEF:shading5=rtt_def,0.95,*" "AREA:shading5#0c8bcc" \
				"CDEF:shading10=rtt_def,0.90,*" "AREA:shading10#1690ce" \
				"CDEF:shading15=rtt_def,0.85,*" "AREA:shading15#2195d0" \
				"CDEF:shading20=rtt_def,0.80,*" "AREA:shading20#2b9ad2" \
				"CDEF:shading25=rtt_def,0.75,*" "AREA:shading25#359fd4" \
				"CDEF:shading30=rtt_def,0.70,*" "AREA:shading30#40a4d6" \
				"CDEF:shading35=rtt_def,0.65,*" "AREA:shading35#4aa9d9" \
				"CDEF:shading40=rtt_def,0.60,*" "AREA:shading40#54aedb" \
				"CDEF:shading45=rtt_def,0.55,*" "AREA:shading45#5fb3dd" \
				"CDEF:shading50=rtt_def,0.50,*" "AREA:shading50#69b7df" \
				"CDEF:shading55=rtt_def,0.45,*" "AREA:shading55#74bce1" \
				"CDEF:shading60=rtt_def,0.40,*" "AREA:shading60#7ec1e3" \
				"CDEF:shading65=rtt_def,0.35,*" "AREA:shading65#88c6e6" \
				"CDEF:shading70=rtt_def,0.30,*" "AREA:shading70#93cbe8" \
				"CDEF:shading75=rtt_def,0.25,*" "AREA:shading75#9dd0ea" \
				"CDEF:shading80=rtt_def,0.20,*" "AREA:shading80#a7d5ec" \
				"CDEF:shading85=rtt_def,0.15,*" "AREA:shading85#b2daee" \
				"CDEF:shading90=rtt_def,0.10,*" "AREA:shading90#bcdff0" \
				"CDEF:shading95=rtt_def,0.05,*" "AREA:shading95#c7e4f3" \
				"COMMENT: \n"
		fi
	done < <(snmpwalk -v 2c -c public "$rtr" jnxUtilStringValue.114.116.116.95)
done < "$jrouters"

# Remove RRD and PNG files which have not been updated for more than three days.
# This usually happens when OSPF neighbor has been removed.
find "$dir" -maxdepth 1 -type f \( -name "*.rrd" -o -name "*.png" \) \
	-mtime +3 -execdir rm -f {} +
