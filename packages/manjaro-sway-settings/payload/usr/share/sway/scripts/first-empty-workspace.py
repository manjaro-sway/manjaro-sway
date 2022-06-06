#!/usr/bin/python3

import i3ipc
from argparse import ArgumentParser
from time import sleep

# Assumption: it exists 10 workspaces (otherwise, change this value)
NUM_WORKSPACES = 10

if __name__ == "__main__":

    arguments_parser = ArgumentParser()
    arguments_parser.add_argument('-s',
                                  '--switch',
                                  action='store_true',
                                  help='switch to the first empty workspace'
    )
    arguments_parser.add_argument('-m',
                                  '--move',
                                  action='store_true',
                                  help='move the currently focused container to the first empty workspace'
    )
    arguments = arguments_parser.parse_args()
    assert(arguments.switch or arguments.move) # at least one of the flags must be specificated

    ipc = i3ipc.Connection()
    tree = ipc.get_tree()
    current_workspace = tree.find_focused().workspace()
    workspaces = tree.workspaces() # includes current_workspace

    workspace_numbers = [workspace.num for workspace in workspaces]
    empty_workspace_numbers = set([number for number in range(1,NUM_WORKSPACES+1)]) - set(workspace_numbers)
    # Take into consideration that the current workspace exists but might be empty
    if len(current_workspace.nodes) == 0: empty_workspace_numbers.add(current_workspace.num)

    # Get the minor empty workspace's number (or set it as the current workspace's number if all are busy)
    first_empty_workspace_number = current_workspace.num
    if empty_workspace_numbers:
        first_empty_workspace_number = min(empty_workspace_numbers)

    # Use the value of first_empty_workspace_number to make the requested actions
    if arguments.move and arguments.switch:
        # Avoid wallpaper flickering when moving and switching by specifying both actions in the same Sway's command
        reply = ipc.command("move container to workspace number {}, workspace number {}".format(first_empty_workspace_number, first_empty_workspace_number))
        assert(reply[0].success) # exit with non-zero status if the assertion fails
    elif arguments.switch:
        reply = ipc.command("workspace number {}".format(first_empty_workspace_number))
        assert(reply[0].success) # exit with non-zero status if the assertion fails
    elif arguments.move:
        reply = ipc.command("move container to workspace number {}".format(first_empty_workspace_number))
        assert(reply[0].success) # exit with non-zero status if the assertion fails
