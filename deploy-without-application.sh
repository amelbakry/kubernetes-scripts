#!/bin/bash

echo -e "\e[1m\e[39mThese Deployments do not have Application in the Labels\e[21m"
namespaces=$(kubectl get ns | awk {'print $1'} | grep -v NAME)
for namespace in $namespaces
   do
        echo -e "\e[1m\e[39mNamespace: $namespace\e[21m"
         deployments=$(kubectl get deploy -n $namespace | awk {'print $1'} | grep -v NAME)
         for deploy in $deployments
            do

               var=$(kubectl get deployment -n ${namespace} --output=json ${deploy} | \
                           jq -j '.metadata.labels  | to_entries | .[] | "\(.key)=\(.value),"')
               labels=${var%?}

               echo $labels | grep application &> /dev/null
               status=$?
               if [ $status -ne 0 ]
                  then
                     echo $deploy
               fi


    done
done
