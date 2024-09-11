#!/bin/bash

wait="${SPAM_WAIT_MILLISECONDS:-1000}"

i=0

while true; do
  t="$(date +%s)"
  ts="$(( 1000*$t ))"
  fancy="$(date -d@$t +%Y-%m-%dT%H:%M:%S.000+00:00)"
  uuid="$(uuidgen)"
  stdbuf -o0 cat <<EOF
{"@timestamp":"$fancy","@version":1,"message":"{\"timestamp\":$ts,\"actor\":{\"id\":\"66e09389376334846320bb45\",\"name\":\"integration-test\"},\"action\":{\"eventName\":\"Launch Job\",\"using\":[{\"entityType\":\"eventSource\",\"id\":\"Web\",\"tags\":[]}],\"traceId\":\"$uuid\"},\"targets\":[{\"entity\":{\"entityType\":\"job\",\"id\":\"66e10476fd530420ac0b5e96\",\"tags\":[]},\"fieldChanges\":[]}],\"affecting\":[],\"in\":{\"entityType\":\"project\",\"id\":\"66e09e20e7cdcc450b36c73c\",\"tags\":[]},\"metadata\":{}}","logger_name":"audit-event","thread_name":"application-akka.actor.default-dispatcher-201","level":"INFO","level_value":20000,"application.home":"/opt/domino-nucleus"}
EOF
  sleep "$(echo "scale=4; $wait/1000" | bc)"
  i="$(( $i + 1 ))"
done
