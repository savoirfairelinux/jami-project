// Packaging validation for supported GNU/Linux systems.
//
// Note: To work on this script without having to push a commit each
// time, use the jenkins-cli command (see:
// https://wiki.savoirfairelinux.com/wiki/Jenkins.jami.net#Usage_CLI_de_Jenkins).
pipeline {
    agent {
        label 'guix'
    }

    parameters {
        string(name: 'GERRIT_REFSPEC',
               defaultValue: 'refs/heads/master',
               description: 'The Gerrit refspec to fetch.')

        booleanParam(name: 'BUILD_OWN_QT',
                     defaultValue: false,
                     description: 'Whether to build our own Qt packages.')
        booleanParam(name: 'BUILD_ARM',
                     defaultValue: false,
                     description: 'Whether to build ARM packages.')
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
                echo 'Updating relevant submodules to their latest commit'
                sh 'git submodule update --init --recursive --remote ' +
                   'daemon lrc client-gnome client-qt'
            }
        }

        stage('Generate release tarball') {
            steps {
                // Note: sourcing .bashrc is necessary to setup the
                // environment variables used by Guix.
                sh '''
                   #!/usr/bin/env bash
                   test -f $HOME/.bashrc && . $HOME/.bashrc
                   make portable-release-tarball .tarball-version
                   '''
                stash(includes: '*.tar.gz, .tarball-version',
                      name: 'release-tarball')
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
                    def targetsText = sh(script: 'make -s list-package-targets',
                                         returnStdout: true)
                    def targets = targetsText.split('\n')
                    if (!params.BUILD_OWN_QT) {
                        targets = targets.findAll { !it.endsWith('_qt') }
                    }
                    if (!params.BUILD_ARM) {
                        targets = targets.findAll { !(it =~ /_(armhf|arm64)$/) }
                    }
                    def stages = [:]

                    targets.each { target ->
                        // Note: The stage calls are wrapped in closures, to
                        // delay their execution.
                        stages["${target}"] =  {
                            stage("${target}") {
                                // Offload builds to different agents.
                                node('linux-builder') {
                                    unstash 'release-tarball'
                                    sh """#!/usr/bin/env bash
                                       tar xf *.tar.gz ring-project/{Makefile,\
docker/,packaging/,patches/,scripts/} --strip-components=1
                                       make ${target}
                                       """
                                }
                            }
                        }
                    }
                    parallel stages
                }
            }
        }
    }
}
