import subprocess
import os
import sys

this_dir = os.path.dirname(os.path.realpath(__file__))


def execute_cmd(cmd, with_shell=False):
    p = subprocess.Popen(cmd, shell=with_shell)
    _, perr = p.communicate()
    if perr:
        return 1
    return 0


def build_daemon():
    make_cmd = os.path.dirname(this_dir) + '\\daemon\\msvc\\winmake.py'
    return execute_cmd('python ' + make_cmd + ' -iv -t v142 -b daemon')


def build_lrc():
    make_cmd = os.path.dirname(this_dir) + '\\lrc\\make-lrc.py'
    return execute_cmd('python ' + make_cmd + ' -gb')


def build_client():
    print('Building lrc Release|x64')
    os.chdir('./client-windows')
    ret = 0
    if not os.path.exists('./qrencode-win32'):
        ret &= not execute_cmd('call fetch-deps.bat', True)
    ret &= not execute_cmd('call build-client.bat deps x64', True)
    if not os.path.exists('./x64/Release/qt.conf'):
        ret &= not execute_cmd('pandoc -f markdown -t html5 -o changelog.html changelog.md', True)
    ret &= not execute_cmd(
        'call build-client.bat build x64', True)
    if not os.path.exists('./x64/Release/qt.conf'):
        ret &= not execute_cmd(
            'powershell -ExecutionPolicy Unrestricted -File copy-runtime-files.ps1', True)
    return ret


def main():
    if build_daemon() != 0:
        print('daemon build failure!')
        sys.exit(1)

    if build_lrc() != 0:
        print('lrc build failure!')
        sys.exit(1)

    if build_client() != 0:
        print('client build failure!')
        sys.exit(1)


if __name__ == "__main__":
    main()
