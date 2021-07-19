// Copyright (C) 2021 Savoir-faire Linux Inc.
//
// Author: Maxim Cournoyer <maxim.cournoyer@savoirfairelinux.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
// Packaging validation for supported GNU/Linux systems.
//
// Note: To work on this script without having to push a commit each
// time, use the jenkins-cli command (see:
// https://wiki.savoirfairelinux.com/wiki/Jenkins.jami.net#Usage_CLI_de_Jenkins).
//
// Requirements:
// 1. gerrit-trigger plugin
// 2. ws-cleanup plugin
// 3. ansicolor plugin

// Configuration globals.
def SUBMODULES = ['daemon', 'lrc', 'client-gnome', 'client-qt']
def TARGETS = [:]
def SSH_PRIVATE_KEY = '/var/lib/jenkins/.ssh/gplpriv'
def REMOTE_HOST = env.SSH_HOST_DL_RING_CX
def REMOTE_BASE_DIR = '/srv/repository/ring'
def RING_PUBLIC_KEY_FINGERPRINT = 'A295D773307D25A33AE72F2F64CD5FA175348F84'
def SNAPCRAFT_KEY = '/var/lib/jenkins/.snap/key'

pipeline {
    agent {
        label 'guix'
    }

    triggers {
        gerrit customUrl: '',
        gerritProjects: [
            [branches: [[compareType: 'PLAIN', pattern: 'master']],
             compareType: 'PLAIN',
             disableStrictForbiddenFileVerification: false,
             pattern: 'ring-project']],
        triggerOnEvents: [
            commentAddedContains('!build'),
            patchsetCreated(excludeDrafts: true, excludeNoCodeChange: true,
                            excludeTrivialRebase: true)]
    }

    options {
        ansiColor('xterm')
    }

    parameters {
        string(name: 'GERRIT_REFSPEC',
               defaultValue: 'refs/heads/master',
               description: 'The Gerrit refspec to fetch.')
        booleanParam(name: 'WITH_MANUAL_SUBMODULES',
                     defaultValue: false,
                     description: 'Checkout the ' + SUBMODULES.join(', ') +
                     ' submodules at their Git-recorded commit.  When left ' +
                     'unticked (the default), checkout the submodules at ' +
                     'their latest commit from their main remote branch.')
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
                    (params.WITH_MANUAL_SUBMODULES ? '.' : ' to their latest commit.')
                sh 'git submodule update --init --recursive' +
                    (params.WITH_MANUAL_SUBMODULES ? ' ' : ' --remote ') +
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
                                    catchError(buildResult: 'FAILURE',
                                               stageResult: 'FAILURE') {
                                        sh """
                                           tar xf *.tar.gz --strip-components=1
                                           make ${target}
                                           """
                                        stash(includes: 'packages/**',
                                              name: target)
                                    }
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
                        try {
                            unstash target
                        } catch (err) {
                            echo "Failed to unstash ${target}, skipping..."
                            return
                        }
                    }

                    def distributionsText = sh(
                        script: 'find packages/* -maxdepth 1 -type d -print0' +
                            '| xargs -0 -n1 basename -z',
                        returnStdout: true).trim()
                    def distributions = distributionsText.split("\0")

                    distributions.each { distribution ->
                        echo "Deploying ${distribution} packages..."
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
