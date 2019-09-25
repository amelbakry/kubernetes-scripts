#!/bin/bash

        ######################################################################################
	# Script to check the health status of Deployment and resources assosiated with it   #
	# ####################################################################################


# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
PLAIN='\033[0m'
bold=$(tput bold)
normal=$(tput sgr0)

deploy="$2"
namespace="$1"

if [ $# -ne 2 ]; then
    echo "usage: $0 <namespace> <deployment>"
    exit 1
fi

var=$(kubectl get deployment -n ${namespace} --output=json ${deploy} | \
             jq -j '.spec.selector.matchLabels | to_entries | .[] | "\(.key)=\(.value),"')
selector=${var%?}

pod_status() {
	no_of_pods=$(kubectl get po -n $namespace -l $selector | grep -v NAME | wc -l)
             if [[ $no_of_pods -eq 0 ]]
             then
               echo "Deployment $deploy has 0 replicas"
               exit 0
             fi
	pods_status=$(for i in $(kubectl get po -n $namespace -l $selector | grep -v NAME | awk {'print $3'} | sort -u); do echo "$i";done)
	restart_count=$(kubectl get po -n $namespace -l $selector | grep -v NAME | awk {'print $4'} | grep -v RESTARTS | sort -ur | awk 'FNR <= 1')
        echo -e "${BLUE}"Number of Pods"            :${GREEN}$no_of_pods"
        echo -e "${BLUE}"Pods Status"               :${GREEN}$pods_status"
        echo -e "${BLUE}"MAX Pod Restart Count"     :${GREEN}$restart_count"
	readiness() {
		r=$(kubectl get po -n $namespace | grep $deploy | grep -vE '1/1|2/2|3/3|4/4|5/5|6/6|7/7' &> /dev/null )
	        if [[ $? -ne 0 ]]
	        then
	          echo -e "${BLUE}"Readiness"                 :${GREEN}"ALL Pods are Ready""
	        else
		  echo -e "${BLUE}"Readiness"                 :${RED}"You have some Pods not ready ""
                fi
              }
        readiness

}
pod_distribution() {
        echo -e "\e[1m\e[39mPod Distribution per Node\e[21m"
	for nodes in $(kubectl get po -n $namespace -l $selector -o wide | grep $deploy | awk {'print $7'} | sort -u)
	   do
             echo -e "${BLUE}$nodes \t \t :${GREEN}$(kubectl describe node $nodes | grep $deploy | wc -l)"
	done
	echo -e "\e[1m\e[39mNode Distribution per Availability Zone\e[21m"
        node_dist=$(for node in $(kubectl get po -n $namespace -l $selector -o wide | grep $deploy | awk {'print $7'} | sort -u)
                    do kubectl get node --show-labels $node
		    done | awk {'print $6'} | grep -v LABELS)
	a=$(echo $node_dist | grep -o eu-central-1a | wc -l)
	b=$(echo $node_dist | grep -o eu-central-1b | wc -l)
	c=$(echo $node_dist | grep -o eu-central-1c | wc -l)
	echo -e "${BLUE}"eu-central-1a" \t \t :${GREEN}$a"
	echo -e "${BLUE}"eu-central-1b" \t \t :${GREEN}$b"
	echo -e "${BLUE}"eu-central-1c" \t \t :${GREEN}$c"

}

pod_utilization() {

        cpulimit=$(kubectl describe node | grep $(kubectl get po -n ${namespace} -l ${selector} | grep -v NAME | \
              awk {'print $1'} | head -n1) | awk {'print $5'} | grep -Ev "^$" | sort -u | \
              awk '{ if ($0 ~ /[0-9]*m/) print $0; else print $0*1000;}' | sed 's/[^0-9]*//g')

	memlimit=$(kubectl describe node | grep $(kubectl get po -n ${namespace} -l ${selector} | grep -v NAME | \
                             awk {'print $1'} | head -n1) | awk {'print $9'} | grep -Ev "^$" | sort -u | \
                             awk '{ if ($0 ~ /[0-9]*Gi/) print $0*1024; else if ($0 ~ /[0-9]*G/) print $0*1000; \
                             else if ($0 ~ /[0-9]*M/ || $0 ~ /[0-9]*Mi/) print $0 ; else print $0}' | sed 's/[^0-9]*//g')
	dcores=$(kubectl top pods  -n $namespace | grep $deploy | awk {'print $2'} | sed 's/[^0-9]*//g' | awk '{n += $1}; END{print n}')
	dmem=$(kubectl top pods  -n $namespace | grep $deploy | awk {'print $3'} | sed 's/[^0-9]*//g' | awk '{n += $1}; END{print n}')


	if [ $cpulimit -eq 0 ]
	then
	  echo -e "\e[1m\e[33mWARN: Pods do not have CPU Limits\e[21m"
        else
           echo -e "\e[1m\e[39mAverage Utilization \e[21m"
           deploymentcpu=$(bc <<< "scale=2;$dcores/($cpulimit*$no_of_pods)*100")
           echo -e "${BLUE}"CPU Utilization"                   :${GREEN}$deploymentcpu%"
           if [ $memlimit -ne 0 ]
           then
             deploymentmem=$(bc <<< "scale=2;$dmem/($memlimit*$no_of_pods)*100")
             echo -e "${BLUE}"Memory Utilization"                :${GREEN}$deploymentmem%"
           fi
    	   echo -e "\e[1m\e[39mTop Pods CPU Utilization\e[21m"
    	   kubectl top pods -n $namespace -l $selector | grep -v NAME| \
           awk 'FNR <= 5'  | awk {'print $1,$2'}| awk '$2=($2/'$cpulimit')*100"%"' | \
   	   awk '{printf $1 " " "%0.2f\n",$2}' | sort -k2 -r | \
    	   awk -v OFS='\t' '{if ($2 >= 80) print "\033[0;36m"$1," ", "\033[0;31m"":"$2"%"; else print "\033[0;36m"$1," ","\033[0;32m"":"$2"%";}'
        fi
	if [ $memlimit -eq 0 ]
        then
	  echo -e "\e[1m\e[33mWARN: Pods do not have Memory Limits\e[21m"
        else
	   echo -e "\e[1m\e[39mTop Pods Memory Utilization\e[21m"
	   kubectl top pods -n $namespace -l $selector | grep -v NAME | \
           awk 'FNR <= 5' | awk {'print $1,$3'} | awk '$2=($2/'$memlimit')*100"%"' | \
           awk '{printf $1 " " "%0.2f\n",$2}' | sort -k2 -r | \
	   awk -v OFS=' \t' '{if ($2 >= 80) print "\033[0;36m"$1," ", "\033[0;31m"":"$2"%"; else print "\033[0;36m"$1," ","\033[0;32m"":"$2"%";}'
        fi
}

clear
kubectl get deploy $deploy -n $namespace &> /dev/null
status=$?
if [ $status -ne 0 ]; then
  echo -e "Deployment $deploy not exist. \nPlease make sure you provide the correct deployment name and the correct namespace"
  exit $status
fi
echo -e "\e[1m\e[39mChecking Deployment $deploy...\e[21m"
pod_status
pod_utilization
pod_distribution


