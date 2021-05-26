// Packaging validation for supported GNU/Linux systems.
//
// Note: To work on this script without having to push a commit each
// time, use the jenkins-cli command (see:
// https://wiki.savoirfairelinux.com/wiki/Jenkins.jami.net#Usage_CLI_de_Jenkins).
//
// Requirements:
// 1. gerrit-trigger plugin
// 2. ws-cleanup plugin

// Configuration globals.
def SUBMODULES = ['daemon', 'lrc', 'client-gnome', 'client-qt']
def TARGETS = [:]
def SSH_PRIVATE_KEY = '/var/lib/jenkins/.ssh/gplpriv'
def REMOTE_HOST = env.SSH_HOST_DL_RING_CX
def REMOTE_BASE_DIR = '/srv/repository/ring'
def RING_PUBLIC_KEY_FINGERPRINT = 'A295D773307D25A33AE72F2F64CD5FA175348F84'
def SNAPCRAFT_KEY = '/var/lib/jenkins/.snap/key'

properties(
    [
        [
            $class: 'BuildDiscarderProperty',
            strategy: [$class: 'LogRotator', numToKeepStr: '30']
        ],
        pipelineTriggers([
                [
                    $class: 'GerritTrigger', gerritProjects: [
                        [
                            $class: "GerritProject",
                            pattern: "ring-project",
                            branches: [
                                [$class: "Branch", pattern: "master"]
                            ]
                        ]
                    ],
                    triggerOnEvents: [
                        [$class: "PluginRefUpdatedEvent"],
                        [
                            $class: "PluginCommentAddedContainsEvent",
                            commentAddedCommentContains: '!build'
                        ]
                    ]
                ]
            ])
    ]
)

pipeline {
    agent {
        label 'guix'
    }

    parameters {
        string(name: 'GERRIT_REFSPEC',
               defaultValue: 'refs/heads/master',
               description: 'The Gerrit refspec to fetch.')
        booleanParam(name: 'UPDATE_SUBMODULES',
                     defaultValue: true,
                     description: 'Update the ' + SUBMODULES.join(', ') +
                     'submodules to their latest commit.')
        booleanParam(name: 'BUILD_OWN_QT',
                     defaultValue: false,
                     description: 'Whether to build our own Qt packages.')
        booleanParam(name: 'BUILD_ARM',
                     defaultValue: false,
                     description: 'Whether to build ARM packages.')
        booleanParam(name: 'DEPLOY',
                     defaultValue: false,
                     description: 'Whether and where to deploy packages.')
        choice(name: 'CHANNEL',
               choices: 'internal\nnightly\nstable',
               description: 'The repository channel to deploy to. ' +
               'Defaults to "internal".')
        string(name: 'PACKAGING_TARGETS',
               defaultValue: '',
               description: 'A whitespace-separated list of packaging ' +
               'targets, e.g. "package-debian_10 package-snap". ' +
               'When left unspecified, all the packaging targets are built.')
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
                echo 'Initializing submodules ' + SUBMODULES.join(', ') +
                    (params.UPDATE_SUBMODULES ? ' to their latest commit.' : '.')
                sh 'git submodule update --init --recursive' +
                    (params.UPDATE_SUBMODULES ? ' --remote ' : ' ') +
                    SUBMODULES.join(' ')
            }
        }

        stage('Generate release tarball') {
            steps {
                // Note: sourcing .bashrc is necessary to setup the
                // environment variables used by Guix.
                sh '''#!/usr/bin/env bash
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
                    def targetsText = params.PACKAGING_TARGETS.trim()
                    if (!targetsText) {
                        targetsText = sh(script: 'make -s list-package-targets',
                                         returnStdout: true).trim()
                    }

                    TARGETS = targetsText.split(/\s/)
                    if (!params.BUILD_OWN_QT) {
                        TARGETS = TARGETS.findAll { !it.endsWith('_qt') }
                    }
                    if (!params.BUILD_ARM) {
                        TARGETS = TARGETS.findAll { !(it =~ /_(armhf|arm64)$/) }
                    }


                    def stages = [:]

                    TARGETS.each { target ->
                        // Note: The stage calls are wrapped in closures, to
                        // delay their execution.
                        stages[target] =  {
                            stage(target) {
                                // Offload builds to different agents.
                                node('linux-builder') {
                                    cleanWs()
                                    unstash 'release-tarball'
                                    // sh """
                                    //    tar xf *.tar.gz --strip-components=1
                                    //    make ${target}
                                    //    """
                                    sh "mkdir packages && touch packages/${target}.bin"
                                    stash(includes: 'packages/**',
                                          name: target)
                                }
                            }
                        }
                    }
                    parallel stages
                }
            }
        }
        stage('Sign & deploy packages') {
            agent {
                label 'ring-buildmachine-02.mtl.sfl'
            }

            when {
                expression {
                    params.DEPLOY
                }
            }

            steps {
                script {
                    TARGETS.each { target ->
                        unstash target
                        def distribution = target - /^package-/
                        echo "Deploying packages for ${distribution}..."
                        sh """scripts/deploy-packages.sh \
  --distribution=${distribution} \
  --keyid="${RING_PUBLIC_KEY_FINGERPRINT}" \
  --snapcraft-login="${SNAPCRAFT_KEY}" \
  --remote-ssh-identity-file="${SSH_PRIVATE_KEY}" \
  --remote-repository-location="${REMOTE_HOST}:${REMOTE_BASE_DIR}/${params.CHANNEL}" \
  --remote-manual-download-location="${REMOTE_HOST}:${REMOTE_BASE_DIR}/manual-${params.CHANNEL}"
"""
                    }
                }
            }
        }
    }
}
