import argparse
import subprocess
import os
import sys

this_dir = os.path.dirname(os.path.realpath(__file__))


def execute_cmd(cmd, with_shell=False):
    p = subprocess.Popen(cmd, shell=with_shell)
    _, _ = p.communicate()
    if p.returncode != 0:
        sys.exit(1)
    return p.returncode


def build_daemon(parsed_args):
    make_cmd = os.path.dirname(this_dir) + '\\daemon\\compat\\msvc\\winmake.py'
    os.chdir(os.path.dirname(this_dir) + '\\daemon\\compat\\msvc')
    execute_cmd('python ' + make_cmd + ' -iv -s ' + parsed_args.sdk + ' -b daemon')
    os.chdir(os.path.dirname(this_dir))


def build_client(parsed_args):
    os.chdir('./client-qt')
    execute_cmd('python build.py init')
    execute_cmd('python build.py')


def parse_args():
    ap = argparse.ArgumentParser(description="Qt Client build tool")

    ap.add_argument('--sdk', default='', type=str,
                    help='Windows use only, specify Windows SDK version')

    parsed_args = ap.parse_args()

    return parsed_args


def main():
    parsed_args = parse_args()
    build_daemon(parsed_args)
    build_client(parsed_args)


if __name__ == "__main__":
    main()
