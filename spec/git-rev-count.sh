#!/bin/bash

if [ "$#" != "2" ]; then
    echo "Illegal number of arguments. You need to provide 2 arguments:"
    echo " - repository"
    echo " - branch"
    exit
fi

REPO="$1"
BRANCH=$2

if [[ "$BRANCH" == 'uat' ]]; then
    test_left=$(git rev-list --left-only --count origin/test...origin/uat)
    test_right=$(git rev-list --right-only --count origin/test...origin/uat)
    if [[ $test_right -gt $test_left ]]; then
        echo -e "*Reason*: \`You are trying to go ahead of test from uat\`\nPlease commit to test first" > /home/gitlab-runner/${REPO}_rev_count_msg.txt
        exit 1
    fi
elif [[ "$BRANCH" == 'production' ]]; then
    uat_left=$(git rev-list --left-only --count origin/uat...origin/production)
    uat_right=$(git rev-list --right-only --count origin/uat...origin/production)
    if [[ $uat_right -gt $uat_left ]]; then
        echo -e "*Reason*: \`You are trying to go ahead of test/uat from production\`\nPlease commit to test/uat first" > /home/gitlab-runner/${REPO}_rev_count_msg.txt
        exit 1
    fi
fi

truncate -s 0 /home/gitlab-runner/${REPO}_rev_count_msg.txt
