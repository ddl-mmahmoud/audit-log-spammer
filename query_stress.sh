#!/bin/bash -e

provided_args="$*"

prefix="$(dirname -- "$(readlink -f "$0")")"

_cleanup () {
    [ -n "$spam_analysis_pid" ] && kill "$spam_analysis_pid"
}

trap _cleanup EXIT


while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            sed -n '/^while/,/^done/p' "$0" | grep -oP '\S+(?=\)$)'
            exit 0
            ;;
        --url)
            url="$2"
            shift 2
            ;;
        --api-key)
            api_key="$2"
            shift 2
            ;;
        --concurrency)
            concurrency="$2"
            shift 2
            ;;
        --query)
            query="$2"
            shift 2
            ;;
        --time)
            time="$2"
            shift 2
            ;;
        --workers)
            workers="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

results="$HOME/audit-trail-perf-results"

mkdir -p "$results"

batch_id="$(uuidgen)"
batch_dir="$results/query-perf/$batch_id"
mkdir -p "$batch_dir"
meta="$batch_dir/description.nldjson"


run="run.$(date +%s)"
echo "run: $batch_id/$run" >&2

echo "$provided_args" > "$batch_dir/$run.stress.trigger"
bash "$prefix/run_series.sh" --duration "$(( $time * 2 ))" "$workers" | tee -a "$batch_dir/$run.stress.trigger" &

sleep "$(( $time / 2 ))"
bash -c 'echo $$>'"$batch_dir/spam_pid && $prefix/spam_analysis.sh" | tee "$batch_dir/$run.stress.measure" &
spam_analysis_pid="$(cat "$batch_dir/spam_pid")"

ab -t "$time" -c "$concurrency" -H"X-Domino-Api-Key: $api_key" "$url/api/audittrail/v1/auditevents?$query" | tee "$batch_dir/$run.log"
_cleanup

echo && echo && echo
echo "run: $batch_id/$run"
