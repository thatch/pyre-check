# Copyright (c) 2016-present, Facebook, Inc.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# pyre-unsafe

import os
import sys
import unittest
from unittest.mock import call, mock_open, patch

from ... import EnvironmentException, commands, log
from ...commands import initialize
from .command_test import mock_arguments


class InitializeTest(unittest.TestCase):
    @patch.object(log, "get_yes_no_input", return_value=True)
    @patch.object(log, "get_input", return_value="")
    @patch("shutil.which")
    @patch("os.path.isfile")
    @patch("subprocess.call")
    @patch("builtins.open")
    def test_initialize(
        self, open, subprocess_call, isfile, which, _get_input, get_yes_no_input
    ) -> None:
        get_yes_no_input.return_value = True
        original_directory = "/original/directory"
        arguments = mock_arguments()

        def exists(path):
            if path.endswith(".watchmanconfig"):
                return False
            elif path.endswith(".pyre_configuration"):
                return False
            elif path.endswith(".pyre_configuration.local"):
                return False
            else:
                return True

        isfile.side_effect = exists
        # One for shutil.which("watchman"), another for shutil.which(BINARY_NAME).
        which.side_effect = [True, True]
        with patch.object(commands.Command, "_call_client"):
            initialize.Initialize(arguments, original_directory).run()
            subprocess_call.assert_has_calls([call(["watchman", "watch-project", "."])])
            open.assert_any_call(os.path.abspath(".watchmanconfig"), "w+")

        arguments.local = True

        def exists(path):
            return False

        isfile.side_effect = exists
        file = mock_open()
        with patch("builtins.open", file), patch.object(
            commands.Command, "_call_client"
        ), patch.object(
            initialize.Initialize, "_get_local_configuration", return_value={}
        ):
            initialize.Initialize(arguments, original_directory).run()
            file().write.assert_has_calls([call("{}"), call("\n")])

        def exists(path):
            if path.endswith(".pyre_configuration"):
                return True
            return False

        isfile.side_effect = exists
        with patch.object(commands.Command, "_call_client"):
            with self.assertRaises(EnvironmentException):
                initialize.Initialize(arguments, original_directory).run()

        with patch.object(commands.Command, "_call_client"), patch.object(
            sys, "argv", ["/tmp/pyre/bin/pyre"]
        ):
            which.reset_mock()
            which.side_effect = [True, None, "/tmp/pyre/bin/pyre.bin"]
            initialize.Initialize(arguments, original_directory)._get_configuration()
            which.assert_has_calls(
                [call("watchman"), call("pyre.bin"), call("/tmp/pyre/bin/pyre.bin")]
            )

    def test_get_local_configuration(self) -> None:
        original_directory = "/original/directory"
        arguments = mock_arguments()
        command = initialize.Initialize(arguments, original_directory)

        with patch.object(log, "get_yes_no_input") as yes_no_input, patch.object(
            log, "input", return_value="//target/..."
        ):
            yes_no_input.side_effect = [True, False]
            self.assertEqual(
                command._get_local_configuration(),
                {"continuous": False, "targets": ["//target/..."]},
            )

            yes_no_input.side_effect = [True, True, False]
            self.assertEqual(
                command._get_local_configuration(),
                {
                    "continuous": True,
                    "push_blocking": False,
                    "targets": ["//target/..."],
                },
            )

            yes_no_input.side_effect = [True, True, True]
            self.assertEqual(
                command._get_local_configuration(),
                {
                    "push_blocking": True,
                    "differential": False,
                    "targets": ["//target/..."],
                },
            )

            yes_no_input.side_effect = [True, True, True]
            self.assertEqual(
                command._get_local_configuration(),
                {
                    "differential": False,
                    "push_blocking": True,
                    "targets": ["//target/..."],
                },
            )

        with patch.object(log, "get_yes_no_input") as yes_no_input, patch.object(
            log, "input", return_value="project/a, project/b"
        ):
            yes_no_input.side_effect = [False, False]
            self.assertEqual(
                command._get_local_configuration(),
                {"continuous": False, "source_directories": ["project/a", "project/b"]},
            )
