# This is a sample commands.py.  You can add your own commands here.
#
# Please refer to commands_full.py for all the default commands and a complete
# documentation.  Do NOT add them all here, or you may end up with defunct
# commands when upgrading ranger.

from __future__ import (absolute_import, division, print_function)

import os

from ranger.api.commands import Command


class my_edit(Command):
    """:my_edit <filename>

    A sample command for demonstration purposes that opens a file in an editor.
    """

    def execute(self):
        if self.arg(1):
            target_filename = self.rest(1)
        else:
            target_filename = self.fm.thisfile.path

        self.fm.notify("Let's edit the file " + target_filename + "!")

        if not os.path.exists(target_filename):
            self.fm.notify("The given file does not exist!", bad=True)
            return

        self.fm.edit_file(target_filename)

    def tab(self, tabnum):
        return self._tab_directory_content()
