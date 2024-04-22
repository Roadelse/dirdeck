#!/usr/bin/env python
# coding=utf-8

#@ Introduction
"""
dms, denoting to Directory-Management-System, is designed to set location easily by name.
This script acts as the backend of dms in Linux cluster (In Windows & WSL I prefer to use powershell as the backend)
"""


#@ Import
import sys
import os
import os.path
import argparse
import json


#@ Prepare
#@ .Check
#@ ..pyver
if sys.version_info < (3, 6):
    print("This script requires Python version 3.6 or higher")
    sys.exit(1)

#@ .aux-functions
def warning(msg: str):
    print(f"\033[33mWarning!\033[0m {msg}")


#@ Main
def save_dir(name: str, path: str):
    if not name:
        name = "main"
    if not path:
        path = "."

    target_path: str = os.path.abspath(path)
    if not os.path.exists(path):
        print("\033[33mWarning!\033[0m Saving non-existed path")
    
    namedirs[name] = target_path
    json.dump(namedirs, open(reSG_dat, "w"))

def goto_dir(name: str):
    if not name:
        name = "main"

    if name == "list":
        list_dirs()
        return

    if name not in namedirs:
        raise RuntimeError(f"Cannot find {name} in saved directories")
    
    print(namedirs[name])
    return

def list_dirs():
    for k, v in namedirs.items():
        print(f"{k}\t: {v}")

def delete_dir(name: str):
    if not name or name == "main":
        return
    
    if name not in namedirs:
        warning("Trying to delete directory from a non-existed name")
        return

    del namedirs[name]
    json.dump(namedirs, open(reSG_dat, "w"))

def clear_dirs():
    if "main" in namedirs:
        json.dump({"main": namedirs["main"]}, open(reSG_dat, "w"))
    else:
        json.dump({}, open(reSG_dat, "w"))


#@ Entry
if __name__ == "__main__":
    global namedirs

    parser = argparse.ArgumentParser(description="""dirdeck for cluster""")
    parser.add_argument("action", help="action for dirdeck")
    parser.add_argument("arg1", nargs="?", default="", help="positional argument 1")
    parser.add_argument("arg2", nargs="?", default="", help="posional argument 2")
    parser.add_argument("arg3", nargs="?", default="", help="posional argument 3")

    args = parser.parse_args()

    reSG_dat: str = os.getenv("reSG_dat")
    if not reSG_dat:
        raise EnvironmentError("env:reSG_dat is necessary for this dk.py")
    if not os.path.exists(reSG_dat):
        namedirs = {}
    else:
        try:
            namedirs = json.load(open(reSG_dat, "r"))
        except:
            raise RuntimeError("Fail to load reSG_dat to a dict")

    if args.action == "s":
        save_dir(args.arg1, args.arg2)
    elif args.action == "g":
        goto_dir(args.arg1)
    elif args.action == "list":
        list_dirs()
    elif args.action == "del":
        delete_dir(args.arg1)
    elif args.action == "clear":
        clear_dirs()