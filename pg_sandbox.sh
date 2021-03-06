#!/bin/bash
# vim: ts=4 sts=4 et sw=4

# This file must be used with "source pg_sandbox.sh" *from bash*
# you cannot run it directly

pg_sb () {
    pg_sandbox $*
}

pg_sandbox () {
    case "$1" in
        create_cluster)
            shift 1
            create_cluster $* 
            ;;
        change_cluster)
            shift 1
            change_cluster $*
            ;;
        deactivate)
            shift 1
            deactivate $*
            ;;
        *)
            echo "Usage: $1 {create_cluster|change_cluster|deactivate}" >&2
            return 1
            ;;
    esac
}

create_cluster () {
    if [[ "x$1" = "x" || "x$2" = "x"  || "x$3" = "x" ]] ; then
        echo "Usage: create_cluster [/path/to/cluster] [superuser name] [port]."
        return 1
    fi

    NEW_CLUSTER_PATH=$(qualify_path $1)
    # First create the directory structure
    mkdir -p $NEW_CLUSTER_PATH/data $NEW_CLUSTER_PATH/run $NEW_CLUSTER_PATH/log

    # Then, initialize the cluster
    initdb -U $2 -D $NEW_CLUSTER_PATH/data

    # Set the port in the config file
    sed -i "s/^#port = 5432/port = $3/" $NEW_CLUSTER_PATH/data/postgresql.conf
}

change_cluster () {
    if [ "x$1" = "x" ] ; then
        echo "Error: You must specify a cluster directory."
        return 1
    fi
    # TODO add routine to unset the PG* environment variables/reset them to their original values
    PG_SB_CURRENT_CLUSTER=$(qualify_path $1)
    export PG_SB_CURRENT_CLUSTER
    export PGDATA=$PG_SB_CURRENT_CLUSTER/data
    export PGPORT=`awk '/^port = / {printf "%s", $3}' $PGDATA/postgresql.conf`
    export PGHOST=$PG_SB_CURRENT_CLUSTER/run
    set_ps $1
}

set_ps () {
    case "$1" in
        original)
            if [ -n "$_OLD_VIRTUAL_PS1" ] ; then
                PS1="$_OLD_VIRTUAL_PS1"
                export PS1
            fi
            ;;
        default)
            PS1="(pg_sandbox) $PS1"
            export PS1
            ;;
        *)
            if [ ! "x$1" = "x" ] ; then
               PS1="(pg_sandbox: `basename \"$1\"`) $_OLD_VIRTUAL_PS1"
               export PS1
            fi
            ;;
    esac
}

qualify_path () {
    QUALIFIED_PATH=$1

    # If not fully qualified path, prepend pwd
    if [ ! "`echo -n $QUALIFIED_PATH | awk -F '' '{printf "%s", \$1}'`" = "/" ] ; then
        QUALIFIED_PATH="`pwd`/$QUALIFIED_PATH"
    fi

    echo -n $QUALIFIED_PATH
}

deactivate () {
    if [ -n "$_OLD_VIRTUAL_PATH" ] ; then
        PATH="$_OLD_VIRTUAL_PATH"
        export PATH
        unset _OLD_VIRTUAL_PATH
    fi

    # This should detect bash and zsh, which have a hash command that must
    # be called to get it to forget past commands.  Without forgetting
    # past commands the $PATH changes we made may not be respected
    if [ -n "$BASH" -o -n "$ZSH_VERSION" ] ; then
        hash -r
    fi

    if [ -n "$_OLD_VIRTUAL_PS1" ] ; then
        set_ps original
        unset _OLD_VIRTUAL_PS1
    fi

    unset VIRTUAL_ENV
    if [ ! "$1" = "nondestructive" ] ; then
    # Self destruct!
        unset pg_sb
        unset pg_sandbox
        unset create_cluster
        unset change_cluster 
        unset set_ps
        unset qualify_path
        unset deactivate
    fi
}

initialize () {
    # unset irrelevant variables
    deactivate nondestructive

    if [ ! "x$1" = "x" ] ; then
        export VIRTUAL_ENV="$1"
    fi

    _OLD_VIRTUAL_PATH="$PATH"
    # TODO figure out the path to the postgres bin
    PATH="$VIRTUAL_ENV/bin:/usr/lib/postgresql/8.4/bin:$PATH"
    export PATH

    _OLD_VIRTUAL_PS1="$PS1"
    set_ps default

    # This should detect bash and zsh, which have a hash command that must
    # be called to get it to forget past commands.  Without forgetting
    # past commands the $PATH changes we made may not be respected
    if [ -n "$BASH" -o -n "$ZSH_VERSION" ] ; then
        hash -r
    fi
}

case "$-" in
    *i*) # If we were invoked interactively, initialize pg_sandbox environment
        # Set path to pg_sandbox utility scripts
        INIT_PATH=`dirname $BASH_ARGV`

        # Initialize environment using fully qualified path
        initialize $(qualify_path $INIT_PATH)
        ;;

    *)  # If we were invoked directly, output a message describing correct usage
        echo "Error: pg_sandbox.sh cannot be run directly."
        echo "       Invoke \"source /path/to/pg_sandbox.sh\" in *bash*"
        ;;
esac

