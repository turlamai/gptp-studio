#!/usr/bin/env python3
"""Capture one screenshot per sidebar page of the running GTK4 host.

The sidebar rows select on a click gesture with selection mode off, so this
driver selects each row through its AT-SPI action when it has one, and
otherwise clicks the center of its on-screen box (read through AT-SPI) with
xdotool. A page is captured only once its panel is on screen. The pictures
feed the prototype-vs-build comparison (issue #64); they are evidence, not
an assertion of visual parity.

The assertions are: every page is reachable by one selection, and the native
close works.
"""
import argparse
import json
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


def sidebar_rows(window):
    """The navigation list: the first list whose items are all list items.

    The host's rows expose no accessible name of their own (their label is a
    child), so callers match on the label text inside the row.
    """
    for node in walk(window):
        if role(node) != "list":
            continue
        items = [child for child in children(node) if role(child) == "list item"]
        if items:
            return items
    return []


def find_row(window, page):
    for row in sidebar_rows(window):
        if any((node.name or "") == page for node in walk(row)):
            return row
    return None


def extents(node):
    try:
        box = node.queryComponent().getExtents(XY_SCREEN)
    except Exception:
        return None
    return [int(box[0]), int(box[1]), int(box[2]), int(box[3])]


def is_showing(node):
    try:
        return node.getState().contains(pyatspi.STATE_SHOWING)
    except Exception:
        return False


def visible_page(window, pages):
    """The one page panel that is on screen, or None."""
    shown = set()
    for node in walk(window):
        if role(node) == "panel" and (node.name or "") in pages and is_showing(node):
            shown.add(node.name)
    return shown.pop() if len(shown) == 1 else None


def activate(row):
    """Select the row through its AT-SPI action when it has one.

    Returns True when an action ran. Otherwise the caller falls back to a
    real click.
    """
    try:
        actions = row.queryAction()
    except Exception:
        return False
    if actions.nActions < 1:
        return False
    return bool(actions.doAction(0))


def geometry(row):
    """Every reported box in and under the row, for the manifest."""
    report = []
    for node in walk(row):
        box = extents(node)
        if box is not None:
            report.append({"role": role(node), "name": node.name or "", "box": box})
    return report


def click(row, frame, sidebar_fraction):
    """Click the row, or the node inside it, that lies in the sidebar zone."""
    frame_x, frame_y, frame_width, frame_height = frame
    for node in walk(row):
        box = extents(node)
        if box is None or box[2] <= 0 or box[3] <= 0:
            continue
        center_x, center_y = box[0] + box[2] // 2, box[1] + box[3] // 2
        if (
            frame_x <= center_x <= frame_x + int(frame_width * sidebar_fraction)
            and frame_y <= center_y <= frame_y + frame_height
        ):
            subprocess.run(
                ["xdotool", "mousemove", str(center_x), str(center_y), "click", "1"],
                check=True,
            )
            return [center_x, center_y]
    raise AssertionError(f"no node of row {row.name!r} reports a box in the sidebar zone")


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
    parser.add_argument(
        "--sidebar-fraction",
        type=float,
        default=0.35,
        help="width share of the window in which a navigation row may lie",
    )
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

    rows = wait_for(
        f"{len(args.pages)} sidebar rows",
        lambda: (sidebar_rows(window) if len(sidebar_rows(window)) == len(args.pages) else None),
    )
    frame = extents(window)
    manifest = {
        "platform": "linux",
        "language": args.language,
        "scheme": args.scheme,
        "frame": frame,
        "row_names": [row.name or "" for row in rows],
        "captures": [],
    }

    def write_manifest():
        (args.output / "captures.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    # Every page must end up on screen; a click that lands elsewhere is a
    # failure, not a picture of the wrong page.
    last_click_y = None
    try:
        for index, page in enumerate(args.pages, start=1):
            row = rows[index - 1]
            if find_row(window, page) is not row:
                raise AssertionError(f"sidebar row {index} is not {page!r}")
            boxes = geometry(row)
            if activate(row):
                method, clicked = "at-spi action", None
            else:
                method = "mouse click"
                clicked = click(row, frame, args.sidebar_fraction)
                if last_click_y is not None and clicked[1] <= last_click_y:
                    raise AssertionError(
                        f"rows {index - 1} and {index} report the same spot; geometry: "
                        + json.dumps(boxes, ensure_ascii=False)
                    )
                last_click_y = clicked[1]
            try:
                wait_for(
                    f"{page!r} page on screen",
                    lambda: visible_page(window, args.pages) == page,
                    timeout=10.0,
                )
            except AssertionError as error:
                raise AssertionError(
                    f"{error}; row geometry: {json.dumps(boxes, ensure_ascii=False)}"
                )
            time.sleep(args.settle)
            file = f"{index:02d}.png"
            subprocess.run(
                ["import", "-window", "root", str(args.output / file)], check=True
            )
            manifest["captures"].append(
                {"page": page, "file": file, "method": method, "clicked": clicked}
            )

        close = wait_for(
            "native Close button",
            lambda: find_named(window, args.close_name, "push button"),
        )
        press(close)
    finally:
        write_manifest()


if __name__ == "__main__":
    main()
