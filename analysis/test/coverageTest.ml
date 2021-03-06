(* Copyright (c) 2016-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree. *)

open Core
open OUnit2
open Analysis

let test_coverage context =
  let assert_coverage ?external_sources sources expected =
    let project = Test.ScratchProject.setup ~context ?external_sources sources in
    let configuration = Test.ScratchProject.configuration_of project in
    let ast_environment, ast_environment_update_result =
      Test.ScratchProject.parse_sources project
    in
    let ast_environment = Analysis.AstEnvironment.read_only ast_environment in
    let sources =
      AstEnvironment.UpdateResult.reparsed ast_environment_update_result
      |> List.filter_map ~f:(AstEnvironment.ReadOnly.get_source ast_environment)
      |> List.map ~f:(fun { Ast.Source.source_path = { Ast.SourcePath.qualifier; _ }; _ } ->
             qualifier)
    in
    Coverage.coverage ~configuration ~ast_environment sources |> assert_equal expected
  in
  assert_coverage
    [
      "a.py", "#pyre-strict\ndef foo()->int:\n    return 1\n";
      "b.py", "#pyre-strict\ndef foo()->int:\n    return 1\n";
      "c.py", "#pyre-ignore-all-errors\ndef foo()->int:\n    return 1\n";
    ]
    { Coverage.strict_coverage = 2; declare_coverage = 1; default_coverage = 0; source_files = 3 };
  assert_coverage
    ~external_sources:
      [
        "external_a.py", "#pyre-strict\ndef foo()->int:\n    return 1\n";
        "external_b.py", "#pyre-strict\ndef foo()->int:\n    return 1\n";
        "external_c.py", "#pyre-ignore-all-errors\ndef foo()->int:\n    return 1\n";
      ]
    ["a.py", "#pyre-strict\ndef foo()->int:\n    return 1\n"]
    { Coverage.strict_coverage = 1; declare_coverage = 0; default_coverage = 0; source_files = 1 }


let () = "coverage" >::: ["compute_coverage" >:: test_coverage] |> Test.run
