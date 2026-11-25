#!/usr/bin/env python3
"""Capture one screenshot per sidebar page of the running GTK4 host.

The sidebar rows select on a click gesture with selection mode off, so this
driver reads each row's on-screen geometry through AT-SPI, clicks its center
with xdotool and grabs the root window. The pictures feed the
prototype-vs-build comparison (issue #64); they are evidence, not an
assertion of visual parity.

Unlike linux-atspi.py this script makes no product assertions beyond "every
page is reachable by a click" and "the native close works".
"""
import argparse
import json
import re
import subprocess
import time
from pathlib import Path

import pyatspi

XY_SCREEN = getattr(pyatspi, "XY_SCREEN", 0)


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


def find_frame(application):
    return next((node for node in walk(application) if role(node) == "frame"), None)


def find_named(root, name, expected_role=None):
    for node in walk(root):
        if (node.name or "") != name:
            continue
        if expected_role is not None and role(node) != expected_role:
            continue
        try:
            node.queryComponent()
        except Exception:
            continue
        return node
    return None


def press(node):
    actions = node.queryAction()
    if actions.nActions < 1 or not actions.doAction(0):
        raise AssertionError(f"AT-SPI action failed for {node.name!r}")


def extents(node):
    box = node.queryComponent().getExtents(XY_SCREEN)
    return [int(box[0]), int(box[1]), int(box[2]), int(box[3])]


def click(node):
    x, y, width, height = extents(node)
    if width <= 0 or height <= 0:
        raise AssertionError(f"row {node.name!r} has no on-screen geometry")
    center_x, center_y = x + width // 2, y + height // 2
    subprocess.run(
        ["xdotool", "mousemove", str(center_x), str(center_y), "click", "1"],
        check=True,
    )
    return [center_x, center_y]


def slug(name):
    return re.sub(r"[^a-z0-9]+", "-", name.casefold()).strip("-") or "page"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--title", default="gptp studio")
    parser.add_argument("--language", required=True, help="recorded in the manifest")
    parser.add_argument("--scheme", required=True, help="light or dark")
    parser.add_argument(
        "--busy-text",
        action="append",
        default=[],
        help="a label that still shows this text means the backend is not up yet",
    )
    parser.add_argument(
        "--close-name",
        default="Close",
        help="accessible name of the native window close button",
    )
    parser.add_argument("--settle", type=float, default=1.5)
    parser.add_argument("pages", nargs="+", help="sidebar labels in click order")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    application = wait_for("gPTP Studio application", lambda: find_application(args.title))
    window = wait_for("gPTP Studio frame", lambda: find_frame(application))
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
    time.sleep(1.0)

    captures = []
    for index, page in enumerate(args.pages, start=1):
        # The stack exposes the same titles, so insist on the sidebar row.
        row = wait_for(
            f"{page} sidebar row",
            lambda: find_named(window, page, "list item"),
        )
        clicked = click(row)
        time.sleep(args.settle)
        file = f"{index:02d}-{slug(page)}.png"
        subprocess.run(
            ["import", "-window", "root", str(args.output / file)], check=True
        )
        captures.append({"page": page, "file": file, "clicked": clicked})

    close = wait_for(
        "native Close button",
        lambda: find_named(window, args.close_name, "push button"),
    )
    press(close)

    (args.output / "captures.json").write_text(
        json.dumps(
            {
                "platform": "linux",
                "language": args.language,
                "scheme": args.scheme,
                "frame": extents(window),
                "captures": captures,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
