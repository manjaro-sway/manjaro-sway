#!/usr/bin/python

# This script requires i3ipc-python package (install it from a system package manager
# or pip).
# It adds icons to the workspace name for each open window.
# Set your keybindings like this: set $workspace1 workspace number 1
# Add your icons to WINDOW_ICONS.
# Based on https://github.com/maximbaz/dotfiles/blob/master/bin/i3-autoname-workspaces

import argparse
import i3ipc
import logging
import re
import signal
import sys
from pathlib import Path

WINDOW_ICONS = {
    "firefox": "󰈹",
}

DEFAULT_ICON = "󰄶"

def get_icon(word):
    if word in WINDOW_ICONS:
        return WINDOW_ICONS[word]
    logging.info("No icon available for: %s" % str(word))
    return DEFAULT_ICON

def icon_for_window(window):
    app_id = window.app_id
    if app_id is not None and len(app_id) > 0:
        app_id = app_id.lower()
        return get_icon(app_id)
    else:
        # xwayland support
        class_name = window.window_class
        if class_name is not None and len(class_name) > 0:
            class_name = class_name.lower()
            return get_icon(class_name)
        return DEFAULT_ICON

def rename_workspaces(ipc):
    ICONS_ON_WORKSPACE = {}
    for workspace in ipc.get_tree().workspaces():
        name_parts = parse_workspace_name(workspace.name)
        num = str(name_parts["num"])
        ICONS_ON_WORKSPACE[num] = ()
        for w in workspace:
            if w.app_id is not None or w.window_class is not None:
                icon = icon_for_window(w)
                if not ARGUMENTS.duplicates and icon in ICONS_ON_WORKSPACE[num]:
                    continue
                ICONS_ON_WORKSPACE[num] += (icon,)
        name_parts["icons"] = "%s%s" % (get_icon(num), "".join(ICONS_ON_WORKSPACE[num]))
        new_name = construct_workspace_name(name_parts)
        ipc.command('rename workspace "%s" to "%s"' % (workspace.name, new_name))

def undo_window_renaming(ipc):
    for workspace in ipc.get_tree().workspaces():
        name_parts = parse_workspace_name(workspace.name)
        name_parts["icons"] = None
        new_name = construct_workspace_name(name_parts)
        ipc.command('rename workspace "%s" to "%s"' % (workspace.name, new_name))
    ipc.main_quit()
    sys.exit(0)


def parse_workspace_name(name):
    logging.info(name)
    return re.match(
        "(?P<num>-*[0-9]+):?(?P<icons>.+)?", name
    ).groupdict()

def construct_workspace_name(parts):
    new_name = str(parts["num"])
    if parts["icons"]:
        new_name += ":%s" % parts["icons"]
    return new_name

def parse_icons_file(path):
    file = Path(path)
    if not file.is_file():
        logging.info("no additional icon definition file found at %s", path)
    if file.is_file():
        with open(path) as icons_file:
            for line in icons_file:
                name, var = line.partition("=")[::2]
                WINDOW_ICONS[name.strip()] = var.strip()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="This script automatically changes the workspace name in sway depending on your open applications."
    )
    parser.add_argument(
        "--duplicates",
        "-d",
        action="store_true",
        help="Set it if you want an icon for each instance of the same application per workspace.",
    )
    parser.add_argument(
        "--logfile",
        "-l",
        type=str,
        default="/tmp/sway-autoname-workspaces.log",
        help="Path for the logfile.",
    )
    parser.add_argument(
        "--iconsfile",
        "-i",
        type=str,
        default="/usr/share/sway/icons.config",
        help="Path for a file with additional icon configuration in key=value format",
    )
    args = parser.parse_args()
    global ARGUMENTS
    ARGUMENTS = args

    logging.basicConfig(
        level=logging.INFO,
        filename=ARGUMENTS.logfile,
        filemode="w",
        format="%(message)s",
    )

    parse_icons_file(ARGUMENTS.iconsfile)

    logging.info(WINDOW_ICONS)

    ipc = i3ipc.Connection()

    for sig in [signal.SIGINT, signal.SIGTERM]:
        signal.signal(sig, lambda signal, frame: undo_window_renaming(ipc))

    def window_event_handler(ipc, e):
        if e.change in ["new", "close", "move"]:
            rename_workspaces(ipc)

    ipc.on("window", window_event_handler)

    def workspace_event_handler(ipc, e):
        rename_workspaces(ipc)

    ipc.on("workspace", workspace_event_handler)

    rename_workspaces(ipc)

    ipc.main()
