(* Copyright (c) 2019-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree. *)

open Ast
open Core

type t = {
  add_source: Source.t -> unit;
  remove_sources: Reference.t list -> unit;
  get_source: Reference.t -> Source.t option;
  get_source_path: Reference.t -> SourcePath.t option;
}

module SourceValue = struct
  type t = Source.t

  let prefix = Prefix.make ()

  let description = "AST"

  let unmarshall value = Marshal.from_string value 0
end

module Sources = Memory.NoCache (Reference.Key) (SourceValue)

let create module_tracker =
  {
    add_source = (fun ({ Source.qualifier; _ } as source) -> Sources.add qualifier source);
    remove_sources = (fun qualifiers -> Sources.KeySet.of_list qualifiers |> Sources.remove_batch);
    get_source = Sources.get;
    get_source_path = ModuleTracker.lookup module_tracker;
  }


let add_source { add_source; _ } = add_source

let remove_sources { remove_sources; _ } = remove_sources

let get_source { get_source; _ } = get_source

let get_source_path { get_source_path; _ } = get_source_path

(* Both `load` and `store` are no-ops here since `Ast.SharedMemory.Sources` is in shared memory,
   and `Memory.load_shared_memory`/`Memory.save_shared_memory` will take care of the
   (de-)serialization for us. *)
let store _ = ()

let load = create

let shared_memory_hash_to_key_map qualifiers = Sources.compute_hashes_to_keys ~keys:qualifiers

let serialize_decoded decoded =
  match decoded with
  | Sources.Decoded (key, value) ->
      Some (SourceValue.description, Reference.show key, Option.map value ~f:Source.show)
  | _ -> None


let decoded_equal first second =
  match first, second with
  | Sources.Decoded (_, first), Sources.Decoded (_, second) ->
      Some (Option.equal Source.equal first second)
  | _ -> None


type environment_t = t

module ReadOnly = struct
  type t = {
    get_source: Reference.t -> Source.t option;
    get_source_path: Reference.t -> SourcePath.t option;
  }

  let create ?(get_source = fun _ -> None) ?(get_source_path = fun _ -> None) () =
    { get_source; get_source_path }


  let get_source { get_source; _ } = get_source

  let get_source_path { get_source_path; _ } = get_source_path

  let get_relative read_only qualifier =
    let open Option in
    get_source_path read_only qualifier >>| fun { SourcePath.relative; _ } -> relative
end

let read_only { get_source; get_source_path; _ } = { ReadOnly.get_source; get_source_path }