import subprocess
import os
import sys

this_dir = os.path.dirname(os.path.realpath(__file__))

def execute_cmd(cmd):
    p = subprocess.Popen(cmd)
    _, perr = p.communicate()
    if perr:
        return 1
    return 0

def build_daemon():
    make_cmd = os.path.dirname(this_dir) + '\\daemon\\msvc\\winmake.py'
    return execute_cmd('python ' + make_cmd + ' -iv -t v142 -b daemon')

def build_lrc():
    make_cmd = os.path.dirname(this_dir) + '\\lrc\\make-lrc.py'
    if execute_cmd('python ' + make_cmd + ' --gen') == 0:
        return execute_cmd('python ' + make_cmd + ' --build')
    return 1

def build_client():
    return 0

def main():
    if build_daemon() != 0:
        print('daemon build failure')
        sys.exit(1)
    
    if build_lrc() != 0:
        print('lrc build failure')
        sys.exit(1)
    
    
    build_client()

if __name__ == "__main__":
    main()
