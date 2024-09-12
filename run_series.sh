#!/bin/bash

tmp="$(mktemp -d)"

platform_ns="$(kubectl get ns -l domino-platform -o json | jq -r '.items[0].metadata.name')"
mongo_password="$(kubectl get secret -n "$platform_ns" audit-trail-mongodb-bitnami-mongodb-svcbind-0 -o json | jq -r '.data.password | @base64d')"

_mongo () {
    kubectl exec -it -n "$platform_ns" svc/audit-trail-mongodb-bitnami-mongodb-headless -- mongo --quiet -u audit -p "$mongo_password" audit_events "$@"
}


i=0
n="$#"
[ "$n" -eq 0 ] && { echo "Did not provide any parallelisms to use"; exit 1; }

for parallelism in "$@"; do
    now="$(date +%s)"
    cat <<EOF
---
date: $(date -d@$now -Is)
timestamp: $now
parallelism: $parallelism
iteration: $i
total_iterations: $n

EOF
    _mongo --eval 'db.events.remove({"action.eventName": {"$regex": "FAKE"}})'
    sed -e "s/parallelism: .*/parallelism: $parallelism/" log_spammer.job.yaml > "$tmp/this_run.yaml"
    kubectl apply -n domino-platform -f "$tmp/this_run.yaml"
    sleep 300
    kubectl delete -n domino-platform -f "$tmp/this_run.yaml"
    _mongo --eval 'db.events.remove({"action.eventName": {"$regex": "FAKE"}})'
    i="$(( $i + 1 ))"
done
