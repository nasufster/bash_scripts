#!/bin/bash

dbus-send --system --dest=org.freedesktop.UPower --type=method_call --print-reply /org/freedesktop/UPower org.freedesktop.UPower.Suspend
