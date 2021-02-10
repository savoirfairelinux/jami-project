// Pipeline to validate the packaging targets.

// Note: To work on this script without having to push a commit each
// time, use the jenkins-cli command (see:
// https://wiki.savoirfairelinux.com/wiki/Jenkins.jami.net#Usage_CLI_de_Jenkins).

pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                echo 'Building..'
            }
        }
        stage('Test') {
            steps {
                echo 'Testing..'
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying....'
            }
        }
    }
}
