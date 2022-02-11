// Copyright (C) 2021-2022 Savoir-faire Linux Inc.
//
// Author: Maxim Cournoyer <maxim.cournoyer@savoirfairelinux.com>
// Author: Amin Bandali <amin.bandali@savoirfairelinux.com>
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

// TODO:
// - GPG-sign release tarballs.
// - GPG-sign release commits.
// - Allow publishing from any node, to avoid relying on a single machine.

// Configuration globals.
def SUBMODULES = ['daemon', 'lrc', 'client-gnome', 'client-qt']
def TARGETS = [:]
def REMOTE_HOST = env.SSH_HOST_DL_RING_CX
def REMOTE_BASE_DIR = '/srv/repository/ring'
def JAMI_PUBLIC_KEY_FINGERPRINT = 'A295D773307D25A33AE72F2F64CD5FA175348F84'
def SNAPCRAFT_KEY = '/var/lib/jenkins/.snap/key'
def GIT_USER_EMAIL = 'jenkins@jami.net'
def GIT_USER_NAME = 'jenkins'
def GIT_PUSH_URL = 'ssh://jenkins@review.jami.net:29420/jami-project'
def JENKINS_SSH_KEY = '35cefd32-dd99-41b0-8312-0b386df306ff'
def DL_SSH_KEY = '5825b39b-dfc6-435f-918e-12acc1f56221'

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
             pattern: 'jami-project']],
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
        choice(name: 'SNAP_PKG_NAME',
               choices: ['jami', 'jami-gnome'],
               description: 'Whether to build the client-qt or client-gnome ' +
               'snap. Defaults to "jami" (client-qt).')
        booleanParam(name: 'SNAP_BUILD_LOCAL',
                     defaultValue: false,
                     description: 'Whether to build the snap package locally ' +
                     'on one of our build machines, or remotely on a ' +
                     'Launchpad build server. Defaults to remote build.')
        string(name: 'SNAP_BUILD_ARCHES',
               defaultValue: 'amd64 arm64 armhf i386 ppc64el s390x',
               description: 'A whitespace-separated list of architectures ' +
               'to build the snap package on.  Only used when building ' +
               'remotely.')
        booleanParam(name: 'DEPLOY',
                     defaultValue: false,
                     description: 'Whether to deploy packages.')
        booleanParam(name: 'PUBLISH',
                     defaultValue: false,
                     description: 'Whether to upload tarball and push to git.')
        choice(name: 'CHANNEL',
               choices: ['internal', 'nightly', 'stable'],
               description: 'The repository channel to deploy to. ' +
               'Defaults to "internal".')
        string(name: 'PACKAGING_TARGETS',
               defaultValue: '',
               description: 'A whitespace-separated list of packaging ' +
               'targets, e.g. "debian_10 snap". ' +
               'When left unspecified, all the packaging targets are built.')
    }

    environment {
        TARBALLS = '/var/cache/jami' // set the cache directory
    }

    stages {
        stage('Check configuration') {
            steps {
                script {
                    if (!fileExists(TARBALLS)) {
                        error "The ${TARBALLS} directory does not exist. \
See https://wiki.savoirfairelinux.com/wiki/Jenkins.jami.net#Configuration"
                    }

                    mountType = sh(script: "findmnt ${TARBALLS} -o fstype -n",
                                   returnStdout: true)
                    if (!(mountType =~ /^nfs/)) {
                        error "The ${TARBALLS} directory is not mounted on NFS storage. \
See https://wiki.savoirfairelinux.com/wiki/Jenkins.jami.net#Configuration_client_NFS"
                    }
                }
            }
        }

        stage('Configure Git') {
            steps {
                sh """git config user.name ${GIT_USER_NAME}
                      git config user.email ${GIT_USER_EMAIL}
                   """
            }
        }

        stage('Checkout channel branch') {
            when {
                expression {
                    params.CHANNEL != 'internal'
                }
            }

            steps {
                sh """git checkout ${params.CHANNEL}
                      # Submodules are generally not managed by merging
                      git merge -X theirs --no-commit FETCH_HEAD || git status && git add `git diff --name-status --diff-filter=U | awk '{print \$2}'` || true
                   """
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
                sh """\
#!/usr/bin/env -S bash -l
git commit -am 'New release.'
make portable-release-tarball .tarball-version
git tag \$(cat .tarball-version) -am "Jami \$(cat .tarball-version)"
"""
                stash(includes: '*.tar.gz, .tarball-version',
                      name: 'release-tarball')
            }
        }

        stage('Publish release artifacts') {
            when {
                expression {
                    params.PUBLISH && params.CHANNEL != 'internal'
                }
            }

            steps {
                sshagent(credentials: [JENKINS_SSH_KEY, DL_SSH_KEY]) {
                    echo "Publishing to git repository..."
                    script {
                        if (params.CHANNEL == 'stable') {
                            // Only stables releases get tarballs and a tag.
                            sh 'git push --tags'
                            echo "Publishing release tarball..."
                            sh 'rsync --verbose jami*.tar.gz ' +
                                "${REMOTE_HOST}:${REMOTE_BASE_DIR}" +
                                "/release/tarballs/"
                        } else {
                            sh 'git push'
                        }
                    }
                }
            }
        }

        stage('Build packages') {
            environment {
                DISABLE_CONTRIB_DOWNLOADS = 'TRUE'
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
                                        sh """#!/usr/bin/env -S bash -l
                                           echo Building on node \$NODE_NAME
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
                sshagent(credentials: [DL_SSH_KEY]) {
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
                            script: 'find packages/* -maxdepth 1 -type d -print0 ' +
                                '| xargs -0 -n1 basename -z',
                            returnStdout: true).trim()
                        def distributions = distributionsText.split("\0")

                        distributions.each { distribution ->
                            echo "Deploying ${distribution} packages..."
                            sh """scripts/deploy-packages.sh \
  --distribution=${distribution} \
  --keyid="${JAMI_PUBLIC_KEY_FINGERPRINT}" \
  --snapcraft-login="${SNAPCRAFT_KEY}" \
  --remote-repository-location="${REMOTE_HOST}:${REMOTE_BASE_DIR}/${params.CHANNEL}" \
  --remote-manual-download-location="${REMOTE_HOST}:${REMOTE_BASE_DIR}/manual-${params.CHANNEL}"
"""
                        }
                    }
                }
            }
        }
    }
}
