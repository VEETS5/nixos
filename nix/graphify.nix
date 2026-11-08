{ pkgs }:
let
  python = pkgs.python3.withPackages (ps: [ (ps.toPythonModule pkgs.graphify) ]);
in
pkgs.writeShellScriptBin "graphify" ''
  exec ${python}/bin/python3 -m graphify "$@"
''
