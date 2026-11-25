#!/usr/bin/env python3
"""Capture the page the GTK4 host was started on, then close it natively.

The host opens on the page named by GPTP_DEV_PAGE (see capture-host.sh).
Why not click the sidebar: on X11 this host's rows report only
parent-relative AT-SPI boxes and no accessible name, and every stack page
reports "showing", so a driver can neither find a row nor tell which page
is up. The pictures feed the prototype-vs-build comparison (issue #64);
they are evidence, not an assertion of visual parity.

Asserted here: the window came up, the backend reached its ready state,
and the native close works.
"""
import argparse
import json
import subprocess
import time
from pathlib import Path

import pyatspi


def children(node):
    for index in range(node.childCount):
        try:
            yield node.getChildAtIndex(index)
        except Exception:
            continue


def walk(node):
    yield node
    for child in children(node):
        yield from walk(child)


def role(node):
    try:
        return node.getRoleName()
    except Exception:
        return "unknown"


def wait_for(description, probe, timeout=30.0):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = probe()
        if value:
            return value
        time.sleep(0.05)
    raise AssertionError(f"timed out waiting for {description}")


def find_application(title):
    folded = title.casefold()
    for application in children(pyatspi.Registry.getDesktop(0)):
        for node in walk(application):
            if role(node) == "frame" and folded in (node.name or "").casefold():
                return application
    return None


def find_named(root, name, expected_role):
    for node in walk(root):
        if (node.name or "") == name and role(node) == expected_role:
            return node
    return None


def press(node):
    actions = node.queryAction()
    if actions.nActions < 1 or not actions.doAction(0):
        raise AssertionError(f"AT-SPI action failed for {node.name!r}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--title", default="gptp studio")
    parser.add_argument("--busy-text", action="append", default=[])
    parser.add_argument("--close-name", default="Close")
    parser.add_argument("--settle", type=float, default=1.5)
    parser.add_argument("file", help="picture file name, relative to --output")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    application = wait_for("gPTP Studio application", lambda: find_application(args.title))
    window = wait_for(
        "gPTP Studio frame",
        lambda: next((node for node in walk(application) if role(node) == "frame"), None),
    )
    busy = [text.casefold() for text in args.busy_text]
    wait_for(
        "backend ready status",
        lambda: not any(
            marker in (node.name or "").casefold()
            for node in walk(window)
            for marker in busy
        ),
        timeout=120.0,
    )
    time.sleep(args.settle)
    subprocess.run(
        ["import", "-window", "root", str(args.output / args.file)], check=True
    )
    close = wait_for(
        "native Close button",
        lambda: find_named(window, args.close_name, "push button"),
    )
    press(close)
    print(json.dumps({"file": args.file}))


if __name__ == "__main__":
    main()
