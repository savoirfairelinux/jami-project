#!/usr/bin/env python3
#
# This is the Ring build helper, it can do these things:
#  - Build Ring
#  - Install Ring
#  - Run Ring
#

import argparse
import os
import subprocess
import sys
import time
import platform
import multiprocessing
import shutil

DEBIAN_BASED_DISTROS = [
    'Debian',
    'Ubuntu',
]

RPM_BASED_DISTROS = [
    'Fedora',
]

PACMAN_BASED_DISTROS = [
    'Arch Linux',
]

SUSE_BASED_DISTROS = [
    'openSUSE',
]

APT_INSTALL_SCRIPT = [
    'apt-get update',
    'apt-get install -y %(packages)s'
]

BREW_INSTALL_SCRIPT = [
    'brew update',
    'brew install -y %(packages)s',
    'brew link --force gettext'
]

RPM_INSTALL_SCRIPT = [
    'sudo dnf update',
    'sudo dnf install -y %(packages)s'
]

PACMAN_INSTALL_SCRIPT = [
    'sudo pacman -Sy',
    'sudo pacman -S %(packages)s'
]

ZYPPER_INSTALL_SCRIPT = [
    'sudo zypper update',
    'sudo zypper install -y %(packages)s'
]

OPENSUSE_DEPENDENCIES = [
# build system
    'autoconf', 'automake', 'cmake', 'patch', 'gcc-c++', 'libtool',
# daemon
    'speexdsp-devel', 'speex-devel', 'libdbus-c++-devel', 'jsoncpp-devel', 'yaml-cpp-devel',
    'libupnp-devel', 'boost-devel', 'yasm', 'libuuid-devel', 'libsamplerate-devel',
    'libnettle-devel', 'libopus-devel', 'libgnutls-devel', 'msgpack-devel', 'libavcodec-devel',
    'libavdevice-devel', 'pcre-devel', 'libogg-devel', 'libsndfile-devel', 'libvorbis-devel',
    'flac-devel', 'libgsm-devel', 'alsa-devel', 'libpulse-devel', 'libudev-devel', 'libva-devel',
# lrc
    'libQt5Core-devel', 'libQt5DBus-devel', 'libqt5-linguist-devel',
# gnome client
    'gtk3-devel', 'clutter-gtk-devel', 'qrencode-devel', 'evolution-data-server-devel',
    'gettext-tools', 'libnotify-devel', 'libappindicator3-devel',
]

MINGW64_FEDORA_DEPENDENCIES = [
    'mingw64-binutils', 'mingw64-gcc', 'mingw64-headers', 'mingw64-crt', 'mingw64-gcc-c++',
    'mingw64-pkg-config', 'yasm', 'gettext-devel', 'cmake', 'patch', 'libtool', 'automake',
    'make', 'xz', 'bzip2', 'which', 'mingw64-qt5-qtbase', 'mingw64-qt5-qttools',
    'mingw64-qt5-qtsvg', 'mingw64-qt5-qtwinextras'
]

MINGW32_FEDORA_DEPENDENCIES = [
    'mingw32-binutils', 'mingw32-gcc', 'mingw32-headers', 'mingw32-crt', 'mingw32-gcc-c++',
    'mingw32-pkg-config', 'yasm', 'gettext-devel', 'cmake', 'patch', 'libtool', 'automake',
    'make', 'xz', 'bzip2', 'which', 'mingw32-qt5-qtbase', 'mingw32-qt5-qttools',
    'mingw32-qt5-qtsvg', 'mingw32-qt5-qtwinextras'
]

FEDORA_DEPENDENCIES = [
    'autoconf', 'automake', 'cmake', 'speexdsp-devel', 'pulseaudio-libs-devel',
    'libsamplerate-devel', 'libtool', 'dbus-devel', 'expat-devel', 'pcre-devel',
    'yaml-cpp-devel', 'boost-devel', 'dbus-c++-devel', 'dbus-devel',
    'libsndfile-devel', 'libXext-devel', 'libXfixes-devel', 'yasm',
    'speex-devel', 'chrpath', 'check', 'astyle', 'uuid-c++-devel', 'gettext',
    'gcc-c++', 'which', 'alsa-lib-devel', 'systemd-devel', 'libuuid-devel',
    'uuid-devel', 'gnutls-devel', 'nettle-devel', 'opus-devel', 'speexdsp-devel',
    'yaml-cpp-devel', 'qt5-qtbase-devel', 'swig', 'qrencode-devel', 'jsoncpp-devel',
    'gtk3-devel', 'clutter-devel', 'clutter-gtk-devel', 'evolution-data-server-devel',
    'libnotify-devel', 'libappindicator-gtk3-devel', 'patch', 'libva-devel'
]

UBUNTU_DEPENDENCIES = [
    'autoconf', 'autopoint', 'cmake', 'dbus', 'doxygen', 'g++', 'gettext',
    'gnome-icon-theme-symbolic', 'libasound2-dev', 'libavcodec-dev',
    'libavcodec-extra', 'libavdevice-dev', 'libavformat-dev', 'libboost-dev',
    'libclutter-gtk-1.0-dev', 'libcppunit-dev', 'libdbus-1-dev',
    'libdbus-c++-dev', 'libebook1.2-dev', 'libexpat1-dev', 'libgnutls-dev',
    'libgsm1-dev', 'libgtk-3-dev', 'libjack-dev', 'libnotify-dev',
    'libopus-dev', 'libpcre3-dev', 'libpulse-dev', 'libsamplerate0-dev',
    'libsndfile1-dev', 'libspeex-dev', 'libspeexdsp-dev', 'libswscale-dev', 'libtool',
    'libudev-dev', 'libupnp-dev', 'libyaml-cpp-dev', 'qtbase5-dev', 'sip-tester', 'swig',
    'uuid-dev', 'yasm', 'libqrencode-dev', 'libjsoncpp-dev', 'libappindicator3-dev',
    'libva-dev'
]

DEBIAN_DEPENDENCIES = [
    'autoconf', 'autopoint', 'cmake', 'dbus', 'doxygen', 'g++', 'gettext',
    'gnome-icon-theme-symbolic', 'libasound2-dev', 'libavcodec-dev',
    'libavcodec-extra', 'libavdevice-dev', 'libavformat-dev', 'libboost-dev',
    'libclutter-gtk-1.0-dev', 'libcppunit-dev', 'libdbus-1-dev',
    'libdbus-c++-dev', 'libebook1.2-dev', 'libexpat1-dev', 'libgnutls-dev',
    'libgsm1-dev', 'libgtk-3-dev', 'libjack-dev', 'libnotify-dev',
    'libopus-dev', 'libpcre3-dev', 'libpulse-dev', 'libsamplerate0-dev',
    'libsndfile1-dev', 'libspeex-dev', 'libspeexdsp-dev', 'libswscale-dev', 'libtool',
    'libudev-dev', 'libupnp-dev', 'libyaml-cpp-dev', 'qtbase5-dev', 'sip-tester', 'swig',
    'uuid-dev', 'yasm', 'libqrencode-dev', 'libjsoncpp-dev', 'libappindicator3-dev',
    'libva-dev'
]

ARCH_LINUX_DEPENDENCIES = [
    'autoconf', 'gettext', 'cmake', 'dbus', 'doxygen', 'gcc', 'gnome-icon-theme-symbolic',
    'ffmpeg', 'boost', 'clutter-gtk', 'cppunit', 'libdbus', 'dbus-c++', 'libe-book',
    'expat', 'gsm', 'gtk3', 'jack', 'libnotify', 'opus', 'pcre', 'libpulse', 'libsamplerate',
    'libsndfile', 'speex', 'speexdsp', 'libtool', 'libupnp', 'yaml-cpp', 'qt5-base',
    'swig', 'yasm', 'qrencode', 'evolution-data-server', 'make', 'patch', 'pkg-config',
    'automake', 'libva'
]

OSX_DEPENDENCIES = [
    'autoconf', 'cmake', 'gettext', 'pkg-config', 'homebrew/versions/qt55',
    'libtool', 'yasm', 'automake'
]

UNINSTALL_SCRIPT = [
    'make -C daemon uninstall',
    'xargs rm < lrc/build-global/install_manifest.txt',
    'xargs rm < client-gnome/build-global/install_manifest.txt',
]

OSX_UNINSTALL_SCRIPT = [
    'make -C daemon uninstall',
    'rm -rf install/client-macosx',
]

STOP_SCRIPT = [
    'xargs kill < daemon.pid',
    'xargs kill < gnome-ring.pid',
]


def run_dependencies(args):
    if args.distribution == "Ubuntu":
        execute_script(APT_INSTALL_SCRIPT,
            {"packages": ' '.join(UBUNTU_DEPENDENCIES)}
        )

    elif args.distribution == "Debian":
        execute_script(
            APT_INSTALL_SCRIPT,
            {"packages": ' '.join(DEBIAN_DEPENDENCIES)}
        )

    elif args.distribution == "Fedora":
        execute_script(
            RPM_INSTALL_SCRIPT,
            {"packages": ' '.join(FEDORA_DEPENDENCIES)}
        )
    elif args.distribution == "mingw32":
        execute_script(
            RPM_INSTALL_SCRIPT,
            {"packages": ' '.join(MINGW32_FEDORA_DEPENDENCIES)}
        )
    elif args.distribution == "mingw64":
        execute_script(
            RPM_INSTALL_SCRIPT,
            {"packages": ' '.join(MINGW64_FEDORA_DEPENDENCIES)}
        )
    elif args.distribution == "Arch Linux":
        execute_script(
            PACMAN_INSTALL_SCRIPT,
            {"packages": ' '.join(ARCH_LINUX_DEPENDENCIES)}
        )

    elif args.distribution == "openSUSE":
        execute_script(
            ZYPPER_INSTALL_SCRIPT,
            {"packages": ' '.join(OPENSUSE_DEPENDENCIES)}
        )

    elif args.distribution == "OSX":
        execute_script(
            BREW_INSTALL_SCRIPT,
            {"packages": ' '.join(OSX_DEPENDENCIES)}
        )

    elif args.distribution == "Android":
        print("The Android version does not need more dependencies.\nPlease continue with the --install instruction.")
        sys.exit(1)

    else:
        print("Not yet implemented for current distribution (%s)" % args.distribution)
        sys.exit(1)

def run_init():
    os.system("git submodule update --init")
    os.system("git submodule foreach 'git checkout master && git pull'")
    for project in ["daemon", "lrc", "client-macosx", "client-gnome", "client-android"]:
        copy_file("./scripts/commit-msg", ".git/modules/"+project+"/hooks")

def copy_file(src, dest):
    print("Copying:" + src + " to " + dest)
    try:
        shutil.copy2(src, dest)
    # eg. src and dest are the same file
    except shutil.Error as e:
        print('Error: %s' % e)
    # eg. source or destination doesn't exist
    except IOError as e:
        print('Error: %s' % e.strerror)

def run_install(args):
    install_args = ' -p ' + str(multiprocessing.cpu_count())
    if args.static:
        install_args += ' -s'
    if args.global_install:
        install_args += ' -g'
    if args.distribution == "OSX":
        proc= subprocess.Popen("brew --prefix homebrew/versions/qt55", shell=True, stdout=subprocess.PIPE)
        qt5dir = proc.stdout.read()
        os.environ['CMAKE_PREFIX_PATH'] = str(qt5dir.decode('ascii'))
        install_args += " -c client-macosx"
        execute_script(["CONFIGURE_FLAGS='--without-dbus' ./scripts/install.sh " + install_args])
    elif args.distribution == "Android":
        os.chdir("./client-android")
        execute_script(["./compile.sh"])
    elif args.distribution == 'mingw32':
        os.environ['CMAKE_PREFIX_PATH'] = '/usr/i686-w64-mingw32/sys-root/mingw/lib/cmake'
        os.environ['QTDIR'] = '/usr/i686-w64-mingw32/sys-root/mingw/lib/qt5/'
        os.environ['PATH'] = '/usr/i686-w64-mingw32/bin/qt5/:' + os.environ['PATH']
        execute_script(["./scripts/win_compile.sh"])
    elif args.distribution == 'mingw64':
        os.environ['CMAKE_PREFIX_PATH'] = '/usr/x86_64-w64-mingw32/sys-root/mingw/lib/cmake'
        os.environ['QTDIR'] = '/usr/x86_64-w64-mingw32/sys-root/mingw/lib/qt5/'
        os.environ['PATH'] = '/usr/x86_64-w64-mingw32/bin/qt5/:' + os.environ['PATH']
        execute_script(["./scripts/win_compile.sh --arch=64"])
    else:
        if args.distribution == "openSUSE":
            os.environ['JSONCPP_LIBS'] = "-ljsoncpp" #fix jsoncpp pkg-config bug, remove when jsoncpp package bumped
        install_args += ' -c client-gnome'
        execute_script(["./scripts/install.sh " + install_args])


def run_uninstall(args):
    if args.distribution == "OSX":
        execute_script(OSX_UNINSTALL_SCRIPT)
    else:
        execute_script(UNINSTALL_SCRIPT)


def run_run(args):
    if args.distribution == "OSX":
        subprocess.Popen(["install/client-macosx/Ring.app/Contents/MacOS/Ring"])
        return True

    run_env = os.environ
    run_env['LD_LIBRARY_PATH'] = run_env.get('LD_LIBRARY_PATH', '') + ":install/lrc/lib"

    try:
        dring_log = open("daemon.log", 'a')
        dring_log.write('=== Starting daemon (%s) ===' % time.strftime("%d/%m/%Y %H:%M:%S"))
        dring_process = subprocess.Popen(
            ["./install/daemon/lib/ring/dring", "-c", "-d"],
            stdout=dring_log,
            stderr=dring_log
        )

        with open('daemon.pid', 'w') as f:
            f.write(str(dring_process.pid)+'\n')

        client_log = open("gnome-ring.log", 'a')
        client_log.write('=== Starting client (%s) ===' % time.strftime("%d/%m/%Y %H:%M:%S"))
        client_process = subprocess.Popen(
            ["./install/client-gnome/bin/gnome-ring", "-d"],
            stdout=client_log,
            stderr=client_log,
            env=run_env
        )

        with open('gnome-ring.pid', 'w') as f:
            f.write(str(client_process.pid)+'\n')

        if args.debug:
            subprocess.call(
                ['gdb','-x', 'gdb.gdb', './install/daemon/lib/ring/dring'],
            )

        if args.background == False:
            dring_process.wait()
            client_process.wait()

    except KeyboardInterrupt:
        print("\nCaught KeyboardInterrupt...")

    finally:
        if args.background == False:
            try:
                # Only kill the processes if they are running, as they could
                # have been closed by the user.
                print("Killing processes...")
                dring_log.close()
                if dring_process.poll() is None:
                    dring_process.kill()
                client_log.close()
                if client_process.poll() is None:
                    client_process.kill()
            except UnboundLocalError:
                # Its okay! We crashed before we could start a process or open a
                # file. All that matters is that we close files and kill processes
                # in the right order.
                pass
    return True


def run_stop(args):
    execute_script(STOP_SCRIPT)


def execute_script(script, settings=None):
    if settings == None:
        settings = {}
    for line in script:
        line = line % settings
        rv = os.system(line)
        if rv != 0:
            print('Error executing script! Exit code: %s' % rv,
                  file=sys.stderr)
            return False
    return True


def validate_args(parsed_args):
    """Validate the args values, exit if error is found"""

    # Check arg values
    supported_distros = ['Android', 'Ubuntu', 'Debian', 'OSX', 'Fedora', 'Arch Linux', 'openSUSE', 'Automatic', 'mingw32', 'mingw64']

    if parsed_args.distribution not in supported_distros:
        print('Distribution not supported.\nChoose one of: %s' \
                  % ', '.join(supported_distros),
            file=sys.stderr)
        sys.exit(1)

def parse_args():
    ap = argparse.ArgumentParser(description="Ring build tool")

    ga = ap.add_mutually_exclusive_group(required=True)
    ga.add_argument(
        '--init', action='store_true',
        help='Init Ring repository')
    ga.add_argument(
        '--dependencies', action='store_true',
        help='Install ring build dependencies')
    ga.add_argument(
        '--install', action='store_true',
        help='Build and install Ring')
    ga.add_argument(
        '--uninstall', action='store_true',
        help='Uninstall Ring')
    ga.add_argument(
        '--run', action='store_true',
         help='Run the Ring daemon and client')
    ga.add_argument(
        '--stop', action='store_true',
        help='Stop the Ring processes')

    ap.add_argument('--distribution', default='Automatic')
    ap.add_argument('--static', default=False, action='store_true')
    ap.add_argument('--global-install', default=False, action='store_true')
    ap.add_argument('--debug', default=False, action='store_true')
    ap.add_argument('--background', default=False, action='store_true')

    parsed_args = ap.parse_args()

    if parsed_args.distribution == 'Automatic':
        parsed_args.distribution = choose_distribution()

    if parsed_args.distribution in ['mingw32', 'mingw64']:
        if choose_distribution() != "Fedora":
            print('Windows version must be built on a Fedora distribution (>=23)')
            sys.exit(1)

    validate_args(parsed_args)

    return parsed_args

def choose_distribution():
    system = platform.system().lower()
    if system == "linux" or system == "linux2":
        if os.path.isfile("/etc/arch-release"):
            return "Arch Linux"
        with open("/etc/os-release") as f:
            for line in f:
                k,v = line.split("=")
                if k.strip() == 'NAME':
                    return v.strip().replace('"','')
    elif system == "darwin":
        return 'OSX'

    return 'Unknown'


def main():
    parsed_args = parse_args()

    if parsed_args.dependencies:
        run_dependencies(parsed_args)

    elif parsed_args.init:
        run_init()

    elif parsed_args.install:
        run_install(parsed_args)

    elif parsed_args.uninstall:
        run_uninstall(parsed_args)

    elif parsed_args.run:
        run_run(parsed_args)

    elif parsed_args.stop:
        run_stop(parsed_args)


if __name__ == "__main__":
    main()
