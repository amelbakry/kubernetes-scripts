#!/bin/bash

echo -e "\e[1m\e[39mThese Deployments that do not have Limits configured\e[21m"
namespaces=$(kubectl get ns | awk {'print $1'} | grep -v NAME)
for namespace in $namespaces
   do
       echo -e "\e[1m\e[39mNamespace: $namespace\e[21m"
       deployments=$(kubectl get deploy -n $namespace | awk {'print $1'} | grep -v NAME)
       for deploy in $deployments
            do

               var=$(kubectl get deployment -n ${namespace} --output=json ${deploy} | \
                           jq -j '.spec.selector.matchLabels | to_entries | .[] | "\(.key)=\(.value),"')
               selector=${var%?}

               if [ $((kubectl get po -n ${namespace} -l ${selector} | grep -v NAME | wc -l)  2> /dev/null ) -eq 0 ]
                  then
                     continue
               fi
               cpulimit=$(kubectl describe node | grep $(kubectl get po -n ${namespace} -l ${selector} | grep -v NAME | \
                                   awk {'print $1'} | head -n1) | awk {'print $5'} | grep -Ev "^$" | sort -u  |  \
                                   awk '{ if ($0 ~ /[0-9]*m/) print $0; else print $0*1000;}' | sed 's/[^0-9]*//g')
               if [ $cpulimit -eq 0 ]
                    then
                        echo $deploy
               fi

    done
done
