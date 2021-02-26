// Packaging validation for supported GNU/Linux systems.
//
// Note: To work on this script without having to push a commit each
// time, use the jenkins-cli command (see:
// https://wiki.savoirfairelinux.com/wiki/Jenkins.jami.net#Usage_CLI_de_Jenkins).
pipeline {
    agent {
        label 'guix'
    }

    environment {
        TARBALLS = '/opt/ring-contrib' // set the cache directory
    }

    options {
        ansiColor('xterm')
    }

    stages {
        stage('Check configuration') {
            when { not { expression { fileExists TARBALLS } } }
            steps {
                error "The ${TARBALLS} directory does not exist. \
See https://wiki.savoirfairelinux.com/wiki/Jenkins.jami.net#Configuration"
            }
        }

        stage('Fetch submodules') {
            steps {
                sh 'git submodule update --init --recursive ' +
                   'daemon lrc client-gnome client-qt'
            }
        }

        stage('Generate release tarball') {
            steps {
                // The bundled tarballs included in the release
                // tarball depend on what is available on the host.
                // To ensure it can be shared across all different
                // GNU/Linux distributions, generate it in a minimal
                // container.  Wget uses GnuTLS, which looks up its
                // certs from /etc/ssl/certs.
                sh '''
                   #!/usr/bin/env bash
                   test -f $HOME/.bashrc && . $HOME/.bashrc
                   guix environment --container --network -E TARBALLS --share=$TARBALLS \
                       --expose=$SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt --ad-hoc \
                       coreutils \
                       gcc-toolchain \
                       git-minimal \
                       grep \
                       gzip \
                       make \
                       nss-certs \
                       pkg-config \
                       python \
                       sed \
                       tar \
                       wget \
                       xz -- make release-tarball
                   '''
            }
        }

        stage('Build packages') {
            environment {
                DISABLE_CONTRIB_DOWNLOADS = 'TRUE'
                // The following password is used to register with the
                // RHEL subscription-manager tool, required to build on RHEL.
                PASS = credentials('developers-redhat-com')
            }
            steps {
                script {
                    def targetsText = sh script: 'make -s list-package-targets', returnStdout: true
                    def targets = targetsText.split('\n')
                    def stages = [:]

                    targets.each { target ->
                        // Note: The stage calls are wrapped in closures, to
                        // delay their execution.
                        stages["${target}"] =  {
                            stage("stage: ${target}") {
                                sh "make ${target}"
                            }
                        }
                    }
                    parallel stages
                }
            }
        }
    }
}
