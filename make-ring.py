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
import shlex
import shutil
import signal

IOS_DISTRIBUTION_NAME = "ios"
OSX_DISTRIBUTION_NAME = "osx"
ANDROID_DISTRIBUTION_NAME = "android"
WIN32_DISTRIBUTION_NAME = "win32"

QT5_VERSION = "5.15.0"

# vs vars
win_sdk_default = '10.0.16299.0'
win_toolset_default = '142'

APT_BASED_DISTROS = [
    'debian',
    'ubuntu',
    'trisquel',
    'linuxmint',
    'raspbian',
]

DNF_BASED_DISTROS = [
    'fedora', 'rhel',
]

PACMAN_BASED_DISTROS = [
    'arch',
]

ZYPPER_BASED_DISTROS = [
    'opensuse-leap', 'opensuse-tumbleweed',
]

FLATPAK_BASED_RUNTIMES = [
    'org.gnome.Platform',
]

APT_INSTALL_SCRIPT = [
    'apt-get update',
    'apt-get install -y %(packages)s'
]

BREW_UNLINK_SCRIPT = [
    'brew unlink %(packages)s'
]

BREW_INSTALL_SCRIPT = [
    'brew update',
    'brew install %(packages)s',
    'brew link --force --overwrite %(packages)s'
]

RPM_INSTALL_SCRIPT = [
    'dnf update',
    'dnf install -y %(packages)s'
]

PACMAN_INSTALL_SCRIPT = [
    'pacman -Sy',
    'pacman -S --asdeps --needed %(packages)s'
]

ZYPPER_INSTALL_SCRIPT = [
    'zypper update',
    'zypper install -y %(packages)s'
]

ZYPPER_DEPENDENCIES = [
    # build system
    'autoconf', 'autoconf-archive', 'automake', 'cmake', 'make', 'patch', 'gcc-c++',
    'libtool', 'which', 'pandoc','nasm', 'doxygen', 'graphviz',
    # contrib dependencies
    'curl', 'gzip', 'bzip2',
    # daemon
    'speexdsp-devel', 'speex-devel', 'libdbus-c++-devel', 'jsoncpp-devel', 'yaml-cpp-devel',
    'yasm', 'libuuid-devel', 'libnettle-devel', 'libopus-devel', 'libexpat-devel',
    'libgnutls-devel', 'msgpack-devel', 'libavcodec-devel', 'libavdevice-devel', 'pcre-devel',
    'alsa-devel', 'libpulse-devel', 'libudev-devel', 'libva-devel', 'libvdpau-devel',
    'libopenssl-devel', 'libavutil-devel',
    # lrc
    'libQt5Core-devel', 'libQt5DBus-devel', 'libqt5-linguist-devel',
    # client gnome / qt
    'qrencode-devel', 'NetworkManager-devel'
]

ZYPPER_CLIENT_GNOME_DEPENDENCIES = [
    'gtk3-devel', 'clutter-gtk-devel', 'gettext-tools', 'libnotify-devel', 'libappindicator3-devel',
    'webkit2gtk3-devel', 'libcanberra-gtk3-devel'
]

ZYPPER_CLIENT_QT_DEPENDENCIES = [
    'libqt5-qtsvg-devel', 'libqt5-qtwebengine-devel', 'libqt5-qtmultimedia-devel',
    'libqt5-qtdeclarative-devel', 'libQt5QuickControls2-devel', 'libqt5-qtquickcontrols'
]

DNF_DEPENDENCIES = [
    'autoconf', 'autoconf-archive', 'automake', 'cmake', 'make', 'speexdsp-devel', 'pulseaudio-libs-devel',
    'libtool', 'dbus-devel', 'expat-devel', 'pcre-devel', 'doxygen', 'graphviz',
    'yaml-cpp-devel', 'boost-devel', 'dbus-c++-devel', 'dbus-devel',
    'libXext-devel', 'libXfixes-devel', 'yasm',
    'speex-devel', 'chrpath', 'check', 'astyle', 'uuid-c++-devel', 'gettext-devel',
    'gcc-c++', 'which', 'alsa-lib-devel', 'systemd-devel', 'libuuid-devel',
    'uuid-devel', 'gnutls-devel', 'nettle-devel', 'opus-devel', 'speexdsp-devel',
    'yaml-cpp-devel', 'qt5-qtbase-devel', 'swig', 'jsoncpp-devel',
    'patch', 'libva-devel', 'openssl-devel', 'libvdpau-devel', 'msgpack-devel',
    'sqlite-devel', 'openssl-static', 'pandoc', 'nasm', 'qrencode-devel', 'NetworkManager-libnm-devel',
    'bzip2', 'qt5-qttools-devel'
]

DNF_CLIENT_GNOME_DEPENDENCIES = [
    'gtk3-devel', 'clutter-devel', 'clutter-gtk-devel', 'libnotify-devel','libappindicator-gtk3-devel',
    'webkitgtk4-devel', 'libcanberra-devel'
]

DNF_CLIENT_QT_DEPENDENCIES = [
    'qt5-qtsvg-devel', 'qt5-qtwebengine-devel', 'qt5-qtmultimedia-devel', 'qt5-qtdeclarative-devel',
    'qt5-qtquickcontrols2-devel', 'qt5-qtquickcontrols'
]

APT_DEPENDENCIES = [
    'autoconf', 'autoconf-archive', 'autopoint', 'automake', 'cmake', 'make', 'dbus', 'doxygen', 'graphviz',
    'g++', 'gettext', 'gnome-icon-theme-symbolic', 'libasound2-dev', 'libavcodec-dev',
    'libavdevice-dev', 'libavformat-dev', 'libboost-dev',
    'libclutter-gtk-1.0-dev', 'libcppunit-dev', 'libdbus-1-dev',
    'libdbus-c++-dev', 'libebook1.2-dev', 'libexpat1-dev', 'libgnutls28-dev',
    'libgtk-3-dev', 'libjack-dev', 'libnotify-dev',
    'libopus-dev', 'libpcre3-dev', 'libpulse-dev', 'libssl-dev',
    'libspeex-dev', 'libspeexdsp-dev', 'libswscale-dev', 'libtool',
    'libudev-dev', 'libyaml-cpp-dev', 'qtbase5-dev', 'libqt5sql5-sqlite', 'sip-tester', 'swig',
    'uuid-dev', 'yasm', 'libjsoncpp-dev', 'libva-dev', 'libvdpau-dev', 'libmsgpack-dev',
    'pandoc', 'nasm', 'libqrencode-dev', 'libnm-dev', 'dpkg-dev', 'qttools5-dev', 'qttools5-dev-tools'
]

APT_CLIENT_GNOME_DEPENDENCIES = [
    'libwebkit2gtk-4.0-dev', 'libappindicator3-dev', 'libcanberra-gtk3-dev'
]

APT_CLIENT_QT_DEPENDENCIES = [
    'qtmultimedia5-dev', 'libqt5svg5-dev', 'qtwebengine5-dev', 'qtdeclarative5-dev',
    'qtquickcontrols2-5-dev', 'qml-module-qtquick2', 'qml-module-qtquick-controls',
    'qml-module-qtquick-controls2', 'qml-module-qtquick-dialogs',
    'qml-module-qtquick-layouts', 'qml-module-qtquick-privatewidgets',
    'qml-module-qtquick-shapes', 'qml-module-qtquick-window2',
    'qml-module-qtquick-templates2', 'qml-module-qt-labs-platform',
    'qml-module-qtwebengine', 'qml-module-qtwebchannel'
]

PACMAN_DEPENDENCIES = [
    'autoconf', 'autoconf-archive', 'gettext', 'cmake', 'dbus', 'doxygen', 'graphviz',
    'gcc', 'ffmpeg', 'boost', 'cppunit', 'libdbus', 'dbus-c++', 'libe-book', 'expat',
    'jack', 'opus', 'pcre', 'libpulse', 'speex', 'speexdsp', 'libtool', 'yaml-cpp',
    'qt5-base', 'swig', 'yasm', 'qrencode', 'make', 'patch', 'pkg-config',
    'automake', 'libva', 'libnm', 'libvdpau', 'openssl', 'pandoc', 'nasm', 'qt5-tools'
]

PACMAN_CLIENT_GNOME_DEPENDENCIES = [
    'clutter-gtk','gnome-icon-theme-symbolic', 'gtk3', 'libappindicator-gtk3',
    'libcanberra', 'libnotify', 'webkit2gtk'
]

PACMAN_CLIENT_QT_DEPENDENCIES = [
    'qt5-declarative', 'qt5-graphicaleffects', 'qt5-multimedia', 'qt5-quickcontrols',
    'qt5-quickcontrols2', 'qt5-svg', 'qt5-tools', 'qt5-webengine'
]

OSX_DEPENDENCIES = [
    'autoconf', 'cmake', 'gettext', 'pkg-config', 'qt5',
    'libtool', 'yasm', 'nasm', 'automake', 'libtasn'
]

OSX_DEPENDENCIES_UNLINK = [
    'autoconf*', 'cmake*', 'gettext*', 'pkg-config*', 'qt*', 'qt@5.*',
    'libtool*', 'yasm*', 'nasm*', 'automake*', 'gnutls*', 'nettle*', 'msgpack*',
    'libtasn'
]

IOS_DEPENDENCIES = [
    'autoconf', 'automake', 'cmake', 'yasm', 'libtool',
    'pkg-config', 'gettext', 'swiftlint', 'swiftgen', 'libtasn'
]

IOS_DEPENDENCIES_UNLINK = [
    'autoconf*', 'automake*', 'cmake*', 'yasm*', 'libtool*',
    'pkg-config*', 'gettext*', 'swiftlint*', 'swiftgen*', 'libtasn'
]

UNINSTALL_DAEMON_SCRIPT = [
    'make -C daemon uninstall'
]

OSX_UNINSTALL_SCRIPT = [
    'make -C daemon uninstall',
    'rm -rf install/client-macosx'
]

def run_powersell_cmd(cmd):
    p = subprocess.Popen(["powershell.exe", cmd], stdout=sys.stdout)
    p.communicate()
    p.wait()
    return


def write_qt_conf(path, qt5version=QT5_VERSION):
    # Add a configuration that can be supplied to qmake
    # e.g. `qmake -qt=5.15 [mode] [options] [files]`
    if path == '':
        return
    with open('/usr/share/qtchooser/' + qt5version + '.conf', 'w+') as fd:
        fd.write(path.rstrip('/') + '/bin\n')
        fd.write(path.rstrip('/') + '/lib\n')
    return


def run_dependencies(args):
    if args.qt is not None:
        write_qt_conf(args.qt, args.qtver)

    if args.distribution == WIN32_DISTRIBUTION_NAME:
        run_powersell_cmd(
            'Set-ExecutionPolicy Unrestricted; .\\scripts\\install-deps-windows.ps1')

    elif args.distribution in APT_BASED_DISTROS:
        if args.qt is None:
            APT_DEPENDENCIES.extend(APT_CLIENT_GNOME_DEPENDENCIES)
        else:
            APT_DEPENDENCIES.extend(APT_CLIENT_QT_DEPENDENCIES)
        execute_script(
            APT_INSTALL_SCRIPT,
            {"packages": ' '.join(map(shlex.quote, APT_DEPENDENCIES))}
        )

    elif args.distribution in DNF_BASED_DISTROS:
        if args.qt is None:
            DNF_DEPENDENCIES.extend(DNF_CLIENT_GNOME_DEPENDENCIES)
        else:
            DNF_DEPENDENCIES.extend(DNF_CLIENT_QT_DEPENDENCIES)
        execute_script(
            RPM_INSTALL_SCRIPT,
            {"packages": ' '.join(map(shlex.quote, DNF_DEPENDENCIES))}
        )

    elif args.distribution in PACMAN_BASED_DISTROS:
        if args.qt is None:
            PACMAN_DEPENDENCIES.extend(PACMAN_CLIENT_GNOME_DEPENDENCIES)
        else:
            PACMAN_DEPENDENCIES.extend(PACMAN_CLIENT_QT_DEPENDENCIES)
        execute_script(
            PACMAN_INSTALL_SCRIPT,
            {"packages": ' '.join(map(shlex.quote, PACMAN_DEPENDENCIES))}
        )

    elif args.distribution in ZYPPER_BASED_DISTROS:
        if args.qt is None:
            ZYPPER_DEPENDENCIES.extend(ZYPPER_CLIENT_GNOME_DEPENDENCIES)
        else:
            ZYPPER_DEPENDENCIES.extend(ZYPPER_CLIENT_QT_DEPENDENCIES)
        execute_script(
            ZYPPER_INSTALL_SCRIPT,
            {"packages": ' '.join(map(shlex.quote, ZYPPER_DEPENDENCIES))}
        )

    elif args.distribution == OSX_DISTRIBUTION_NAME:
        execute_script(
            BREW_UNLINK_SCRIPT,
            {"packages": ' '.join(map(shlex.quote, OSX_DEPENDENCIES_UNLINK))},
            False
        )
        execute_script(
            BREW_INSTALL_SCRIPT,
            {"packages": ' '.join(map(shlex.quote, OSX_DEPENDENCIES))},
            False
        )

    elif args.distribution == IOS_DISTRIBUTION_NAME:
        execute_script(
            BREW_UNLINK_SCRIPT,
            {"packages": ' '.join(map(shlex.quote, IOS_DEPENDENCIES_UNLINK))},
            False
        )
        execute_script(
            BREW_INSTALL_SCRIPT,
            {"packages": ' '.join(map(shlex.quote, IOS_DEPENDENCIES))},
            False
        )

    elif args.distribution == ANDROID_DISTRIBUTION_NAME:
        print("The Android version does not need more dependencies.\nPlease continue with the --install instruction.")
        sys.exit(1)

    elif args.distribution == WIN32_DISTRIBUTION_NAME:
        print("The win32 version does not install dependencies with this script.\nPlease continue with the --install instruction.")
        sys.exit(1)

    else:
        print("Not yet implemented for current distribution (%s). Please continue with the --install instruction. Note: You may need to install some dependencies manually." %
              args.distribution)
        sys.exit(1)


def run_init():
    # Extract modules path from '.gitmodules' file
    module_names = []
    with open('.gitmodules') as fd:
        for line in fd.readlines():
            if line.startswith('[submodule "'):
                module_names.append(line[line.find('"')+1:line.rfind('"')])

    subprocess.run(["git", "submodule", "update", "--init"], check=True)
    subprocess.run(["git", "submodule", "foreach",
                    "git checkout master && git pull"], check=True)
    for name in module_names:
        copy_file("./scripts/commit-msg", ".git/modules/"+name+"/hooks")

    module_names_to_format = ['daemon', 'lrc', 'client-qt', 'plugins']
    for name in module_names_to_format:
        execute_script(
            ['./scripts/format.sh --install  %(path)s'],
            {"path": ".git/modules/" + name + "/hooks"}
        )


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
    # Platforms with special compilation scripts
    if args.distribution == IOS_DISTRIBUTION_NAME:
        return subprocess.run(["./compile-ios.sh"], cwd="./client-ios", check=True)
    elif args.distribution == ANDROID_DISTRIBUTION_NAME:
        return subprocess.run(["./compile.sh"], cwd="./client-android", check=True)
    elif args.distribution == WIN32_DISTRIBUTION_NAME:
        return subprocess.run([
            sys.executable, os.path.join(
                os.getcwd(), "scripts/build-windows.py"),
            "--toolset", args.toolset,
            "--sdk", args.sdk,
            "--qtver", args.qtver
        ], check=True)

    # Unix-like platforms
    environ = os.environ.copy()

    install_args = ['-p', str(multiprocessing.cpu_count())]
    if args.static:
        install_args.append('-s')
    if args.global_install:
        install_args.append('-g')
    if args.prefix is not None:
        install_args += ('-P', args.prefix)
    if not args.priv_install:
        install_args.append('-u')

    if args.distribution == OSX_DISTRIBUTION_NAME:
        # The `universal_newlines` parameter has been renamed to `text` in
        # Python 3.7+ and triggering automatical binary to text conversion is
        # what it actually does
        proc = subprocess.run(["brew", "--prefix", "qt5"],
                              stdout=subprocess.PIPE, check=True,
                              universal_newlines=True)

        environ['CMAKE_PREFIX_PATH'] = proc.stdout.rstrip("\n")
        environ['CONFIGURE_FLAGS'] = '--without-dbus'
        install_args += ("-c", "client-macosx")
    else:
        if args.distribution in ZYPPER_BASED_DISTROS:
            # fix jsoncpp pkg-config bug, remove when jsoncpp package bumped
            environ['JSONCPP_LIBS'] = "-ljsoncpp"
        if args.qt is None:
            install_args += ("-c", "client-gnome")
        else:
            install_args += ("-c", "client-qt")
            install_args += ("-q", args.qtver)
            install_args += ("-Q", args.qt)

    return subprocess.run(["./scripts/install.sh"] + install_args, env=environ, check=True)


def run_uninstall(args):
    if args.distribution == OSX_DISTRIBUTION_NAME:
        execute_script(OSX_UNINSTALL_SCRIPT)
    else:
        execute_script(UNINSTALL_DAEMON_SCRIPT)

        CLIENT_SUFFIX = 'qt' if (args.qt is not None) else 'gnome'
        INSTALL_DIR = '/build-global' if args.global_install else '/build-local'

        # Client needs to be uninstalled first
        if (os.path.exists('./client-' + CLIENT_SUFFIX + INSTALL_DIR)):
            UNINSTALL_CLIENT = [
                 'make -C client-' + CLIENT_SUFFIX + INSTALL_DIR + ' uninstall',
                 'rm -rf ./client-' + CLIENT_SUFFIX + INSTALL_DIR
            ]
            execute_script(UNINSTALL_CLIENT)

        if (os.path.exists('./lrc' + INSTALL_DIR)):
            UNINSTALL_LRC = [
                'make -C lrc' + INSTALL_DIR + ' uninstall',
                'rm -rf ./lrc' + INSTALL_DIR
            ]
            execute_script(UNINSTALL_LRC)

def run_run(args):
    if args.distribution == OSX_DISTRIBUTION_NAME:
        subprocess.Popen(
            ["install/client-macosx/Ring.app/Contents/MacOS/Ring"])
        return True

    run_env = os.environ
    run_env['LD_LIBRARY_PATH'] = run_env.get(
        'LD_LIBRARY_PATH', '') + ":install/lrc/lib"

    try:
        dring_log = open("daemon.log", 'a')
        dring_log.write('=== Starting daemon (%s) ===' %
                        time.strftime("%d/%m/%Y %H:%M:%S"))
        dring_process = subprocess.Popen(
            ["./install/daemon/lib/ring/dring", "-c", "-d"],
            stdout=dring_log,
            stderr=dring_log
        )

        with open('daemon.pid', 'w') as f:
            f.write(str(dring_process.pid)+'\n')

        client_suffix = ""
        if args.qt is not None:
            client_suffix += "qt"
        else:
            client_suffix += "gnome"
        client_log = open("jami-" + client_suffix + ".log", 'a')
        client_log.write('=== Starting client (%s) ===' %
                         time.strftime("%d/%m/%Y %H:%M:%S"))
        client_process = subprocess.Popen(
            ["./install/client-" + client_suffix +
                "/bin/jami-" + client_suffix, "-d"],
            stdout=client_log,
            stderr=client_log,
            env=run_env
        )

        with open("jami-" + client_suffix + ".pid", 'w') as f:
            f.write(str(client_process.pid)+'\n')

        if args.debug:
            subprocess.call(
                ['gdb', '-x', 'gdb.gdb', './install/daemon/lib/ring/dring'],
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
    client_suffix = "qt" if (args.qt is not None) else "gnome"
    STOP_SCRIPT = [
        'xargs kill < daemon.pid',
        'xargs kill < jami-' + client_suffix + '.pid'
    ]
    execute_script(STOP_SCRIPT)


def execute_script(script, settings=None, fail=True):
    if settings == None:
        settings = {}
    for line in script:
        line = line % settings
        rv = os.system(line)
        if rv != 0 and fail == True:
            print('Error executing script! Exit code: %s' %
                  rv, file=sys.stderr)
            sys.exit(1)


def validate_args(parsed_args):
    """Validate the args values, exit if error is found"""

    # Filter unsupported distributions.
    supported_distros = [
        ANDROID_DISTRIBUTION_NAME, OSX_DISTRIBUTION_NAME, IOS_DISTRIBUTION_NAME,
        WIN32_DISTRIBUTION_NAME
    ] + APT_BASED_DISTROS + DNF_BASED_DISTROS + PACMAN_BASED_DISTROS \
      + ZYPPER_BASED_DISTROS + FLATPAK_BASED_RUNTIMES

    if parsed_args.distribution not in supported_distros:
        print('WARNING: Distribution \'{0}\' not supported.\nChoose one of: {1}'.format(
            parsed_args.distribution, ', '.join(supported_distros)
        ), file=sys.stderr)

    # The Qt client support will be added incrementally.
    if parsed_args.qt is not None:
        supported_qt_distros = [
            WIN32_DISTRIBUTION_NAME
        ] + APT_BASED_DISTROS + DNF_BASED_DISTROS + PACMAN_BASED_DISTROS

        if parsed_args.distribution not in supported_qt_distros:
            print('Distribution \'{0}\' not supported when building the Qt client.'
                  '\nChoose one of: {1}'.format(
                      parsed_args.distribution, ', '.join(supported_qt_distros)
                  ), file=sys.stderr)
            sys.exit(1)

    # The windows client can only be built on a Windows 10 host.
    if parsed_args.distribution == WIN32_DISTRIBUTION_NAME:
        if platform.release() != '10':
            print('Windows version must be built on Windows 10')
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

    ap.add_argument('--distribution')
    ap.add_argument('--prefix')
    ap.add_argument('--static', default=False, action='store_true')
    ap.add_argument('--global-install', default=False, action='store_true')
    ap.add_argument('--debug', default=False, action='store_true')
    ap.add_argument('--background', default=False, action='store_true')
    ap.add_argument('--no-priv-install', dest='priv_install',
                    default=True, action='store_false')
    ap.add_argument('--qt', nargs='?', const='', type=str,
                    help='Build the Qt client with the Qt path supplied')
    ap.add_argument('--qtver', default=QT5_VERSION,
                    help='Sets the Qt version to build with')

    dist = choose_distribution()
    if dist == WIN32_DISTRIBUTION_NAME:
        ap.add_argument('--toolset', default=win_toolset_default, type=str,
                        help='Windows use only, specify Visual Studio toolset version')
        ap.add_argument('--sdk', default=win_sdk_default, type=str,
                        help='Windows use only, specify Windows SDK version')

    parsed_args = ap.parse_args()

    if (parsed_args.distribution is not None):
        parsed_args.distribution = parsed_args.distribution.lower()
    else:
        parsed_args.distribution = dist

    validate_args(parsed_args)

    return parsed_args


def choose_distribution():
    system = platform.system().lower()

    if system == "linux" or system == "linux2":
        if os.path.isfile("/etc/arch-release"):
            return "arch"
        with open("/etc/os-release") as f:
            for line in f:
                k, v = line.split("=")
                if k.strip() == 'ID':
                    return v.strip().replace('"', '').split(' ')[0]
    elif system == "darwin":
        return OSX_DISTRIBUTION_NAME
    elif system == "windows":
        return WIN32_DISTRIBUTION_NAME

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
