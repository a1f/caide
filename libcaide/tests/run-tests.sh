#!/bin/bash
set -e
set -u

cur_dir=$( cd $(dirname "${BASH_SOURCE[0]}") ; pwd )
[ -d $cur_dir ] || exit 420

tmp_dir=$cur_dir/tmp
export caide=$cur_dir/../dist/build/caide/caide
# On Windows use something like CSC=/c/Windows/Microsoft.NET/Framework/v4.0.30319/csc.exe ./run-tests.sh
CSC=${CSC:-gmcs}
export CSC

functions_file=$cur_dir/test-functions.sh

mkdir -p $tmp_dir

failed=0
passed=0
failed_tests=""
shopt -s nullglob

if [ "$#" -eq 0 ]; then
    tests=($( cd $cur_dir ; ls *.test ))
else
    tests=( "$@" )
fi

for f in "${tests[@]}"
do
    echo " == Running $f... =="
    full_test_path=$cur_dir/$f
    export etalon_dir=$cur_dir/${f%.test}
    work_dir=$tmp_dir/${f%.test}
    rm -rf $work_dir

    if [ -d $etalon_dir/init ] ; then
        cp -R $etalon_dir/init $work_dir
    else
        mkdir -p $work_dir
    fi

    cd $work_dir

    if bash -e -c "source $cur_dir/test-functions.sh; source $full_test_path" ; then
        echo " == Passed =="
        passed=$((passed+1))
    else
        echo " == Failed =="
        failed=$((failed+1))
        failed_tests="$failed_tests $f"
    fi

done

echo "$passed test(s) passed, $failed test(s) failed"
echo "$failed_tests"

exit $failed

