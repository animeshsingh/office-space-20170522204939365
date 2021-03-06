#!/bin/bash

echo "Creating Office Space App"

IP_ADDR=$(bx cs workers $CLUSTER_NAME | grep normal | awk '{ print $2 }')
if [ -z $IP_ADDR ]; then
  echo "$CLUSTER_NAME not created or workers not ready"
  exit 1
fi

echo -e "Configuring vars"
exp=$(bx cs cluster-config $CLUSTER_NAME | grep export)
if [ $? -ne 0 ]; then
  echo "Cluster $CLUSTER_NAME not created or not ready."
  exit 1
fi
eval "$exp"

kubectl delete --ignore-not-found=true -f account-database.yaml
kubectl delete --ignore-not-found=true -f account-summary.yaml
kubectl delete --ignore-not-found=true -f compute-interest-api.yaml
kubectl delete --ignore-not-found=true -f transaction-generator.yaml
kuber=$(kubectl get pods -l app=office-space)
while [ ${#kuber} -ne 0 ]
do
    sleep 5s
    kubectl get pods -l app=office-space
    kuber=$(kubectl get pods -l app=offce-space)
done

echo "Creating MySQL Database..."
kubectl create -f account-database.yaml
echo "Creating Spring Boot App..."
kubectl create -f compute-interest-api.yaml
sleep 5s
echo "Creating Node.js Frontend..."
kubectl create -f account-summary.yaml
while [ $? -ne 0 ]
do
    sleep 1s
    echo "Creating Node.js Frontend failed. Trying to recreate..."
    COUNT=$(cat account-summary.yaml | grep 30080 | sed -e s#nodePort:## | xargs)
    COUNTUP=$((COUNT+1))
    sed -i s#$COUNT#$COUNTUP# account-summary.yaml
    kubectl apply -f account-summary.yaml
    echo $?
done

echo "Creating Transaction Generator..."
kubectl create -f transaction-generator.yaml
sleep 5s

echo "Getting IP and Port"
kubectl get nodes
NODEPORT=$(kubectl get svc | grep account-summary | awk '{print $4}' | sed -e s#80:## | sed -e s#/TCP##)
kubectl get svc | grep account-summary
if [ -z "$NODEPORT" ]
then
    echo "NODEPORT not found"
    exit 1
fi
kubectl get pods,svc -l app=office-space
echo "You can now view your account balance at http://$IP_ADDR:$NODEPORT"
