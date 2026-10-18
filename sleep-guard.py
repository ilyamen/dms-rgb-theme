#!/usr/bin/env python3
# Turns the lighting off before the system suspends, hibernates, shuts down or reboots.
#   sleep-guard.py COMMAND...
# Many boards keep standby power on the RGB headers, so in software (Direct)
# mode the LEDs stay lit in the last color while the PC sleeps or is switched
# off. This holds a logind "delay" inhibitor, runs COMMAND (OpenRGB setting the
# zones to black) when logind announces sleep or shutdown, and only then lets
# the system go. It prints "sleep", "resume" and "shutdown" so the plugin can
# paint the theme color again after waking up.
# Needs nothing beyond Python, systemd-inhibit and gdbus; runs as the user.
import ctypes
import signal
import subprocess
import sys

PR_SET_PDEATHSIG = 1
# logind waits at most InhibitDelayMaxSec (5 s by default) for delay inhibitors
OFF_TIMEOUT = 4.5

libc = ctypes.CDLL(None)


def die_with_parent():
    libc.prctl(PR_SET_PDEATHSIG, signal.SIGTERM)


def spawn(args, **kwargs):
    return subprocess.Popen(args, preexec_fn=die_with_parent, **kwargs)


def inhibit():
    return spawn(["systemd-inhibit", "--what=sleep:shutdown", "--mode=delay", "--who=RGB Theme",
                  "--why=Turning the RGB lighting off", "sleep", "infinity"])


def lights_off(command):
    try:
        subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=OFF_TIMEOUT, check=False)
    except subprocess.TimeoutExpired:
        pass


def main():
    off_command = sys.argv[1:]
    if not off_command:
        sys.exit("usage: sleep-guard.py COMMAND...")
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    lock = inhibit()
    monitor = spawn(["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1",
                     "--object-path", "/org/freedesktop/login1"],
                    stdout=subprocess.PIPE, text=True)
    try:
        for line in monitor.stdout:
            if ".PrepareForShutdown (true" in line:
                # Power-off or reboot: nothing comes back, so the lock stays released
                lights_off(off_command)
                print("shutdown", flush=True)
                if lock:
                    lock.terminate()
                    lock.wait()
                    lock = None
            elif ".PrepareForShutdown (false" in line:
                # Shutdown cancelled: paint the theme color again and keep guarding
                if lock is None:
                    lock = inhibit()
                print("resume", flush=True)
            elif ".PrepareForSleep (true" in line:
                lights_off(off_command)
                print("sleep", flush=True)
                if lock:
                    lock.terminate()
                    lock.wait()
                    lock = None
            elif ".PrepareForSleep (false" in line:
                if lock is None:
                    lock = inhibit()
                print("resume", flush=True)
    finally:
        for child in (lock, monitor):
            if child and child.poll() is None:
                child.terminate()


if __name__ == "__main__":
    main()
