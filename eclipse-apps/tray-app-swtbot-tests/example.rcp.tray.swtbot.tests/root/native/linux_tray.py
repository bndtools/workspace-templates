#!/usr/bin/env python3
# Copyright (c) 2026 Kirschners GmbH and others.
# SPDX-License-Identifier: EPL-2.0
"""Use X11 input and AT-SPI against the running SWT tray application."""
import re
import subprocess
import sys
import time

try:
    import pyatspi
except ImportError as exc:
    sys.exit("Native tray tests require python3-pyatspi: " + str(exc))


def command(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT)


def wait_for(description, predicate, timeout=15):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        try:
            result = predicate()
            if result:
                return result
        except (RuntimeError, LookupError):
            pass
        time.sleep(0.1)
    raise AssertionError("Timed out waiting for " + description)


def walk(obj):
    yield obj
    for child in obj:
        yield from walk(child)


def showing(obj):
    return obj.getState().contains(pyatspi.STATE_SHOWING)


def objects(role):
    return [obj for obj in walk(pyatspi.Registry.getDesktop(0))
            if obj.getRoleName() == role and showing(obj)]


def tray_position():
    panels = command("xdotool", "search", "--onlyvisible", "--name", "^panel$").split()
    if len(panels) != 1:
        raise AssertionError("Expected exactly one visible trayer panel, found " + repr(panels))
    tree = command("xwininfo", "-id", panels[0], "-tree")
    icons = re.findall(r'^\s*(0x[0-9a-fA-F]+)\s+"SWT":\s+\("SWT" "SWT"\)', tree, re.MULTILINE)
    if len(icons) != 1:
        return None
    geometry = command("xdotool", "getwindowgeometry", "--shell", icons[0])
    values = dict(line.split("=", 1) for line in geometry.splitlines() if "=" in line)
    return (int(values["X"]) + int(values["WIDTH"]) // 2,
            int(values["Y"]) + int(values["HEIGHT"]) // 2)


def mouse_click(x, y, button=1):
    command("xdotool", "mousemove", "--sync", str(x), str(y), "click", str(button))


def click_accessible(obj):
    rect = obj.queryComponent().getExtents(pyatspi.DESKTOP_COORDS)
    if rect.width <= 0 or rect.height <= 0:
        raise AssertionError("No clickable bounds for " + repr(obj.name))
    mouse_click(rect.x + rect.width // 2, rect.y + rect.height // 2)


def open_menu(position, button, expected):
    mouse_click(*position, button)

    def matching_menu():
        for menu in objects("menu"):
            children = [(child.getRoleName(), child.name) for child in menu]
            if children == expected:
                return menu
        return None

    return wait_for("tray menu " + repr(expected), matching_menu)


def open_dialog(menu, item_name, title, message):
    matches = [item for item in menu if item.getRoleName() == "menu item" and item.name == item_name]
    if len(matches) != 1:
        raise AssertionError("Missing or duplicate menu item " + item_name)
    click_accessible(matches[0])

    def matching_dialog_with_button():
        for dialog in objects("alert") + objects("dialog"):
            descendants = list(walk(dialog))
            labels = [child.name for child in descendants if child.getRoleName() == "label"]
            if title not in labels or message not in labels:
                continue
            buttons = [child for child in descendants
                       if child.getRoleName() == "push button" and child.name == "OK" and showing(child)]
            if len(buttons) == 1:
                return dialog, buttons[0]
        return None

    # The dialog and its message label can become showing before the OK button
    # finishes rendering, so wait for both together instead of checking once.
    dialog, button = wait_for(title + " dialog with one visible OK button", matching_dialog_with_button)
    click_accessible(button)
    wait_for(title + " dialog to close",
             lambda: not any(title in [child.name for child in walk(dialog)
                                       if child.getRoleName() == "label"]
                             for dialog in objects("alert") + objects("dialog")))


def main():
    position = wait_for("one SWT icon embedded in the trayer panel", tray_position, 30)
    left = [("menu item", "Hello World..."), ("menu item", "About"), ("menu item", "Exit")]
    right = [("menu item", "Hello World..."), ("menu item", "Preferences..."),
             ("separator", ""), ("menu item", "Exit")]
    open_dialog(open_menu(position, 1, left), "Hello World...", "Hello World", "Hello World!")
    open_dialog(open_menu(position, 1, left), "About", "About", "SWT system tray example.")
    open_dialog(open_menu(position, 3, right), "Hello World...", "Hello World", "Hello World!")
    open_dialog(open_menu(position, 3, right), "Preferences...", "Preferences",
                "Preferences are not implemented.")
    menu = open_menu(position, 1, left)
    click_accessible(next(item for item in menu if item.name == "Exit"))
    wait_for("tray icon to disappear after Exit", lambda: not tray_position())
    print("Native Linux tray menus, dialogs and Exit passed", flush=True)


if __name__ == "__main__":
    main()
