#!/bin/bash -e

tmp="$(mktemp -d)"

platform_ns="$(kubectl get ns -l domino-platform -o json | jq -r '.items[0].metadata.name')"
mongo_password="$(kubectl get secret -n "$platform_ns" audit-trail-mongodb-bitnami-mongodb-svcbind-0 -o json | jq -r '.data.password | @base64d')"

_mongo () {
    kubectl exec -n "$platform_ns" audit-trail-mongodb-bitnami-mongodb-0 -- mongo --quiet -u audit -p "$mongo_password" audit_events "$@"
}


_cleanup () {
    kubectl delete job -n "$platform_ns" "nucleus-test-log-spammer"
    _mongo --eval 'db.events.remove({"action.eventName": {"$regex": "FAKE"}})'
    num_found="$(_mongo --eval 'db.events.find({"action.eventName": {"$regex": "FAKE"}}).count()')"
    while [ "$num_found" -gt 0 ]; do
        _mongo --eval 'db.events.remove({"action.eventName": {"$regex": "FAKE"}})'
        num_found="$(_mongo --eval 'db.events.find({"action.eventName": {"$regex": "FAKE"}}).count()')"
        sleep 1
    done
}

trap _cleanup EXIT


duration=300

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            sed -n '/^while/,/^done/p' "$0" | grep -oP '\S+(?=\)$)'
            exit 0
            ;;
        -d|--duration|--duration-seconds)
            duration="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done



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
    _cleanup
    sed -e "s/parallelism: .*/parallelism: $parallelism/" log_spammer.job.yaml > "$tmp/this_run.yaml"
    kubectl apply -n domino-platform -f "$tmp/this_run.yaml"
    sleep "$duration"
    _cleanup
    i="$(( $i + 1 ))"
done
