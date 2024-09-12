#!/bin/bash
#
# Provide the analysis output to this on STDOUT
#

yq -s . | jq -r '(.[0] | keys_unsorted), (.[] | [.[]]) | @csv'
