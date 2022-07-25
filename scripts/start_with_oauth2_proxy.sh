#!/bin/bash

set -eo pipefail

# This pipe setup is not my invention but the same one used by
# https://github.com/heroku/heroku-buildpack-static

# make a shared pipe; we'll write the name of the process that exits to it once
# that happens, and wait for that event below this particular call works on
# Linux and Mac OS (will create a literal ".XXXXXX" on Mac, but that doesn't
# matter).
wait_pipe=$(mktemp -t "heroku.waitpipe-$PORT.XXXXXX" -u)
rm -f $wait_pipe
mkfifo $wait_pipe
exec 3<> $wait_pipe

pids=()

# trap SIGQUIT (ctrl+\ on the console), SIGTERM (when we get killed) and EXIT
# (upon failure of any command due to set -e, or because of the exit 1 at the
# very end), we then 1) restore the trap so it doesn't fire again a loop due to
# the exit at the end (if we're handling SIGQUIT or SIGTERM) or another signal
# 2) remove our FIFO from above 3) kill all the subshells we've spawned - they
# in turn have their own traps to kill their respective subprocesses 3a) send
# STDERR to /dev/null so we don't see "no such process" errors - after all, one
# of the subshells may be gone 3b) || true so that set -e doesn't cause a mess
# if the kill returns 1 on "no such process" cases (which is likely) 4) exit in
# case we're handling SIGQUIT or SIGTERM
trap 'trap - QUIT TERM EXIT; echo "Going down, terminating child processes..." >&2; rm -f ${wait_pipe} || true; kill -TERM "${pids[@]}" 2> /dev/null || true; exit' QUIT TERM EXIT
# if FD 1 is a TTY (that's the -t 1 check), trap SIGINT/Ctrl+C
# 1) restore the INT trap so it doesn't fire in a loop due to 2)
# 2) be nice to the caller and send SIGINT to ourselves (http://mywiki.wooledge.org/SignalTrap#Special_Note_On_SIGINT)
# 3) *do* exit after all to run the cleanup code from above (avoids duplication)
if [[ -t 1 ]]; then
    trap 'trap - INT; kill -INT $$; exit' INT;
# if FD 1 is not a TTY (e.g. when we're run through 'foreman start'), do nothing
# on SIGINT; the assumption is that the parent will send us a SIGTERM or
# something when this happens. With the trap above, Ctrl+C-ing out of a 'foreman
# start' run would trigger the INT trap both in Foreman and here (because Ctrl+C
# sends SIGINT to the entire process group, but there is no way to tell the two
# cases apart), and while the trap is still doing its shutdown work triggered by
# the SIGTERM from the Ctrl+C, Foreman would then send a SIGTERM because that's
# what it does when it receives a SIGINT itself.
else
    trap '' INT;
fi

# we are now launching a subshell for each of the tasks (oauth2-proxy, web server)
# 1) each subshell has a trap on EXIT that echos the command name to FD 3 (see the FIFO set up above)
# 1a) a 'read' at the end of the script will block on reading from that FD and then trigger the exit trap above, which does the cleanup
# 2) each subshell also has a trap on TERM that
# 2a) kills $! (the last process executed)
# 2b) ... which in turn will unblock the 'wait' in 4)
# 3) execute the command in the background
# 4) 'wait' on the command (wait is interrupted by an incoming TERM to the subshell, whereas running 3) in the foreground would wait for that 3) to finish before triggering the trap)
# 5) add the PID of the subshell to the array that the EXIT trap further above uses to clean everything up

# Add a flag to only enable the OAUTH2_PROXY if explicitly specified
if [[ "$OAUTH2_PROXY_ENABLE" = true ]] ; then 
	echo "Starting oauth2-proxy..." >&2
	(
	    trap 'echo "oauth2-proxy" >&3;' EXIT
	    trap 'kill -TERM $! 2> /dev/null' TERM
	    /app/bin/start_oauth2_proxy.sh &
	    wait
	) & pids+=($!)
	echo "Starting backend..." >&2
	(
	    trap 'echo "backend" >&3;' EXIT
	    trap 'kill -TERM $! 2> /dev/null' TERM
	    export PORT=8080
	    "$@" &
	    wait
	) & pids+=($!)
else
	echo "Starting backend..." >&2
	(
	    trap 'echo "backend" >&3;' EXIT
	    trap 'kill -TERM $! 2> /dev/null' TERM
	    "$@" &
	    wait
	) & pids+=($!)
fi

read exitproc <&3
echo "Process exited unexpectedly: $exitproc" >&2
exit 1
