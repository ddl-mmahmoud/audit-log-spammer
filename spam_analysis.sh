#!/bin/bash -e
tmp="$(mktemp -d)"

platform_ns="$(kubectl get ns -l domino-platform -o json | jq -r '.items[0].metadata.name')"
mongo_password="$(kubectl get secret -n "$platform_ns" audit-trail-mongodb-bitnami-mongodb-svcbind-0 -o json | jq -r '.data.password | @base64d')"

pod_name="$(kubectl get pod -n "$platform_ns" -l job-name=nucleus-test-log-spammer -o json | jq -r '.items[0].metadata.name')"

last_event="$(kubectl logs -n "$platform_ns" "$pod_name" --tail=1 --timestamps)"
job_id="$(grep -oP '(?<=FAKE job )\S+' <<< "$last_event")"


_mongo_eval () {
    kubectl exec -n "$platform_ns" svc/audit-trail-mongodb-bitnami-mongodb-headless -- \
        mongo --quiet -u audit -p "$mongo_password" audit_events \
        --eval "$@"
}


_hms_convert () {
    perl -ne 'm/(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?\s*$/ && print($1*3600 + $2*60 + $3)'
}


while true; do
    last_event="$(kubectl logs -n domino-platform "$pod_name" --tail=1 --timestamps)"
    event_seq_num="$(grep -oP '(?<=event )\d+' <<< "$last_event")"

    start_ts="$(date +%s)"
    end_poll="$(( $start_ts + 60 ))"

    i=0
    while [ "$(date +%s)" -lt "$end_poll" ]; do
        found="$(_mongo_eval 'db.events.findOne({"action.eventName": "FAKE job '"$job_id"' event '"$event_seq_num"'"})')"
        (grep "^null" <<< "$found" >/dev/null) || break
        sleep 0.01
        i="$(( $i + 1 ))"
    done

    now="$(date +%s)"
    duration="$(( "$(date +%s)" - "$start_ts" ))"
    mock_action_count="$(_mongo_eval 'db.events.find({"action.eventName": {"$regex": "FAKE"}}).count()')"
    kubectl get pods -A | grep nucleus-test-log-spammer > "$tmp/pod_listing"
    num_scheduled="$(wc -l < "$tmp/pod_listing")"
    num_ready="$(grep Running < "$tmp/pod_listing" | wc -l)"
    sample_uptime="$(grep Running < "$tmp/pod_listing" | tail -n1 | _hms_convert)"
    est_ingest_rate="$(perl -e "print($mock_action_count/$sample_uptime . qq(\n))")"

    cat <<EOF
---
date: $(date -d@$now -Is)
timestamp: $now
ready: $num_ready
scheduled: $num_scheduled
sample_uptime: $sample_uptime
mock_action_count: $mock_action_count
est_ingest_rate: $est_ingest_rate
ingest_lag_iterations: $i
ingest_lag_seconds: $duration

EOF

    sleep 10
done
