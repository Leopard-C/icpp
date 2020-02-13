#!/bin/bash

## @descriptrion: A tool for writing c++ code temporarily and conveniently
## @author: iCrystal
## @e-mail: leopard.c@outlook.com

DEV_DIR=/home/icrystal/dev
THIS_FILE=$DEV_DIR/shell/icpp/icpp.sh
ICPP_HOME=/dev/shm/.icpp
CONFIG_DIR=$ICPP_HOME/.config
CONFIG_FILE=$CONFIG_DIR/icpprc
TRASH_DIR=$ICPP_HOME/.trash


function writeConfig()
{
    if [ $# -ne 4 ]; then return 1; fi
    sed -i "s/$1=$2/$1=$3/g" $4
}


function getID()
{
    if [ $# -ne 1 ]; then return 1; fi
    echo $1 | grep -o "^[0-9]*"
}

function getDirByName()
{
    count=`ls $ICPP_HOME | grep "$1" |wc -l`
    if [ $? -eq 0 ]; then
        if [ $count -eq 1 ]; then
            dir=`ls $ICPP_HOME | grep "$1"`
            echo $dir
        else
            return 2
        fi
    else
        return 1
    fi
}


function getDirByID()
{
    dir=`ls $ICPP_HOME | grep "^$1\."`
    if [ $? -eq 0 ]; then
        echo $dir
    fi
}

function compile()
{
    dir=`getDirByID $icpp_currID`
    source_file=$ICPP_HOME/$dir/main.cpp
    output_file=$ICPP_HOME/$dir/out
    if [ -e $source_file ]; then
        echo "g++ -o $output_file $source_file $@"
        g++ -o $output_file $source_file $@
        chmod +x $output_file
    else
        echo "ERROR: No source file found"
        return 1
    fi
}


function removeFirstParemeter()
{
    remain=""
    for i in $(seq 2 $(($#)))
    do
        eval para=$(echo '$'"$i")
        remain="$remain $para"
    done
    echo $remain
}


function main_func()
{
    if [ ! -d $CONFIG_DIR ]; then mkdir -p $CONFIG_DIR; fi
    if [ ! -e $CONFIG_FILE ]; then echo -e "icpp_currID=0\nicpp_maxID=0" > $CONFIG_FILE; fi

    source $CONFIG_FILE

    if [ $# -eq 0 ]; then
        dir=`getDirByID $icpp_currID`
        file=$ICPP_HOME/$dir/main.cpp
        if [ -e $file ]; then
            vim $file
        else
            $THIS_FILE new
        fi
        return 0
    fi

    case $1 in
    edit | e)
        line=0
        if [ $# -eq 1 ]; then
            line=`cat $THIS_FILE | grep -n main_func |head -1 | awk -F ':' '{print $1}'`
        elif [ $# -eq 2 ]; then
            line=`cat $THIS_FILE | grep -n "$2.*)" |head -1 | awk -F ':' '{print $1}'` 
        fi
        vim $THIS_FILE +$line
        ;;
    config | cfg)
        vim $CONFIG_FILE
        ;;
    home | h)
        echo -e "cd $ICPP_HOME\c" | xsel -ib
        ;;
    ls)
        dir=`getDirByID $icpp_currID`
        $@ $ICPP_HOME |grep -F "$dir" -A30 -B30 --color
        ;;
    ll)
        dir=`getDirByID $icpp_currID`
        ls -l $ICPP_HOME |grep -F "$dir" -A30 -B30 --color
        ;;
    pwd)
        dir=`getDirByID $icpp_currID`
        echo $dir
        ;;
    rename | rn | mv)
        if [ $# -eq 2 ]; then
            dir=`getDirByID $icpp_currID`
            new_dir="$icpp_currID.$2"
            mv $ICPP_HOME/$dir $ICPP_HOME/$new_dir
            echo "OK!"
        else
            echo "ERROR: command \"$1\" accept one parameter"
            return 1
        fi
        ;;
    cd)
        if [ $# -lt 2 ]; then
            echo "ERROR: command 'cd' accept one parameter"
            return 1
        fi

        dir=""
        echo $2 |grep -q "^[0-9]*$"
        if [ $? -eq 0 ]; then
            dir=`getDirByID $2`
        else
            dir=`getDirByName $2`
        fi

        ret=$?
        if [ $ret -eq 1 ]; then
            echo "ERROR: Not found the directory!"
            return 1
        elif [ $ret -eq 2 ]; then
            echo "ERROR: More than one directory found."
            ls $ICPP_HOME | grep "$2"
            return 2
        fi

        icpp_oldCurrID=$icpp_currID
        icpp_currID=`getID $dir`
        writeConfig icpp_currID $icpp_oldCurrID $icpp_currID $CONFIG_FILE
        echo "Now you are in directory: $dir"
        echo "OK!"
        ;;
    new)
        icpp_oldMaxID=$icpp_maxID
        icpp_oldCurrID=$icpp_currID
        let icpp_maxID=icpp_oldMaxID+1
        let icpp_currID=icpp_maxID
        writeConfig icpp_maxID $icpp_oldMaxID $icpp_maxID $CONFIG_FILE
        writeConfig icpp_currID $icpp_oldCurrID $icpp_currID $CONFIG_FILE
        icpp_curr_dir=""
        if [ $# -gt 1 ] && [ ! $2 = "-h" ]; then
            icpp_curr_dir="$ICPP_HOME/$icpp_maxID"".$2"
        else
            icpp_curr_dir="$ICPP_HOME/$icpp_maxID""."
        fi
        mkdir $icpp_curr_dir

        header="#include <iostream>"
        define="#define Log(x) std::cout << (x) << std::endl\n\n"
        main="int main() {\n\n\treturn 0;\n}\n"

        if [ $# -gt 2 ]; then
            if [ $2 = "-h" ]; then
                for i in $(seq 3 $#)
                do
                    eval new_header=$(echo '$'"$i")
                    header="$header\n#include <$new_header>"
                done
            elif [ $3 = "-h" ] && [ $# -gt 3 ]; then
                for i in $(seq 4 $#)
                do
                    eval new_header=$(echo '$'"$i")
                    header="$header\n#include <$new_header>"
                done
            fi
        fi

        echo -e "$header\n\n$define\n$main" > $icpp_curr_dir/main.cpp
        line=`cat $icpp_curr_dir/main.cpp |grep main -n |head -1 |awk -F ':' '{print $1}'`
        vim $icpp_curr_dir/main.cpp +$line
        ;;
    compile | build | b)
        flag=`removeFirstParemeter $@`
        compile $flag
        ;;
    run | r)
        dir=`getDirByID $icpp_currID`
        if [ ! -e $ICPP_HOME/$dir/out ]; then
            compile
        fi
        echo '************ Running ************'
        $ICPP_HOME/$dir/out
        echo '*********************************'
        ;;
    rc)
        dir=`getDirByID $icpp_currID`
        flag=`removeFirstParemeter $@`
        compile $flag
        echo '************ Running ************'
        $ICPP_HOME/$dir/out
        echo '*********************************'
        ;;
    reset | clear)
        echo -e "icpp_currID=0\nicpp_maxID=0" > $CONFIG_FILE
        if [ ! -d "$TRASH_DIR" ]; then mkdir -p $TRASH_DIR; fi
        now=`date +%Y-%m-%d_%H:%M:%s`
        mkdir $TRASH_DIR/$now
        mv $ICPP_HOME/* $TRASH_DIR/$now
        echo "OK!"
        ;;
    *)
        echo "ERROR: Unknown command \"$1\"";
        return 1
        ;;
    esac

    return 0
}

main_func $@

