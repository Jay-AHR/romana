#!/bin/bash
# Contributed by Robert Starmer


# Warning. This script currently utilizes custom 
# docker images for nginx and curl.
# This need to change.

apt-get install tmux pv -y

readonly  reset=$(tput sgr0)
readonly  green=$(tput bold; tput setaf 2)
readonly yellow=$(tput bold; tput setaf 3)
readonly   blue=$(tput bold; tput setaf 6)

function desc() {
    maybe_first_prompt
    echo "$blue# $@$reset"
    prompt
}

function prompt() {
    echo -n "$yellow\$ $reset"
}

started=""
function maybe_first_prompt() {
    if [ -z "$started" ]; then
        prompt
        started=true
    fi
}

function get_pod_ip() {
    kubectl get pod "$1" -o json | jq -r '.status.podIP'
}

function run() {
    maybe_first_prompt
    rate=25
    if [ -n "$DEMO_RUN_FAST" ]; then
      rate=1000
    fi
    echo "$green$1$reset" | pv -qL $rate
    if [ -n "$DEMO_RUN_FAST" ]; then
      sleep 0.5
    fi
    eval "$1"
    r=$?
    read -d '' -t 0.1 -n 10000 # clear stdin
    prompt
    if [ -z "$DEMO_AUTO_RUN" ]; then
      read -s
    fi
    return $r
}

function relative() {
    for arg; do
        echo "$(realpath $(dirname $(which $0)))/$arg" | sed "s|$(realpath $(pwd))|.|"
    done
}

SSH_NODE=$(kubectl get nodes | tail -1 | cut -f1 -d' ')

trap "echo" EXIT


cd /home/ubuntu
##### DEMO  ######
desc "Get a list of nodes in the environment"
run "kubectl get nodes"

desc "anybody here? let's see if we have a pod"
run "romana/kubernetes/get-pods.sh"

desc "How about we stand up a few pods with a resource controller"
run "kubectl create -f romana/kubernetes/example-controller.yaml"

desc "anybody here now?"
run "romana/kubernetes/get-pods.sh"

desc "create a pod on 'frontend' segment in 't1' tenant/owner"
run "kubectl create -f romana/kubernetes/pod-frontend.yaml"

desc "create a pod on 'backend' segment in 't1' tenant/owner"
run "kubectl create -f romana/kubernetes/pod-backend.yaml"

desc "Let’s find out where the pods are"
run "sleep 15; romana/kubernetes/get-pods.sh"

desc "we should only see our 'internal' local interface"
run "kubectl exec nginx-frontend -- ip a"

desc "Let's look at the state in the frontend segment"
run "kubectl exec nginx-frontend -- curl $(get_pod_ip 'nginx-backend') --connect-timeout 5"

desc "apply the network policy to allow the frontend to connec to the backend"
run "curl -X POST -d @romana/kubernetes/romana-network-policy-request.json http://localhost:8080/apis/romana.io/demo/v1/namespaces/default/networkpolicys/"

desc "Let's look at the state in the frontend segment"
run "sleep 15; kubectl exec nginx-frontend -- curl $(get_pod_ip 'nginx-backend') --connect-timeout 5"

desc "Cleaning up"
run "sleep 15; kubectl delete rc nginx-default; kubectl delete pod nginx-frontend; kubectl delete pod nginx-backend; curl -X DELETE http://localhost:8080/apis/romana.io/demo/v1/namespaces/default/networkpolicys/pol1"
