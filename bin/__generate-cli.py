#!/usr/bin/env python3

import os
import sys
import argparse
from collections import namedtuple

if len(sys.argv) == 1:
    print("USAGE: echo paramspec | __generate-cli.py cmdname param [param [...]]")
    sys.exit(0)

Param = namedtuple(
    "Param",
    ["short", "long", "dest", "type", "nargs", "default", "choices", "help"],
)


def get_params():
    for i, line in enumerate(sys.stdin):
        line = line.strip()
        if line == "":
            continue
        dline = eval("dict(" + line + ")")

        short = dline.get("short")
        long = dline.get("long")
        dest = dline.get("dest")
        type_ = dline.get("type")
        nargs = dline.get("nargs")
        default = dline.get("default")
        choices = dline.get("choices")
        help = dline.get("help")

        positional = (short is None) and (long is None)
        if positional:
            assert dest is not None, (i, line)

        assert dest is not None, (i, line)
        assert type_ is not None, (i, line)
        assert type_ in ("FLAG", "str", "int", "float", str, int, float), (i, line)

        if type_ == "FLAG":
            assert choices is None
            assert nargs is None
            assert isinstance(default, bool), (i, line)
        else:
            if isinstance(type_, str):
                type_ = eval(type_)

            assert isinstance(nargs, (type(None), int, str)), (i, line)
            if isinstance(nargs, str):
                assert nargs in "*+?", (i, line)

        if (default is not None) and (type_ == "FLAG"):
            assert isinstance(default, bool), (i, line)

        if choices is not None:
            assert isinstance(choices, list), (i, line)

        assert help is not None, (i, line)

        yield Param(
            short,
            long,
            dest,
            type_,
            nargs,
            default,
            choices,
            help
        )

    return


def build_cli(prog, params):

    parser = argparse.ArgumentParser(
        prog=prog,
    )

    for param in params:
        args = []
        kwargs = {}

        if param.short is not None:
            args.append(param.short)

        if param.long is not None:
            args.append(param.long)

        if (param.short is None) and (param.long is None):
            args.append(param.dest)
        else:
            kwargs["dest"] = param.dest

        if param.default is not None:
            kwargs["default"] = param.default

        if param.type == "FLAG":
            assert param.default is not None
            if param.default:
                kwargs["action"] = "store_false"
            else:
                kwargs["action"] = "store_true"

        else:
            kwargs["type"] = param.type

        if param.choices is not None:
            kwargs["choices"] = param.choices

        if param.help is not None:
            kwargs["help"] = param.help

        if param.nargs is not None:
            kwargs["nargs"] = param.nargs

        if (param.default is None) and ((param.short is not None) or (param.long is not None)):
            kwargs["required"] = True


        parser.add_argument(*args, **kwargs)

    return parser


def list_as_array(arg, li):

    li = [f"[{i}]='{v}'" for i, v in enumerate(li)]
    li = " ".join(li)
    return f"declare -a {arg}=( {li} )"


def main():
    args = sys.argv
    params = list(get_params())

    parser = build_cli(args[1], params)

    args = parser.parse_args(args[2:])

    lines = []
    for param in params:
        is_arr = False
        if param.nargs is not None:
            if isinstance(param.nargs, int):
                is_arr = param.nargs > 1
            else:
                is_arr = True

        if is_arr:
            lines.append(list_as_array(param.dest, getattr(args, param.dest)))
        else:
            lines.append(f"declare {param.dest}='{getattr(args, param.dest, '')}'")

    # Do this so that any errors occur before ok is printed
    print("### __generate-cli output")
    print("\n".join(lines))
    return

main()
