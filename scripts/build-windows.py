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

def generate_msi():
    os.chdir(os.path.dirname(this_dir) + '\\client-qt')
    execute_cmd('python make-client.py --msi')
    os.chdir(os.path.dirname(this_dir))

def build_daemon(parsed_args):
    make_cmd = os.path.dirname(this_dir) + '\\daemon\\compat\\msvc\\winmake.py'
    os.chdir(os.path.dirname(this_dir) + '\\daemon\\compat\\msvc')
    execute_cmd('python ' + make_cmd + ' -iv -t ' +
                parsed_args.toolset + ' -s ' + parsed_args.sdk + ' -b daemon')
    os.chdir(os.path.dirname(this_dir))


def build_lrc(parsed_args):
    make_cmd = os.path.dirname(this_dir) + '\\lrc\\make-lrc.py'
    execute_cmd('python ' + make_cmd + ' -gb ' + ' -t ' + parsed_args.toolset + ' -s ' + parsed_args.sdk + ' -q ' + parsed_args.qtver)


def build_client(parsed_args):
    os.chdir('./client-qt')
    execute_cmd('pandoc -f markdown -t html5 -o changelog.html changelog.md', True)
    execute_cmd('python make-client.py -d')
    execute_cmd('python make-client.py -b ' + '-t ' +
                parsed_args.toolset + ' -s ' + parsed_args.sdk + ' -q ' + parsed_args.qtver)
    execute_cmd('powershell -ExecutionPolicy Unrestricted -File copy-runtime-files.ps1' + ' "Release" ' + '"' + parsed_args.qtver + '"', True)


def parse_args():
    ap = argparse.ArgumentParser(description="Qt Client build tool")

    ap.add_argument('--toolset', default='', type=str,
                    help='Windows use only, specify Visual Studio toolset version')
    ap.add_argument('--sdk', default='', type=str,
                    help='Windows use only, specify Windows SDK version')
    ap.add_argument('--qtver', default='5.15.0',
                    help='Sets the Qt version to build with')
    ap.add_argument('--msi', action='store_true',
                    help='Generate msi')

    parsed_args = ap.parse_args()

    return parsed_args


def main():
    parsed_args = parse_args()
    if parsed_args.msi:
        generate_msi()
    else:
        build_daemon(parsed_args)
        build_lrc(parsed_args)
        build_client(parsed_args)


if __name__ == "__main__":
    main()
